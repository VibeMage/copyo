#!/usr/bin/env python3
"""用真实应用截图合成 Mac 1.2 中英双语商店截图。

    python3 scripts/make-store-shots.py build.noindex/store-light/raw
    # 另生成两张照片预览备选，放入 out/alt/：
    python3 scripts/make-store-shots.py build.noindex/store-light/raw --include-image-preview

默认输出十张 RGB PNG 到 <素材目录>/../out/screenshots/，并生成
out/contact-sheet.png 与 out/screenshot-layout.json；不写入 art/store/。
不带 --include-image-preview 时，清理 out/alt/ 中本脚本生成的两张
03-preview-image-{zh,en}.png，并将布局记录的 alternatives 置空；其他文件保留。
照片预览备选只供比较：它的标题栏在画面左侧，正好压在浅色舞台的红色侧光上，
副标题对比度不到 WCAG AA，这版舞台下不能拿它上架。

先校验十三张素材（含舞台）的 SHA-256，全部匹配后才写成品。更换素材后应先检查面板
是否仍位于 PANEL_SOURCE、是否完整落在 SCENE_CROP / LAYOUTS 的裁切框内，
必要时重新调整版式，再更新 EXPECTED_SOURCES；不要跳过校验直接套用旧裁切框。
文件名与文案见 TEXT。拍摄使用 -demoData，保留 PNG 原有色彩配置。

面板场景只裁取桌面上的一块连续区域，不单独移动、重绘或修补应用像素；
半透明面板、阴影与预览窗保留拍摄背景。独立设置窗口按透明度叠加在背景上。
带显示器 ICC 的素材先转换到 sRGB；嵌入固定 ICC，保证相同输入逐字节可复现。

Copyo 复制后交还焦点，由用户按 Command-V；宣传文案不承诺自动粘贴。
浅色素材要求见 build.noindex/store-light/BRIEF.md；版式沿用
build.noindex/store-1.2.1/BRIEF.md 和 BRIEF-fixes.md。
"""

import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

from PIL import Image, ImageCms, ImageDraw, ImageFont


REPO = Path(__file__).resolve().parent.parent
ICON = REPO / "art" / "icon" / "icon-512.png"
W, H = 2560, 1600
SOURCE_SIZE = (3840, 2160)
# 角光原图中的面板位于 (816, 1330)，尺寸为 2208×664px；比上一轮上移 2px。
# 四个主面板场景保持相同位置和约 1.0997 倍缩放，均裁取连续的 16:10 区域。
SCENE_CROP = (756, 705, 3084, 2160)
PANEL_SOURCE = (816, 1330, 3024, 1994)
LAYOUTS = {
    "panel": dict(crop=SCENE_CROP, icon_size=176, icon_top=195,
                  head_top=425, sub_top=551, head_en=83, head_zh=79,
                  sub_en=44, sub_zh=40, header_limit=640),
    "text-preview": dict(crop=SCENE_CROP, icon_size=90, icon_top=18,
                         head_top=128, sub_top=223, head_en=72, head_zh=69,
                         sub_en=36, sub_zh=34, header_limit=265),
    # 高照片窗与面板无法同时按 1.1 倍放入画布；标题使用照片旁的原有空白，
    # 保留 2007px 宽面板和完整预览，不单独移动任何应用像素。
    "image-preview": dict(crop=(512, 300, 3328, 2060), icon_size=140, icon_top=231,
                          head_top=435, sub_top=540, head_en=62, head_zh=62,
                          sub_en=36, sub_zh=36, header_limit=820,
                          text_left=64, text_width=488),
    "settings": dict(crop=SCENE_CROP, icon_size=100, icon_top=110,
                     head_top=260, sub_top=370, head_en=80, head_zh=77,
                     sub_en=40, sub_zh=38, header_limit=440),
}
BACKGROUND_COLOR = (244, 242, 237)
HEADLINE_COLOR, SUBTITLE_COLOR = (22, 22, 26), (110, 110, 118)
TEXT_MAX_WIDTH = W - 240
# 独立设置窗口保留原始宽高比与系统阴影；与标题区一起下移 75px。
SETTINGS_WIDTH, SETTINGS_TOP = 1340, 440
SF = "/System/Library/Fonts/SFNS.ttf"
SYMBOLS = "/System/Library/Fonts/Apple Symbols.ttf"
PINGFANG_ROOT = Path("/System/Library/AssetsV2/com_apple_MobileAsset_Font8")
PINGFANG_SEMIBOLD, PINGFANG_REGULAR = 11, 3
# 色彩转换继续使用 LittleCMS 内置 sRGB；改用系统配置可能使部分通道相差 1，
# 因而与仅用于嵌入成品的固定 ICC 分开，保持既有颜色与逐字节可复现性。
SRGB = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB"))
SRGB_ICC = Path("/System/Library/ColorSync/Profiles/sRGB Profile.icc")


