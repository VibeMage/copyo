#!/usr/bin/env python3
"""从模拟器截图合成 iOS / iPadOS 商店截图（art/store-ios/）。

版式跟 iOS 设计稿走，**不沿用 Mac 那套深色渐变底板**（那是 Mac 1.0 的旧风格）：
设计稿画布是暖白底、系统字体、内容优先，红蓝错位只做点缀（设计规格第一节「品牌与风格」）。
所以这里是：暖白底 + 小号应用图标 + 深色标题 + 灰色副标题 + 带机身圆角与柔和投影的真实界面。

## 一、采集

截图全部来自应用自带的 `-demoData` 样例库（设计稿第六节的样例数据），**不要拿自己的真实
剪贴板去拍**。演示模式下 iCloud 胶囊固定为「已同步」，不依赖模拟器有没有登录 iCloud。

    APP=build/Build/Products/Debug-iphonesimulator/Copyo.app
    PHONE="iPhone 17 Pro Max"      # 6.9 英寸，1320×2868
    PAD="iPad Pro 13-inch (M5)"    # 13 英寸，2064×2752（竖屏）
    xcrun simctl status_bar "$PHONE" override --time 9:41 --batteryState discharging \\
        --batteryLevel 100 --cellularBars 4 --wifiBars 3
    xcrun simctl launch --terminate-running-process "$PHONE" dev.vibemage.Copyo \\
        -demoData -skipOnboarding -demoScreen history -demoTheme light -AppleLanguages "(zh-Hans)"
    xcrun simctl io "$PHONE" screenshot <CAPTURE_DIR>/phone-zh-history.png

文件名规则：`<phone|pad>-<zh|en>-<SHOTS 表里的 source>.png`。
`scripts/capture-store-shots-ios.sh` 把上面这套对 SHOTS 表里的每一项跑一遍。

## 二、合成

    python3 scripts/make-store-shots-ios.py <CAPTURE_DIR>

副标题**不能承诺应用做不到的事**（Mac 1.0 (3) 因此吃过 2.4.5）：iOS 版不能后台读剪贴板、
不能自动粘贴、键盘扩展不在这一版里。
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "art" / "store-ios"
ICON = REPO / "art" / "icon" / "icon-512.png"

SF = "/System/Library/Fonts/SFNS.ttf"
PINGFANG = ("/System/Library/AssetsV2/com_apple_MobileAsset_Font8/"
            "86ba2c91f017a3749571a82f2c6d890ac7ffb2fb.asset/AssetData/PingFang.ttc")
PINGFANG_SEMIBOLD, PINGFANG_REGULAR = 11, 3

# 设计稿的暖白画布与文字色（design-spec 2.1：label #000 / secondaryLabel 60%）
BACKGROUND = (244, 242, 237)
HEADLINE_COLOR = (22, 22, 26)          # 图标内容条色 #16161A
SUBTITLE_COLOR = (110, 110, 118)
BEZEL_COLOR = (22, 22, 26)

# 每种设备的画布与版式。数值是按 App Store 要求的像素尺寸排出来的
DEVICES = {
    # 6.9 英寸 iPhone：1320×2868
    "phone": dict(size=(1320, 2868), icon=112, icon_top=130, head_top=290, sub_gap=34, line_gap=22,
                  head_pt=(92, 88), sub_pt=(46, 44), shot_gap=80, shot_width=1060, bottom=40,
                  corner=150, bezel=22, max_text=1160),
    # 13 英寸 iPad：2064×2752（竖屏）
    "pad": dict(size=(2064, 2752), icon=120, icon_top=130, head_top=300, sub_gap=38, line_gap=26,
                head_pt=(104, 100), sub_pt=(52, 50), shot_gap=90, shot_width=1640, bottom=40,
                corner=64, bezel=26, max_text=1800),
}

# (输出序号-名称, 采集来源, {语言: (标题, 副标题)})
SHOTS = {
    "phone": [
        ("01-history", "history", {
            "zh": ("Mac 上复制的，口袋里都有", "经你自己的 iCloud 同步，随时搜、随时复制"),
            "en": ("Everything you copied on your Mac", "Synced through your own iCloud"),
        }),
        ("02-search", "history-search", {
            "zh": ("即输即搜", "文本、链接、图片、颜色，一键按类型筛选"),
            "en": ("Find it as you type", "Filter by text, links, images or colors"),
        }),
        ("03-detail", "detail-text", {
            "zh": ("轻点就复制", "卡片轻点即复制，打开详情看全文"),
            "en": ("Tap to copy", "One tap copies a clip — open it to see everything"),
        }),
        ("04-share", "share", {
            "zh": ("从任何 App 存进来", "分享面板里选 Copyo，Mac 上也能看到"),
            "en": ("Save from any app", "Share to Copyo — it shows up on your Mac too"),
        }),
        ("05-quicksave", "settings-quicksave", {
            "zh": ("一按，存下剪贴板", "操作按钮、控制中心、轻点背面都能用"),
            "en": ("One press saves your clipboard", "Action Button, Control Center or Back Tap"),
        }),
        ("06-pinboard", "pinboard-content", {
            "zh": ("常用的，钉在 Pinboard", "把常用片段分组收好，每台设备都在"),
            "en": ("Keep favorites on Pinboards", "Group the clips you reuse, on every device"),
        }),
    ],
    "pad": [
        ("01-history", "sidebar-history", {
            "zh": ("在 iPad 上，一屏看全", "侧栏分类、卡片网格，支持硬件键盘快捷键"),
            "en": ("Your whole history at a glance", "Sidebar, card grid and hardware keyboard shortcuts"),
        }),
        ("02-kinds", "sidebar-color", {
            "zh": ("按类型，一键筛选", "文本、链接、图片、颜色、文件各归各位"),
            "en": ("Every kind in its place", "Text, links, images, colors and files, one tap apart"),
        }),
        ("03-pinboard", "sidebar-pinboard", {
            "zh": ("常用的，钉在 Pinboard", "把常用片段分组收好，每台设备都在"),
            "en": ("Keep favorites on Pinboards", "Group the clips you reuse, on every device"),
        }),
        ("04-share", "share", {
            "zh": ("从任何 App 存进来", "分享面板里选 Copyo，Mac 上也能看到"),
            "en": ("Save from any app", "Share to Copyo — it shows up on your Mac too"),
        }),
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


def fonts(lang, device, weight):
    """标题用 Semibold、副标题用 Regular；中文逐字符在苹方与 SF 之间切换（苹方的拉丁字母偏窄）"""
    cfg = DEVICES[device]
    if weight == "head":
        size = cfg["head_pt"][0 if lang == "en" else 1]
        latin = sf_font(size, "Bold" if lang == "en" else "Semibold")
        cjk = None if lang == "en" else ImageFont.truetype(PINGFANG, size, index=PINGFANG_SEMIBOLD)
    else:
        size = cfg["sub_pt"][0 if lang == "en" else 1]
        latin = sf_font(size, "Regular")
        cjk = None if lang == "en" else ImageFont.truetype(PINGFANG, size, index=PINGFANG_REGULAR)
    return latin, cjk


def render_line(text, latin, cjk):
    """把一行字画成灰度蒙版，返回裁到字形包围盒的图"""
    runs = []
    for ch in text:
        font = cjk if (cjk and is_cjk(ch)) else latin
        if runs and runs[-1][1] is font:
            runs[-1][0] += ch
        else:
            runs.append([ch, font])
    scratch = Image.new("L", (4000, 400), 0)
    draw = ImageDraw.Draw(scratch)
    x = 40
    for chunk, font in runs:
        draw.text((x, 100), chunk, font=font, fill=255)
        x += draw.textlength(chunk, font=font)
    box = scratch.getbbox()
    return scratch.crop(box) if box else None


def wrap(text, latin, cjk, max_width):
    """放得下就一行；放不下在最接近中点的空格处折成两行（中文标题都短，只有英文会折）"""
    whole = render_line(text, latin, cjk)
    if whole.width <= max_width:
        return [whole]
    spaces = [i for i, ch in enumerate(text) if ch == " "]
    for i in sorted(spaces, key=lambda i: abs(i - len(text) / 2)):
        lines = [render_line(text[:i], latin, cjk), render_line(text[i + 1:], latin, cjk)]
        if all(line.width <= max_width for line in lines):
            return lines
    sys.exit(f"「{text}」两行也放不下（上限 {max_width}px），改短文案")


def paste_centered(base, glyphs, top, color):
    x = (base.width - glyphs.width) // 2
    base.paste(Image.new("RGB", glyphs.size, color), (x, top), glyphs)
    return top + glyphs.height


def framed(shot, cfg):
    """真实界面 → 缩放 + 圆角 + 深色机身边 + 柔和投影，返回 RGBA"""
    w = cfg["shot_width"]
    h = round(shot.height * w / shot.width)
    shot = shot.convert("RGB").resize((w, h), Image.LANCZOS)
    bezel, corner = cfg["bezel"], cfg["corner"]
    fw, fh = w + 2 * bezel, h + 2 * bezel
    pad = 80
    canvas = Image.new("RGBA", (fw + 2 * pad, fh + 2 * pad), (0, 0, 0, 0))

    shadow = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (pad, pad + 24, pad + fw, pad + fh + 24), radius=corner + bezel, fill=70)
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas.paste(Image.new("RGBA", canvas.size, (40, 30, 20, 255)), (0, 0), shadow)

    body = Image.new("L", (fw, fh), 0)
    ImageDraw.Draw(body).rounded_rectangle((0, 0, fw - 1, fh - 1), radius=corner + bezel, fill=255)
    canvas.paste(Image.new("RGBA", (fw, fh), BEZEL_COLOR + (255,)), (pad, pad), body)

    screen = Image.new("L", (w, h), 0)
    ImageDraw.Draw(screen).rounded_rectangle((0, 0, w - 1, h - 1), radius=corner, fill=255)
    canvas.paste(shot, (pad + bezel, pad + bezel), screen)
    return canvas, pad


def build(device, lang, headline, subtitle, shot_path):
    cfg = DEVICES[device]
    base = Image.new("RGB", cfg["size"], BACKGROUND)

    icon = Image.open(ICON).convert("RGBA").resize((cfg["icon"], cfg["icon"]), Image.LANCZOS)
    base.paste(icon, ((base.width - icon.width) // 2, cfg["icon_top"]), icon)

    head_latin, head_cjk = fonts(lang, device, "head")
    sub_latin, sub_cjk = fonts(lang, device, "sub")
    top = cfg["head_top"]
    for glyphs in wrap(headline, head_latin, head_cjk, cfg["max_text"]):
        top = paste_centered(base, glyphs, top, HEADLINE_COLOR) + cfg["line_gap"]
    top += cfg["sub_gap"] - cfg["line_gap"]
    for glyphs in wrap(subtitle, sub_latin, sub_cjk, cfg["max_text"]):
        top = paste_centered(base, glyphs, top, SUBTITLE_COLOR) + cfg["line_gap"]

    # 机身接在文字下面，放不下就等比缩小——英文标题折成两行时整机往下让，而不是压住文字
    shot = Image.open(shot_path)
    shot_top = top + cfg["shot_gap"]
    avail_h = base.height - shot_top - cfg["bottom"] - 2 * cfg["bezel"]
    width = min(cfg["shot_width"], int(avail_h * shot.width / shot.height))
    frame, pad = framed(shot, dict(cfg, shot_width=width))
    base.paste(frame, ((base.width - frame.width) // 2, shot_top - pad), frame)
    return base


def main():
    if len(sys.argv) != 2:
        sys.exit(f"用法：{Path(sys.argv[0]).name} <采集目录>")
    captures = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    for device, rows in SHOTS.items():
        for name, source, texts in rows:
            for lang, (headline, subtitle) in texts.items():
                shot = captures / f"{device}-{lang}-{source}.png"
                if not shot.exists():
                    sys.exit(f"缺少采集文件：{shot}")
                img = build(device, lang, headline, subtitle, shot)
                if img.size != DEVICES[device]["size"]:
                    sys.exit(f"尺寸不对：{img.size}")
                out = OUT / f"{device}-{name}-{lang}.png"
                img.save(out)
                print("wrote", out.relative_to(REPO))


if __name__ == "__main__":
    main()
