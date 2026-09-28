#!/usr/bin/env bash
# 把 Mac 商店预览的中英两段原始录屏剪成成品：H.264 1920×1080 30 fps，带一条 48 kHz 立体声
# 静音 AAC 轨（Mac 的 App 预览没有音轨会被 ASC 拒收），外加海报帧与 ffprobe 探测结果。
#
# 用法:
#   bash scripts/make-store-preview.sh --input-dir <raw 目录> [--output-dir DIR] [--language zh|en|all]
#
#   --input-dir   原始素材目录，里面是 zh-preview.mov / en-preview.mov（必填，没有参数时只打印用法）
#   --output-dir  默认 <输入目录的上一级>/out/preview，与 make-store-shots.py 的 <raw>/../out 放在一起
#   --language    默认 all
#
# 几个刻意的选择:
# - 剪点是对着 store-light 的品牌角光浅色录屏逐段挑的（cut_plan 里的 case），只对这两段素材成立。
#   每种语言都记着当时源片的精确时长和容器记录帧数（nb_frames），运行时必须同时完全匹配：换了素材要重挑剪点，
#   不能拿旧剪点硬剪。所有语言都通过检查后才开始编码。
# - 输出目录不能等于或位于输入目录、art/store/ 之内（解析符号链接、按同一 inode 判断），
#   免得覆盖原始素材或已经入库的成品；除输出目录外不写任何地方。
#
# 依赖 ffmpeg（带 libx264）、ffprobe、python3。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
INPUT_DIR=
OUTPUT_DIR=
LANGUAGE=all

usage() {
  cat <<'USAGE'
用法: bash scripts/make-store-preview.sh --input-dir DIR [--output-dir DIR] [--language zh|en|all]
  --input-dir   原始素材目录，里面是 zh-preview.mov / en-preview.mov（必填）
  --output-dir  输出目录，默认 <输入目录的上一级>/out/preview
  --language    zh、en 或 all（默认 all）
USAGE
}

if (($# == 0)); then
  usage >&2
  exit 2
fi
while (($#)); do
  case "$1" in
    --input-dir|--output-dir|--language)
      if (($# < 2)); then
        printf '%s 缺少参数值\n' "$1" >&2
        exit 2
      fi
      case "$1" in
        --input-dir) INPUT_DIR="$2" ;;
        --output-dir) OUTPUT_DIR="$2" ;;
        --language) LANGUAGE="$2" ;;
      esac
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) printf '不认识的参数：%s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$INPUT_DIR" ]]; then
  printf '缺少 --input-dir\n' >&2
  usage >&2
  exit 2
fi
case "$LANGUAGE" in
  zh|en) languages=("$LANGUAGE") ;;
  all) languages=(zh en) ;;
  *) printf '%s\n' '--language 只能是 zh、en 或 all' >&2; exit 2 ;;
esac
for command in ffmpeg ffprobe python3; do
  command -v "$command" >/dev/null || { printf '缺少命令：%s\n' "$command" >&2; exit 1; }
done

[[ -d "$INPUT_DIR" ]] || { printf '输入目录不存在：%s\n' "$INPUT_DIR" >&2; exit 1; }
INPUT_DIR="$(cd -- "$INPUT_DIR" && pwd -P)"
OUTPUT_DIR="${OUTPUT_DIR:-$(dirname -- "$INPUT_DIR")/out/preview}"

# 输出目录黑名单：输入目录与 art/store/。先按解析符号链接后的路径比；
# 再对输出路径上已经存在的每一级按 inode 比，大小写不敏感的卷上换个大小写也绕不过去。
python3 - "$OUTPUT_DIR" "$INPUT_DIR" "$PROJECT_DIR/art/store" <<'PY'
import os
import pathlib
import sys

output = pathlib.Path(sys.argv[1]).resolve()
for root in (pathlib.Path(p).resolve() for p in sys.argv[2:]):
    inside = output == root or root in output.parents
    if not inside and root.exists():
        inside = any(p.exists() and os.path.samefile(p, root) for p in (output, *output.parents))
    if inside:
        raise SystemExit(f"输出目录不能等于或位于 {root} 之内，收到 {output}")