def srgb_profile_bytes():
    """固定嵌入的 sRGB 标签，确保相同输入生成逐字节一致的 PNG。

    createProfile() 会把当前时间写入 ICC 头的第 24–35 字节，直接嵌入会使
    每次结果不同。优先读取系统 sRGB IEC61966-2.1 配置；不存在时将内置配置
    的日期清零。该配置的 ID 原本为全零（未计算），因此不会破坏校验和。
    """
    try:
        return SRGB_ICC.read_bytes()
    except OSError:
        data = bytearray(SRGB.tobytes())
        data[24:36] = bytes(12)
        return bytes(data)


SRGB_BYTES = srgb_profile_bytes()

# 成品文件名前缀、素材后缀、主标题、副标题；中英文文案均保持不变。
TEXT = {
    "en": [
        ("01-panel", "01-panel", "Everything you copied, one key away",
         "Press ⇧⌘V — your history floats right above the Dock"),
        ("02-search", "02-search", "Type to filter",
         "Search content, source app or file name — the cards never jump"),
        ("03-preview", "03-preview", "Space to peek",
         "Preview text, links and images above the panel"),
        ("04-pinboard", "05-pinmenu", "Keep what you use most",
         "Press ⌘P to choose a Pinboard, right from the keyboard"),
        ("05-shortcuts", "04-settings", "Hands stay on the keyboard",
         "⇥ switches filters, ⌘1–9 copies a card — ⇧⌘V is yours to remap"),
    ],
    "zh": [
        ("01-panel", "01-panel", "复制过的一切，随叫随到",
         "按下 ⇧⌘V，剪贴板历史浮在 Dock 上方"),
        ("02-search", "02-search", "即输即搜",
         "按内容、来源应用、文件名过滤，卡片不跳动"),
        ("03-preview", "03-preview", "空格，先看一眼",
         "在面板上方预览文本、链接和图片"),
        ("04-pinboard", "05-pinmenu", "常用的，固定下来",
         "按 ⌘P 选择 Pinboard，手不离键盘"),
        ("05-shortcuts", "04-settings", "手不离键盘",
         "⇥ 切换筛选，⌘1–9 直接复制；⇧⌘V 可自定义"),
    ],
}


