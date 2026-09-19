#!/usr/bin/env python3
"""从真实 UI 截图合成 Mac App Store 商店截图（2560×1600，art/store/）。

商店截图是合成图：统一的渐变背景板 + 应用图标 + 标题 + 副标题 + 真实 UI 截图。
背景板 `art/store/_background-plate.png` 是从初版截图反推出来的，不要手改。

## 一、先用应用自带的截图开关采集 UI

应用里有一组只为截图存在的启动参数（见 AppDelegate / PanelRootView / SettingsView）：
`-forceDark` 强制深色、`-opaquePanel` 面板不透明、`-showPanel` 启动即拉起面板、
`-demoSearch <词>` 预置搜索词、`-demoPreview` 启动即开预览、
`-showSettings -settingsTab <0-4>` 直接打开设置的某个标签页。

演示数据要先灌进 `~/Library/Application Support/Copyo/Copyo.store`，别拿自己的真实剪贴板
去拍——那会把私人内容发到 App Store 上。

    APP=build/Build/Products/Debug/Copyo.app
    for lang in en zh-Hans; do
      open $APP --args -AppleLanguages "($lang)" -forceDark -opaquePanel -showPanel
      sleep 6 && screencapture -x raw_01.png && pkill -x Copyo
      # 02 加 -demoSearch Q3；03 加 -demoPreview；04 用 -showSettings -settingsTab 3
    done

然后把面板／设置窗口从整屏截图里裁出来，放进 CAPTURE_DIR：
面板存 `ui_01_<lang>.png`（整条面板，带满宽），设置窗口存 `ui_04_<lang>.png`（带圆角透明）。

## 二、合成

    python3 scripts/make-store-shots.py <CAPTURE_DIR>

文案改这里的 TEXT 表。注意：**副标题不能承诺应用做不到的事**。1.0 (4) 移除自动粘贴后，
初版截图里的「then ↩ to paste」「↩ 直接粘贴」「粘贴」全部作废——那正是 2.4.5 拒审的点。
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parent.parent
STORE = REPO / "art" / "store"
PLATE = STORE / "_background-plate.png"
ICON = REPO / "art" / "icon" / "icon-512.png"

W, H = 2560, 1600
SF = "/System/Library/Fonts/SFNS.ttf"
PINGFANG = ("/System/Library/AssetsV2/com_apple_MobileAsset_Font8/"
            "86ba2c91f017a3749571a82f2c6d890ac7ffb2fb.asset/AssetData/PingFang.ttc")
PINGFANG_SEMIBOLD, PINGFANG_REGULAR = 11, 3

# 版式参数由初版截图实测而来，改动会破坏与既有截图的一致性
ICON_XY, ICON_SIZE = (1194, 179), 175
HEADLINE_TOP, SUBTITLE_TOP = 448, 590
HEADLINE_COLOR, SUBTITLE_COLOR = (255, 255, 255), (190, 192, 197)
WINDOW_RECT = (870, 738, 820, 689)   # 设置窗口贴图位置 x, y, w, h

TEXT = {
    "en": [
        ("01-panel", "Everything you copied, one key away",
         "Press ⇧⌘V — your clipboard history slides up", "panel"),
        ("02-search", "Type to filter",
         "Search by content, source app or file name — no clicking first", "panel"),
        ("03-preview", "Space to peek",
         "Preview text, images and files without leaving the panel", "panel"),
        ("04-shortcuts", "Hands stay on the keyboard",
         "Summon, search, copy, preview — and ⇧⌘V is yours to remap", "window"),
    ],
    "zh": [
        ("01-panel", "复制过的一切，随叫随到",
         "按下 ⇧⌘V，剪贴板历史从屏幕底部滑出", "panel"),
        ("02-search", "即输即搜",
         "按内容、来源应用、文件名过滤，不用先点搜索框", "panel"),
        ("03-preview", "空格，先看一眼",
         "大图预览文本、图片和文件，不用离开面板", "panel"),
        ("04-shortcuts", "手不离键盘",
         "呼出、导航、复制、预览，全程快捷键；⇧⌘V 可自定义", "window"),
    ],
}


def sf_font(size, variation):
    font = ImageFont.truetype(SF, size)
    font.set_variation_by_name(variation)
    return font


def is_cjk(ch):
    o = ord(ch)
    return (0x3000 <= o <= 0x303F or 0x4E00 <= o <= 0x9FFF
            or 0xFF00 <= o <= 0xFFEF or 0x2018 <= o <= 0x201D)


def draw_centered(base, text, latin, cjk, top, color):
    """逐字符选字体后整体居中。PingFang 没有 ⇧⌘ 这些符号，必须回退到 SF。"""
    runs = []
    for ch in text:
        font = cjk if (cjk and is_cjk(ch)) else latin
        if runs and runs[-1][1] is font:
            runs[-1][0] += ch
        else:
            runs.append([ch, font])
    pad = 300
    scratch = Image.new("L", (W + 2 * pad, 420), 0)
    draw = ImageDraw.Draw(scratch)
    x = pad
    for chunk, font in runs:
        draw.text((x, 120), chunk, font=font, fill=255)
        x += draw.textlength(chunk, font=font)
    box = scratch.getbbox()
    if box is None:
        return
    glyphs = scratch.crop(box)
    mask = Image.new("L", (W, H), 0)
    mask.paste(glyphs, ((W - glyphs.width) // 2, top))
    base.paste(Image.new("RGB", (W, H), color), (0, 0), mask)


def build(headline, subtitle, ui_path, kind, lang):
    base = Image.open(PLATE).convert("RGB")
    icon = Image.open(ICON).convert("RGBA").resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
    base.paste(icon, ICON_XY, icon)

    if lang == "en":
        head, sub, cjk_head, cjk_sub = sf_font(83, "Bold"), sf_font(44, "Regular"), None, None
    else:
        head, sub = sf_font(79, "Semibold"), sf_font(40, "Regular")
        cjk_head = ImageFont.truetype(PINGFANG, 79, index=PINGFANG_SEMIBOLD)
        cjk_sub = ImageFont.truetype(PINGFANG, 40, index=PINGFANG_REGULAR)
    draw_centered(base, headline, head, cjk_head, HEADLINE_TOP, HEADLINE_COLOR)
    draw_centered(base, subtitle, sub, cjk_sub, SUBTITLE_TOP, SUBTITLE_COLOR)

    ui = Image.open(ui_path)
    if kind == "panel":
        # 面板满宽贴底。面板高度由应用固定，屏幕越宽贴出来越扁，
        # 所以同一批截图必须在同一台机器上采集，否则卡片大小对不上。
        ui = ui.convert("RGB")
        height = int(ui.height * (W / ui.width))
        base.paste(ui.resize((W, height), Image.LANCZOS), (0, H - height))
    else:
        x, y, w, h = WINDOW_RECT
        ui = ui.convert("RGBA").resize((w, h), Image.LANCZOS)
        base.paste(ui, (x, y), ui)
    return base


def main():
    if len(sys.argv) != 2:
        sys.exit(f"用法：{Path(sys.argv[0]).name} <采集目录>")
    captures = Path(sys.argv[1])
    for lang, rows in TEXT.items():
        for name, headline, subtitle, kind in rows:
            ui = captures / f"ui_{name.split('-')[0]}_{lang}.png"
            if not ui.exists():
                sys.exit(f"缺少采集文件：{ui}")
            out = STORE / f"{name}-{lang}.png"
            build(headline, subtitle, ui, kind, lang).save(out)
            print("wrote", out.relative_to(REPO))


if __name__ == "__main__":
    main()