PY

# 每段格式「CFR 开始帧:排他结束帧:取景」；这些是按真实 PTS 运行 fps=30 后的帧号，
# 绝不是 VFR 原帧序号除以 60。原片用 ffprobe frame=pts_time / showinfo 逐帧核过。
# 两段从 163/30=5.433333 秒开始，淡入前保留约 0.2 秒空舞台；只跳过静止停顿和
# 已定位的瑕疵。每个剪点检查前后各 5 帧，所有操作、动画保持 1 倍速。
# expected_source / expected_frames 是任务四源片的精确格式时长与容器记录帧数（nb_frames）。
cut_plan() {
  case "$1" in
    zh)
      # 淡入；四次切卡/筛选/完整拼音上屏；缩短搜索停顿；
      # 清空搜索时原始 PTS 20.216667–20.433333 有蓝块，静止帧之间跳过 [20.2,20.6)。
      # 图片停稳后 24.7 秒切宽景，关闭预览后 31.3 秒回紧景；结尾停在「已复制」完整显示的最后一帧
      # （这次录屏里提示是一帧内消失的，没有淡出，留着空舞台尾巴像是闪没了）。
      expected_source=46.020000
      expected_frames=1437
      ranges=('163:198:tight' '219:570:tight' '594:606:tight'
              '618:741:tight' '741:792:wide' '828:870:wide'
              '906:939:wide' '939:1122:tight')
      duration=27.666666667
      ;;
    en)
      # 原生 PTS 5.883333 的输入法玻璃浮层在 fps 前显式排除，保留原时间戳。
      # 第一处接点 CFR 176→177 对应干净原帧 5.866667→5.900000；不改变动作速度。
      # 24.0 秒切宽景，30.5 秒回紧景；菜单选择、图钉；结尾同样停在「已复制」完整显示的最后一帧。
      expected_source=45.991667
      expected_frames=1465
      ranges=('163:177:tight' '177:198:tight' '219:540:tight'
              '564:720:tight' '720:768:wide' '804:846:wide'
              '882:915:wide' '915:1099:tight')
      duration=27.3
      ;;
  esac
}

check_source() {
  local lang="$1"
  local source="$INPUT_DIR/$lang-preview.mov"
  local probe expected_source expected_frames duration
  local -a ranges
  test -r "$source" || { printf '找不到素材：%s\n' "$source" >&2; return 1; }
  cut_plan "$lang"
  probe="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,nb_frames:format=duration -of json "$source")"
  python3 - "$source" "$lang" "$expected_source" "$expected_frames" "$probe" <<'PY'
import json
import sys
from decimal import Decimal, InvalidOperation

source, lang, expected_duration, expected_frames, probe = sys.argv[1:]
data = json.loads(probe)
streams = data.get('streams', [])
if len(streams) != 1:
    raise SystemExit(f"源片必须含有一个可读取的视频流：{source}")
video = streams[0]
width, height = video.get('width'), video.get('height')
if (width, height) != (3840, 2160):
    raise SystemExit(f"裁切框按 3840×2160 的源片核过，{source} 实际为 {width}×{height}。")
duration, frames = data.get('format', {}).get('duration'), video.get('nb_frames')
try:
    matched = Decimal(duration) == Decimal(expected_duration) and int(frames) == int(expected_frames)
except (InvalidOperation, TypeError, ValueError):
    matched = False
if not matched:
    raise SystemExit(
        f"源片不匹配：{source}\n"
        f"实际时长 {duration} 秒、容器记录帧数（nb_frames） {frames}；"
        f"预期精确时长 {expected_duration} 秒、容器记录帧数（nb_frames） {expected_frames}。\n"
        f"请先对着新录屏重新挑剪点，再更新 cut_plan 中 {lang} 的 "
        "ranges、duration、expected_source 与 expected_frames。")
PY
}