# 十三张经人工核验的浅色素材（含舞台）；换图后必须先复核版式，再更新对应指纹。
EXPECTED_SOURCES = {
    "en-01-panel.png": "fc67855264fdcbb6d49724e9492ac4c84a2259df195bee52184e520c54b2f3d4",
    "en-02-search.png": "806d4b06ddf03308c3e658101a8277e2678f6706889684f5a2cbf76ad5bdef61",
    "en-03-preview.png": "a3db05d7282cda025934c895c058e98b4cffe12b872314ab6bd5523ae2181b38",
    "en-03b-preview-image.png": "382cf0ef6fab294f703ee682c18cb11c992618f7c5013f9cc344bd61e2fae452",
    "en-04-settings.png": "d485ea0cadf12b49101257d1f28bd9aa9b2ef940570b37939d21c0a021a9d10a",
    "en-05-pinmenu.png": "a5d6b298c714588da3acb200df26d536c32276914c89908c26c16cd73bcb915f",
    "zh-01-panel.png": "1eba95a72199a9ad5012178e15a66f3a17565ada41731fecfe8b6a5e972f6c24",
    "zh-02-search.png": "6e576b656f7368761cfb1b2281b2749bec57ae0295d76bb6b70c2018da612568",
    "zh-03-preview.png": "3d7170f8f999b84f0d574f5f58bd70adb505229f5433a02741ea2d3a7c85993c",
    "zh-03b-preview-image.png": "b2930e3a0ef9c663fc4e888bbbb7be59384e6998d719ed4e43400e684e826803",
    "zh-04-settings.png": "27e06a52cedbc5b4fdf3c2d393e07e4badd8a917538b5bf50398d2c3983978a2",
    "zh-05-pinmenu.png": "ffff6855624492f4d8d9bb1680ea64a6fdfa76b9937b77ede6563a6769b76991",
    "stage-plate-16x9.png": "d14519665697ab8131a20e1df33123320032fa1bfe3345c8d56316d6f937b0b4",
}


def check_sources(captures):
    """先校验整套素材的指纹与尺寸，失败时不写入或删除任何成品。"""
    guidance = ("请先复核 PANEL_SOURCE，并重新调整 SCENE_CROP / LAYOUTS；"
                "确认裁切完整后再更新 EXPECTED_SOURCES。")
    for filename, expected in EXPECTED_SOURCES.items():
        path = captures / filename
        if not path.is_file():
            raise ValueError(f"缺少已核验的原图：{path}。{guidance}")
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f"原图 SHA-256 不匹配：{path}；"
                             f"期望 {expected}，实际 {actual}。{guidance}")
        expected_size = (1304, 1144) if filename.endswith("04-settings.png") else SOURCE_SIZE
        with Image.open(path) as source:
            if source.size != expected_size:
                raise ValueError(f"原图尺寸不匹配：{path}；"
                                 f"期望 {expected_size}，实际 {source.size}。{guidance}")
    for kind, layout in LAYOUTS.items():
        if kind == "settings":
            continue
        x0, y0, x1, y1 = layout["crop"]
        px0, py0, px1, py1 = PANEL_SOURCE
        if not (x0 <= px0 < px1 <= x1 and y0 <= py0 < py1 <= y1):
            raise ValueError(f"{kind} 的裁切框未完整包含 PANEL_SOURCE。{guidance}")


def load_srgb(path):
    """按 macOS 显示器 ICC 转换颜色，保留设置窗口与图标的透明度。"""
    with Image.open(path) as source:
        profile = source.info.get("icc_profile")
        image = source.convert("RGBA" if "A" in source.getbands() else "RGB")
    if profile:
        image = ImageCms.profileToProfile(
            image, ImageCms.ImageCmsProfile(io.BytesIO(profile)), SRGB,
            outputMode=image.mode,
        )
    return image


def sf_font(size, variation):
    font = ImageFont.truetype(SF, size)
    font.set_variation_by_name(variation)
    return font


def is_cjk(ch):
    code = ord(ch)
    return (0x3000 <= code <= 0x303F or 0x4E00 <= code <= 0x9FFF
            or 0xFF00 <= code <= 0xFFEF or 0x2018 <= code <= 0x201D)


