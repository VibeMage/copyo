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
# - 剪点是对着 1.2.1 那两段录屏逐段挑的（cut_plan 里的 case），只对那两段素材成立。
#   每种语言都记着当时源片的精确时长和原始帧数，运行时必须同时完全匹配：换了素材要重挑剪点，
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

# 每种语言的剪点，格式为「开始秒:结束秒:取景」。先 fps=30，再以精确帧号抽样，
# 在动画、拼音输入、照片切颜色、Pinboard 和复制提示处加密到 0.1 秒核对。
# 只去掉静止停顿，操作和动画都保持 1 倍速；取景仅在预览打开前、关闭后硬切。
# expected_source / expected_frames 是 ffprobe 读取的 1.2.1 源片精确时长与原始帧数。
# 换景发生在选中图片卡后的静止段；预览关闭后先在远景停留，再切回近景。
cut_plan() {
  case "$1" in
    zh)
      # 上浮；四次切卡、四次筛选、完整拼音上屏；清空及走到图片卡；
      # 照片预览；切到颜色预览；关闭预览；弹菜单；选 Pinboard、图钉、复制提示至淡出。
      expected_source=39.716667
      expected_frames=1420
      ranges=('1.4:3.2:tight' '4.0:16.5:tight' '17.5:22.6:tight'
              '22.6:24.6:wide' '25.5:26.7:wide' '27.7:29.0:wide'
              '29.5:30.7:tight' '31.6:35.7:tight')
      duration=29.2
      ;;
    en)
      expected_source=40.001667
      expected_frames=1318
      ranges=('1.4:3.2:tight' '4.0:15.4:tight' '16.1:21.4:tight'
              '21.4:23.4:wide' '24.2:25.6:wide' '26.5:27.8:wide'
              '28.2:29.5:tight' '30.2:34.4:tight')
      duration=28.7
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
        f"实际时长 {duration} 秒、原始帧数 {frames}；"
        f"预期精确时长 {expected_duration} 秒、原始帧数 {expected_frames}。\n"
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
  # 图片卡停稳后提前约 0.7–0.8 秒切 wide；关闭预览后在 wide 保留约 0.7 秒，再回 tight。
  # 两次换景都在静止画面完成，没有推拉摇移或变速。
  # 源片可变帧率，先统一到 30 fps，再以帧边界剪辑，保证每段原速且切点精确。
  count="${#ranges[@]}"
  graph="[0:v]fps=30,split=$count"
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
    graph+="[source$index]trim=start=$start:end=$end,setpts=PTS-STARTPTS,crop=$crop,scale=1920:1080:flags=lanczos,setsar=1[$label];"
    labels+="[$label]"
    index=$((index + 1))
  done
  graph+="${labels}concat=n=$count:v=1:a=0,format=yuv420p[video]"

  # 留下逐段源帧/成片帧映射。QA 抽帧按 n 精确取帧，不用 fps=1 结果反推时间标签。
  python3 - "$OUTPUT_DIR/$lang-cut-plan.json" "$expected_source" "$expected_frames" "$duration" "${ranges[@]}" <<'PY'
import json
import pathlib
import sys
from decimal import Decimal

report, source_duration, source_frames, expected_duration, *ranges = sys.argv[1:]
segments, cursor = [], 0
for part in ranges:
    start, end, framing = part.split(':')
    first, last = Decimal(start) * 30, Decimal(end) * 30
    assert first == int(first) and last == int(last), '剪点必须对齐 30 fps 的整数帧'
    first, last = int(first), int(last)
    assert 0 <= first < last <= Decimal(source_duration) * 30, '剪点必须位于源片时长内'
    crop = [2304, 1296, 768, 864] if framing == 'tight' else [3072, 1728, 384, 304]
    segments.append(dict(source_start_frame=first, source_end_frame_exclusive=last,
                         output_start_frame=cursor, output_end_frame_exclusive=cursor + last - first,
                         framing=framing, crop_whxy=crop))
    cursor += last - first
assert cursor == Decimal(expected_duration) * 30, '分段帧数总和必须与成片时长一致'
pathlib.Path(report).write_text(json.dumps(dict(source_duration_seconds=source_duration,
    source_nb_frames=int(source_frames), fps=30, frame_count=cursor,
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

  # 成品第 30 帧（1.0 秒，源片 2.4 秒）面板已经完整浮起且静止，取这一帧做海报。
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