render_preview() {
  local lang="$1"
  local source="$INPUT_DIR/$lang-preview.mov"
  local destination="$OUTPUT_DIR/$lang-preview.mp4"
  local poster="$OUTPUT_DIR/$lang-poster.png"
  local expected_source expected_frames duration graph part index start end framing crop label labels count
  local -a ranges
  cut_plan "$lang"

  # 两个固定 16:9 取景都裁自同一块连续的真实录屏，菜单栏完全排除，没有重绘或移动 UI：
  # tight=2304×1296 at (768,864)：2208 px 面板成为 1840 px，左右各 40 px；旧版是约 1745 px。
  # wide=3072×1728 at (384,304)：为高照片预览留出完整高度；面板 1380 px，预览窗 900 px。
  # 照片预览顶部约 27 px、面板底部约 22 px 成片余量；打开/切卡/关闭动画的外沿均在取景内。
  # 图片卡停稳后提前约 0.6–0.8 秒切 wide；关闭预览后在 wide 保留约 0.7 秒，再回 tight。
  # 两种取景的右界分别为 3072、3456 px，排除源片 x≈3780 px 的鼠标指针。
  # 两次换景都在静止画面完成，没有推拉摇移或变速。
  # 源片可变帧率；en 先剔除原始 PTS 坏帧，再统一到 30 fps，以帧边界剪辑保持原速。
  count="${#ranges[@]}"
  graph='[0:v]'
  if [[ "$lang" == en ]]; then
    # 用原始 PTS 明确剔除系统输入法浮层；不重置 PTS，fps 只作正常定帧，不变速。
    graph+="select='not(between(t,5.875,5.895))',"
  fi
  graph+="fps=30,split=$count"
  for ((index=0; index<count; index++)); do graph+="[source$index]"; done
  graph+=';'
  labels=''
  index=0
  for part in "${ranges[@]}"; do
    IFS=: read -r start end framing <<< "$part"
    case "$framing" in
      tight) crop='2304:1296:768:864' ;;
      wide) crop='3072:1728:384:304' ;;
      *) printf '未知取景：%s\n' "$framing" >&2; return 1 ;;
    esac
    label="segment$index"
    graph+="[source$index]trim=start_frame=$start:end_frame=$end,setpts=PTS-STARTPTS,crop=$crop,scale=1920:1080:flags=lanczos,setsar=1[$label];"
    labels+="[$label]"
    index=$((index + 1))
  done
  graph+="${labels}concat=n=$count:v=1:a=0,format=yuv420p[video]"

  # 留下逐段源帧/成片帧映射。QA 抽帧按 n 精确取帧，不用 fps=1 结果反推时间标签。
  python3 - "$OUTPUT_DIR/$lang-cut-plan.json" "$expected_source" "$expected_frames" "$duration" "$lang" "${ranges[@]}" <<'PY'
import json
import pathlib
import sys
from decimal import Decimal

report, source_duration, source_frames, expected_duration, lang, *ranges = sys.argv[1:]
segments, cursor = [], 0
for part in ranges:
    start, end, framing = part.split(':')
    first, last = int(start), int(end)
    assert 0 <= first < last <= Decimal(source_duration) * 30, '剪点必须位于源片时长内'
    crop = [2304, 1296, 768, 864] if framing == 'tight' else [3072, 1728, 384, 304]
    segments.append(dict(source_start_frame=first, source_end_frame_exclusive=last,
                         output_start_frame=cursor, output_end_frame_exclusive=cursor + last - first,
                         framing=framing, crop_whxy=crop))
    cursor += last - first
assert abs(Decimal(cursor) / 30 - Decimal(expected_duration)) < Decimal('0.000001'), '分段帧数总和必须与成片时长一致'
pathlib.Path(report).write_text(json.dumps(dict(source_duration_seconds=source_duration,
    source_nb_frames=int(source_frames), fps=30, frame_count=cursor,
    source_frame_numbering='CFR frames after timestamp-preserving native PTS exclusion and fps=30; not native VFR indexes',
    excluded_native_pts_seconds=[[5.875, 5.895]] if lang == 'en' else [],
    poster_output_frame=30, poster_source_cfr_frame=193,
    playback_speed=1, segments=segments), indent=2) + '\n')