def draw_centered(base, text, latin, cjk, top, color, region_left=0, region_width=W):
    """混排 SF 键盘符号与苹方，使用同一文字基线。"""
    # SFNS 有 Shift/Command，但没有 U+21E5 TAB；Pillow 不会像 CoreText
    # 那样自动回退字体，因此显式使用系统符号字体补齐。
    symbols = ImageFont.truetype(SYMBOLS, round(latin.size * 1.25))
    runs = []
    for ch in text:
        font = symbols if ch == "⇥" else cjk if cjk and is_cjk(ch) else latin
        if runs and runs[-1][1] is font:
            runs[-1][0] += ch
        else:
            runs.append([ch, font])
    scratch = Image.new("L", (W * 2, 360), 0)
    draw = ImageDraw.Draw(scratch)
    x = 100
    for chunk, font in runs:
        baseline = 180 - round(latin.size * 0.14) if font is symbols else 180
        draw.text((x, baseline), chunk, font=font, fill=255, anchor="ls")
        x += draw.textlength(chunk, font=font)
    bounds = scratch.getbbox()
    if not bounds:
        raise ValueError(f"未能绘制文字：{text!r}")
    glyphs = scratch.crop(bounds)
    if glyphs.width > min(TEXT_MAX_WIDTH, region_width):
        raise ValueError(f"文字超出安全宽度：{text!r}（{glyphs.width}px）")
    left = region_left + (region_width - glyphs.width) // 2
    base.paste(color, (left, top, left + glyphs.width, top + glyphs.height), glyphs)
    return [left, top, left + glyphs.width, top + glyphs.height]


def wrapped_lines(text, latin, cjk, width):
    """为备选版的侧边副标题换行，保持文案逐字不变。"""
    def measure(value):
        return sum((cjk if cjk and is_cjk(ch) else latin).getlength(ch) for ch in value)
    # 中文在“预览”之后按语义换行，避免第二行只剩两个字。
    if cjk and "预览" in text:
        split_at = text.index("预览") + len("预览")
        phrases = [text[:split_at], text[split_at:]]
        if all(phrase and measure(phrase) <= width - 12 for phrase in phrases):
            return phrases
    tokens = text.split(" ") if cjk is None else list(text)
    separator = " " if cjk is None else ""
    lines, current = [], ""
    for token in tokens:
        candidate = current + separator + token if current else token
        if current and measure(candidate) > width - 12:
            lines.append(current)
            current = token
        else:
            current = candidate
    if current:
        lines.append(current)
    if separator.join(lines) != text:
        raise ValueError("换行处理改变了宣传文案")
    return lines


def crop_scene(image, box=SCENE_CROP):
    if image.size != SOURCE_SIZE:
        raise ValueError(f"桌面截图应为 {SOURCE_SIZE}，实际为 {image.size}；"
                         "素材尺寸改变后，请先复核 SCENE_CROP / LAYOUTS")
    x0, y0, x1, y1 = box
    if not (0 <= x0 < x1 <= image.width and 60 <= y0 < y1 <= image.height):
        raise ValueError(f"裁切框包含私有菜单栏或超出原图：{box}")
    if (x1 - x0) * H != (y1 - y0) * W or W / (x1 - x0) > 1.1:
        raise ValueError(f"裁切框必须为 16:10，放大不超过 1.1 倍：{box}")
    return image.convert("RGB").crop(box).resize((W, H), Image.Resampling.LANCZOS)


def build(captures, lang, row, pingfang):
    name, suffix, headline, subtitle = row
    kind = {"03-preview": "text-preview", "03b-preview-image": "image-preview",
            "04-settings": "settings"}.get(suffix, "panel")
    layout = LAYOUTS[kind]
    box = layout["crop"]
    region_left, region_width = layout.get("text_left", 0), layout.get("text_width", W)
    ui = load_srgb(captures / f"{lang}-{suffix}.png")
    if suffix == "04-settings":
        base = crop_scene(load_srgb(captures / "stage-plate-16x9.png"), box)
        size = (SETTINGS_WIDTH, round(ui.height * SETTINGS_WIDTH / ui.width))
        window = ui.resize(size, Image.Resampling.LANCZOS)
        xy = ((W - size[0]) // 2, SETTINGS_TOP)
        # 素材画布含很长的极淡阴影尾；整体下移后只有 alpha<=2 的末端落在
        # 成品外。只允许这部分自然裁掉，窗口实体与其余阴影必须完整留在画布内。
        visible = window.getchannel("A").point(lambda alpha: 255 if alpha > 2 else 0).getbbox()
        if not visible or not (0 <= xy[0] + visible[0] < xy[0] + visible[2] <= W
                               and 0 <= xy[1] + visible[1] < xy[1] + visible[3] <= H):
            raise ValueError("设置窗口或可见阴影超出画布，请调整 SETTINGS_TOP / SETTINGS_WIDTH")
        base.paste(window, xy, window.getchannel("A"))
    else:
        base = crop_scene(ui, box)

    icon_size = layout["icon_size"]
    icon = load_srgb(ICON).resize((icon_size, icon_size), Image.Resampling.LANCZOS)
    icon_xy = (region_left + (region_width - icon_size) // 2, layout["icon_top"])
    base.paste(icon, icon_xy, icon.getchannel("A"))
    if lang == "en":
        head, sub = sf_font(layout["head_en"], "Bold"), sf_font(layout["sub_en"], "Regular")
        cjk_head = cjk_sub = None
    else:
        head, sub = sf_font(layout["head_zh"], "Semibold"), sf_font(layout["sub_zh"], "Regular")
        cjk_head = ImageFont.truetype(str(pingfang), layout["head_zh"], index=PINGFANG_SEMIBOLD)
        cjk_sub = ImageFont.truetype(str(pingfang), layout["sub_zh"], index=PINGFANG_REGULAR)
    head_bounds = draw_centered(base, headline, head, cjk_head, layout["head_top"], HEADLINE_COLOR,
                                region_left, region_width)
    lines = wrapped_lines(subtitle, sub, cjk_sub, region_width) if kind == "image-preview" else [subtitle]
    line_bounds = [draw_centered(base, line, sub, cjk_sub, layout["sub_top"] + index * 52,
                                 SUBTITLE_COLOR, region_left, region_width)
                   for index, line in enumerate(lines)]
    sub_bounds = [min(b[0] for b in line_bounds), line_bounds[0][1],
                  max(b[2] for b in line_bounds), line_bounds[-1][3]]
    if head_bounds[3] >= layout["sub_top"] or sub_bounds[3] >= layout["header_limit"]:
        raise ValueError(f"标题区与下方内容重叠：{name}-{lang}")
    scale = W / (box[2] - box[0])
    panel_bounds = [round((value - box[index % 2]) * scale, 3)
                    for index, value in enumerate(PANEL_SOURCE)] if kind != "settings" else None
    return base, {"file": f"{name}-{lang}.png", "source": f"{lang}-{suffix}.png",
                  "layout": kind, "source_crop": list(box), "source_scale": scale,
                  "panel_output_bounds": panel_bounds,
                  "panel_output_width": round((PANEL_SOURCE[2] - PANEL_SOURCE[0]) * scale, 3) if panel_bounds else None,
                  "icon_bounds": [*icon_xy, icon_xy[0] + icon_size, icon_xy[1] + icon_size],
                  "headline_bounds": head_bounds, "subtitle_bounds": sub_bounds,
                  "subtitle_lines": lines}


def contact_sheet(paths, output):
    """每种语言占一行，按商店顺序排列；列数自适应，缩略图保持 16:10。"""
    cols, rows = len(TEXT["zh"]), len(TEXT)
    if any(len(entries) != cols for entries in TEXT.values()) or len(paths) != cols * rows:
        raise ValueError(f"拼图应含 {rows} 种语言、每种 {cols} 张截图，"
                         f"实际收到 {len(paths)} 个文件，TEXT 各语言数量为 "
                         f"{ {lang: len(entries) for lang, entries in TEXT.items()} }")
    thumb_w, thumb_h, gap, label_h = 640, 400, 24, 42
    sheet = Image.new("RGB", (cols * thumb_w + (cols + 1) * gap,
                              rows * (thumb_h + label_h) + (rows + 1) * gap),
                      BACKGROUND_COLOR)
    draw = ImageDraw.Draw(sheet)
    label_font = sf_font(19, "Medium")
    for index, path in enumerate(paths):
        col, row = index % cols, index // cols
        x, y = gap + col * (thumb_w + gap), gap + row * (thumb_h + label_h + gap)
        with Image.open(path) as source:
            thumb = source.convert("RGB").resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (x, y))
        draw.text((x, y + thumb_h + 10), path.name, font=label_font, fill=SUBTITLE_COLOR)
    sheet.save(output, icc_profile=SRGB_BYTES)


class ChineseArgumentParser(argparse.ArgumentParser):
    """统一命令行帮助和参数错误的中文提示。"""

    def format_usage(self):
        return super().format_usage().replace("usage: ", "用法：", 1)

    def format_help(self):
        return super().format_help().replace("usage: ", "用法：", 1)

    def error(self, message):
        for original, translated in (
            ("the following arguments are required:", "缺少必填参数："),
            ("unrecognized arguments:", "无法识别的参数："),
            ("ignored explicit argument", "不接受附加参数值"),
            ("expected one argument", "需要一个参数值"),
            ("argument ", "参数 "),
        ):
            message = message.replace(original, translated)
        self.print_usage(sys.stderr)
        self.exit(2, f"参数错误：{message}\n")


def main():
    parser = ChineseArgumentParser(description=__doc__, add_help=False,
                                   formatter_class=argparse.RawDescriptionHelpFormatter)
    parser._positionals.title = "位置参数"
    parser._optionals.title = "选项"
    parser.add_argument("-h", "--help", action="help", help="显示帮助信息并退出")
    parser.add_argument("captures", type=Path, metavar="素材目录",
                        help="含中英 PNG 与 stage-plate-16x9.png 的 raw/ 目录")
    parser.add_argument("--include-image-preview", action="store_true",
                        help="另输出两张照片预览备选到 out/alt/，主图仍为十张；默认清理旧备选")
    args = parser.parse_args()
    captures = args.captures.resolve()
    output = captures.parent / "out"
    screenshots = output / "screenshots"
    try:
        check_sources(captures)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    required = [captures / "stage-plate-16x9.png", ICON, Path(SF), Path(SYMBOLS)]
    for path in required:
        if not path.is_file():
            parser.error(f"缺少输入文件：{path}")
    fonts = sorted(PINGFANG_ROOT.glob("*/AssetData/PingFang.ttc"))
    if not fonts:
        parser.error(f"在 {PINGFANG_ROOT} 下找不到苹方字体 PingFang.ttc")
    screenshots.mkdir(parents=True, exist_ok=True)
    paths, records = [], []
    for lang in ("zh", "en"):
        for row in TEXT[lang]:
            image, record = build(captures, lang, row, fonts[0])
            path = screenshots / record["file"]
            image.save(path, icc_profile=SRGB_BYTES)
            with Image.open(path) as check:
                if check.size != (W, H) or check.mode != "RGB":
                    raise ValueError(f"成品尺寸或颜色模式不符合要求：{path}")
            paths.append(path)
            records.append(record)
            print(f"已生成 {path}")
    contact_sheet(paths, output / "contact-sheet.png")
    alternatives = []
    if args.include_image_preview:
        (output / "alt").mkdir(parents=True, exist_ok=True)
        for lang in ("zh", "en"):
            _, _, headline, subtitle = next(row for row in TEXT[lang] if row[0] == "03-preview")
            row = ("03-preview-image", "03b-preview-image", headline, subtitle)
            image, record = build(captures, lang, row, fonts[0])
            path = output / "alt" / record["file"]
            image.save(path, icc_profile=SRGB_BYTES)
            alternatives.append(record)
            print(f"已生成 {path}")
    else:
        # 只清理本脚本拥有的两张备选，不删除目录或用户放入的其他文件。
        for lang in ("zh", "en"):
            (output / "alt" / f"03-preview-image-{lang}.png").unlink(missing_ok=True)
    metadata = {"size": [W, H], "mode": "RGB", "color_space": "sRGB",
                "source_scene_crop": list(SCENE_CROP),
                "settings_width": SETTINGS_WIDTH, "settings_top": SETTINGS_TOP,
                "screenshots": records, "alternatives": alternatives}
    (output / "screenshot-layout.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    print(f"已生成 {output / 'contact-sheet.png'}")


if __name__ == "__main__":
    main()