PY

  printf '剪辑 %s（%s 秒）\n' "$destination" "$duration"
  ffmpeg -hide_banner -loglevel warning -nostdin -y \
    -i "$source" \
    -f lavfi -i 'anullsrc=channel_layout=stereo:sample_rate=48000' \
    -filter_complex "$graph" \
    -map '[video]' -map 1:a:0 \
    -c:v libx264 -preset slow -crf 18 -profile:v high -level:v 4.1 \
    -pix_fmt yuv420p -r 30 -fps_mode cfr \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
    -c:a aac -b:a 192k -ar 48000 -ac 2 \
    -t "$duration" -shortest -movflags +faststart \
    -map_metadata -1 -map_chapters -1 "$destination"

  # 成品第 30 帧（1.0 秒，两种语言均为源 CFR 193 / 6.433333 秒）面板完整且静止。
  ffmpeg -hide_banner -loglevel error -nostdin -y \
    -i "$destination" -vf "select='eq(n,30)'" -frames:v 1 -update 1 -pix_fmt rgb24 "$poster"

  # 编码或规格检查不过就中止。探测结果（<lang>-probe.json）留在成品旁边备查。
  ffprobe -v error -show_streams -show_format -of json "$destination" > "$OUTPUT_DIR/$lang-probe.json"
  python3 - "$OUTPUT_DIR/$lang-probe.json" "$poster" "$duration" <<'PY'
import json
import pathlib
import struct
import sys
from fractions import Fraction

report, poster, expected = sys.argv[1:]
data = json.loads(pathlib.Path(report).read_text())
video = [s for s in data['streams'] if s['codec_type'] == 'video']
audio = [s for s in data['streams'] if s['codec_type'] == 'audio']
assert len(video) == len(audio) == 1, '成片必须恰好包含一个视频流和一个音频流'
v, a = video[0], audio[0]
assert (v['codec_name'], v['width'], v['height'], v['pix_fmt']) == ('h264', 1920, 1080, 'yuv420p'), '视频必须为 H.264、1920×1080、yuv420p'
assert Fraction(v['avg_frame_rate']) == Fraction(v['r_frame_rate']) == 30, '成片必须恒定为 30 fps'
assert int(v['nb_frames']) == round(float(expected) * 30), '成片帧数必须与精确剪辑计划一致'
assert (a['codec_name'], a['channels'], a['channel_layout'], a['sample_rate']) == ('aac', 2, 'stereo', '48000'), '音轨必须为 AAC、48 kHz 立体声'
length = float(data['format']['duration'])
assert 15 <= length <= 30 and abs(length - float(expected)) < 0.05, '成片时长必须符合剪辑计划，且位于 15–30 秒之间'
assert int(data['format']['size']) < 500_000_000, '成片必须小于 500 MB'
assert abs(float(v['duration']) - float(a['duration'])) < 0.05, '音视频时长差必须小于 0.05 秒'
header = pathlib.Path(poster).read_bytes()[:29]
assert header[:8] == b'\x89PNG\r\n\x1a\n', '海报必须为 PNG'
assert struct.unpack('>II', header[16:24]) == (1920, 1080), '海报尺寸必须为 1920×1080'
assert header[25] == 2, '海报必须为不带透明通道的 RGB 图片'
print(f"已校验 {pathlib.Path(report).name}：{length:.2f} 秒，H.264 1920x1080 30fps，AAC 立体声 48kHz，RGB 海报帧")
PY
}

# 先把要剪的语言全部检查一遍，任何一段素材不对都在编码前退出
for lang in "${languages[@]}"; do check_source "$lang"; done
mkdir -p "$OUTPUT_DIR"
for lang in "${languages[@]}"; do render_preview "$lang"; done
