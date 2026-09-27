#!/bin/bash
# 生成 Xcode 资产目录里的 App 图标。两个平台走两条完全不同的路：
#
#   ./scripts/make-icon.sh [master.png]   macOS：把 1024 主图按比例缩成 10 个规格
#                                         （默认 art/icon-master.png）
#   ./scripts/make-icon.sh --ios          iOS：按 art/icon/copyo-icon-spec.md 重新绘制
#                                         浅色 / 深色 / 单色三份 1024
#
# iOS 不能复用 macOS 那张主图。macOS 的主图是「透明底 + 内缩 9.8% 的圆角方块」——
# 圆角和留白都画在像素里，因为 macOS 图标的外形本身就是素材的一部分。iOS 相反：
# 系统自己用超椭圆裁切，素材必须满幅且**不带 alpha**。直接把 macOS 那张塞进
# iOS 资产目录会连挨两刀：艺术品只占图块的 80%，再被系统圆角切一次，
# 主屏上就是一个小一号、圆角套圆角的图标；而且带 alpha 的 iOS 图标上传时
# 历来会触发 ITMS-90717 Invalid App Store Icon。
#
# 所以 iOS 这条路不缩放、不裁切，而是拿 spec 里那套「以边长为 1」的比例重画一遍，
# 把原本相对**内缩方块**的比例改为相对**整幅画布**——卡片因此放大到 1024 的网格上，
# 视觉占比与 macOS 图标在它自己的圆角方块里一致。
#
# 依赖：`--ios` 这条路需要 **Pillow**（`import PIL`），macOS 那条路只用系统自带的
# sips / awk，不需要。Pillow **不是** macOS 的一部分——系统与 Xcode 自带的 python3 都不含它，
# 本机现在能跑，只是因为装了一份用户级的（~/Library/Python/3.9/lib/python/site-packages）。
# 换机器、升级系统重置 user site-packages、或者在 CI 上跑，它都会消失，
# 所以下面显式检查一次——否则失败现场是一条裸的英文 ModuleNotFoundError 栈，
# 与本脚本其余所有出错分支的中文诊断完全不是一回事。缺了就装：
#   python3 -m pip install --user Pillow
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--ios" ]]; then
  # iOS 图标由脚本现画，不吃任何输入图片——一张栅格主图没法派生出深色与单色变体。
  python3 - "CopyoIOS/Assets.xcassets/AppIcon.appiconset" <<'PY'
# -*- coding: utf-8 -*-
"""按 art/icon/copyo-icon-spec.md 绘制 iOS App 图标的三个外观变体。

几何全部来自 spec 的「几何（以图标边长为 1）」表。spec 里那些比例的基准是**内缩后的
圆角方块**（1024 主图里量得的卡片是 412×458 @ (306,283)，正是 0.50/0.556/0.25/0.222
乘以 824），iOS 满幅没有内缩方块，基准换成整幅 1024，卡片同比放大 1.24 倍。
"""
import sys, math, pathlib

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter
except ImportError:
    # 见脚本头部「依赖」一段：Pillow 不随 macOS 提供，装在用户目录下，换机器/升级系统/CI 都会没有
    sys.exit("缺少 Pillow：iOS 图标是脚本现画的，需要 PIL 做圆角光栅化与高斯模糊。\n"
             "安装：python3 -m pip install --user Pillow\n"
             f"（当前解释器：{sys.executable}）")

DEST = pathlib.Path(sys.argv[1])

EDGE = 1024          # iOS 资产目录只要 1024 这一档，其余尺寸由 Xcode 自己派生
SS = 4               # 超采样倍数。卡片圆角与内容条圆头直接在 1024 上光栅化会有锯齿，
                     # spec「光栅化规则」要求 8–16 倍超采样；这里只有一档目标尺寸，
                     # 4 倍 + 面积平均降采已经看不出台阶，再高只是白烧内存（4096² RGBA ≈ 67MB）。

# ---- 几何（spec 几何表，基准改为整幅画布）------------------------------------
# 顺序照抄 spec 几何表的写法：left / top / 宽 / 高，四个值都是相对整幅画布的比例
CARD = (0.25, 0.222, 0.50, 0.556)
CARD_R = 0.078
OFFSET = (0.030, 0.025)             # 红蓝错位层的 ±偏移
GLOW_R = 0.055                      # 发光半径（spec 几何表）；近处那一档辉光按它取外扩与模糊
# 外层氛围光的偏移 = 错位偏移 × 8。这一档不是「卡片边上的光」而是 spec 选定方向里
# 「**各自**发光」的那个氛围场：主图上左上角整片是红的、右下角整片是蓝的。
# 用错位层那个 ±30/±25px 的偏移去推一团半径上百像素的弥散，两团几乎完全重合，
# 滤色叠完只剩一片中性品红——实测原参数下 (150,150) 是 (41,27,42)、(880,880) 是
# (21,20,35)，红蓝分不出来。推远到 ±246/±205px 才让两团各自占住一个对角。
WASH_SPREAD = 8
# 外扩从原来的 84.5px（= GLOW_R×1.5×1024）砍到 40：两团要靠偏移拉开，各自再摊大
# 只会让它们在中间重新糊到一起，正是上面那片中性品红的成因之一。模糊基本不动（原 169px）。
WASH_GROW = 40
WASH_BLUR = 160
WASH_ALPHA = 0.36
# 氛围光在离画布中心 0.52～0.70 边长之间淡出到 0。四角离中心 0.707 边长，
# 而 (150,150)/(880,880) 这类「场心」只有 0.50——所以这条淡出只吃四角，
# 不碰四边中点（超椭圆裁切之后四边中点是露出来的，四角不是）。
# 没有它，推远后的氛围光会把左上角顶到 (84,20,36)、右下角顶到 (11,47,87)，
# spec 的外圈色 #08060B 就只剩另外两个角还在。
WASH_FADE = (0.52, 0.70)
BAR_H, BAR_GAP, CARD_PAD = 0.052, 0.048, 0.062
BAR_WIDTHS = (1.00, 0.76, 0.88, 0.60)   # 四条内容条 = 剪贴板缓存的四种内容类型


def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ---- 三个外观变体 --------------------------------------------------------------
# bg 为 None 表示透明底，由系统补背景——只有单色变体这么做，理由见下面那段注释。
VARIANTS = {
    'AppIcon.png': {
        # 浅色（默认）外观。**必须不带 alpha**，否则上传触发 ITMS-90717。
        'bg': (rgb('#1B1620'), rgb('#08060B')),
        'ghosts': (rgb('#FF2D55'), rgb('#0A84FF')),
        'card': rgb('#F7F3EA'),
        'bars': (rgb('#16161A'), rgb('#FF2D55'), rgb('#16161A'), rgb('#0A84FF')),
        'glow': 1.0,
        'alpha': False,
    },
    'AppIcon-Dark.png': {
        # 深色外观刻意保留不透明底。Apple 允许深色变体用透明底让系统灰渐变透出来，
        # 但本图标的底色渐变本身就是品牌标记的一部分，交给系统补会换成另一种灰。
        # 代价是整体要压暗——深色主屏上一块高亮骨白卡片会刺眼得像个手电筒。
        'bg': (rgb('#141019'), rgb('#040308')),
        'ghosts': (rgb('#E02449'), rgb('#0A6FD6')),
        'card': rgb('#DCD5C6'),
        'bars': (rgb('#121216'), rgb('#E02449'), rgb('#121216'), rgb('#0A6FD6')),
        'glow': 0.62,
        'alpha': False,
    },
    'AppIcon-Tinted.png': {
        # 单色外观：系统按**亮度**把这张图映射到用户选的色相上，所以这里必须是
        # 一份有意设计过的灰度稿，而不是让系统自己去灰化彩色稿。
        # 红 #FF2D55 与蓝 #0A84FF 的相对亮度只差 0.36 与 0.45——自动灰化后两层错位
        # 会塌成两块几乎分不开的中灰，「套印不准」这个品牌标记当场消失。
        # 这里手工把两层拉开重建同一层次，且两处的灰阶各自按**背景**定：
        #   错位层 0.50 / 0.76——它们只在卡片外沿露出来，要压得住系统那块深色底，
        #     所以整体提亮，仍保持「左上层暗、右下层亮」的前后关系；
        #   内容条 2/4 用 0.38 / 0.58——它们压在接近纯白的卡片上，提亮反而看不见，
        #     只能往下压，但顺序与错位层一致，「红=上层、蓝=下层」的对应还在。
        # 底留透明——单色外观的背景由系统画，自带不透明底只会变成一整块被染色的板子，
        # 卡片与内容条的明暗对比全被抹平。
        'bg': None,
        'ghosts': (rgb('#808080'), rgb('#C2C2C2')),
        'card': rgb('#FFFFFF'),
        'bars': (rgb('#000000'), rgb('#616161'), rgb('#000000'), rgb('#949494')),
        'glow': 0.40,
        'alpha': True,
    },
}


def radial_background(inner, outer):
    """径向渐变底，中心 50% / 16%（spec 颜色表）。

    逐像素算而不是把小图放大——中心偏上 16% 的渐变在放大时会在暗部出现色带，
    1024² 纯 Python 也就一秒。左右对称，只算半行再镜像。
    """
    # 归一化用的不是一个固定半径，而是**同方向射线打到画布边界的距离**：这样四角、四边
    # 都恰好 t=1，落在 spec 的外圈色 #08060B 上。换成固定半径就落不全——中心偏上 16%
    # 使上方两角只有 537px、下方两角有 1000px，任何一个半径都只能照顾其中一头：
    # 原来的 0.92 让上方两角停在 t=0.57（成品实测 (24,19,27)，离 #08060B 差着一截），
    # 给满 1.0 更亮。
    cx, cy = EDGE * 0.5, EDGE * 0.16
    half = EDGE // 2
    buf = bytearray()
    for y in range(EDGE):
        dy = y - cy
        # 射线撞到上／下边界所需的倍数；正好在中心那一行取无穷大，方向完全由 sx 定
        sy = (cy / -dy) if dy < 0 else ((EDGE - cy) / dy if dy > 0 else float('inf'))
        row = bytearray()
        for x in range(half):
            # 左半幅 x < cx 恒成立，射线在 x 方向必定撞左边界，sx 一定是有限值，
            # 所以 min(sx, sy) 不会是无穷大
            sx = cx / (cx - x)
            t = min(1.0, 1.0 / min(sx, sy))
            # 平方过渡：线性渐变的中心亮斑会显得是一块扁平的圆盘
            t *= t
            for i in range(3):
                row.append(int(inner[i] + (outer[i] - inner[i]) * t + 0.5))
        buf += row
        # 镜像右半行（每像素 3 字节，按 3 字节一组倒序）
        buf += b''.join(bytes(row[i:i + 3]) for i in range(len(row) - 3, -1, -3))
    return Image.frombytes('RGB', (EDGE, EDGE), bytes(buf))


_WASH_FADE_MASK = None


def wash_fade_mask():
    """氛围光的四角淡出蒙版（见 WASH_FADE）。只取决于画布几何，与外观变体无关，算一次缓存。"""
    global _WASH_FADE_MASK
    if _WASH_FADE_MASK is None:
        r0, r1 = (EDGE * f for f in WASH_FADE)
        c = EDGE / 2.0
        half = EDGE // 2
        buf = bytearray()
        for y in range(EDGE):
            dy2 = (y - c) ** 2
            row = bytearray()
            for x in range(half):
                u = min(1.0, max(0.0, (math.sqrt((x - c) ** 2 + dy2) - r0) / (r1 - r0)))
                # smoothstep 而不是线性：线性淡出会在起点留一道看得见的硬转折
                row.append(int(255 * (1 - u * u * (3 - 2 * u)) + 0.5))
            buf += row
            buf += bytes(reversed(row))
        _WASH_FADE_MASK = Image.frombytes('L', (EDGE, EDGE), bytes(buf))
    return _WASH_FADE_MASK


def rect_px(frac, dx=0.0, dy=0.0, grow=0.0, scale=1):
    """把比例矩形换算成像素矩形；dx/dy 为错位偏移，grow 为四周外扩。"""
    left, top, w, h = frac
    x0 = (left + dx) * EDGE - grow
    y0 = (top + dy) * EDGE - grow
    return [p * scale for p in (x0, y0, x0 + w * EDGE + 2 * grow, y0 + h * EDGE + 2 * grow)]


def glow_mask(dx, dy, grow, blur):
    """错位卡片的模糊蒙版。不做超采样——半径几十像素的高斯模糊本身就抹平了锯齿。"""
    mask = Image.new('L', (EDGE, EDGE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        rect_px(CARD, dx, dy, grow), radius=CARD_R * EDGE + grow, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(blur))


def render(spec):
    ox, oy = OFFSET
    wx, wy = ox * WASH_SPREAD, oy * WASH_SPREAD
    glow_r = GLOW_R * EDGE
    # 两档辉光，职责不同，所以偏移也不同：
    #   近处一档贴着卡片边跑，画的是「套印不准」本身，偏移就是错位偏移；
    #   外面一档（WASH_SPREAD）画的是氛围场，要的是左上整片红、右下整片蓝，必须推远，
    #     并且带四角淡出（fade=True），否则推远之后四角就不是 spec 的外圈色了。
    # 只画近处那一档时，错位层会像贴纸一样硬生生浮在底色上。
    layers = [
        (-wx, -wy, spec['ghosts'][0], WASH_GROW, WASH_BLUR, WASH_ALPHA, True),
        (+wx, +wy, spec['ghosts'][1], WASH_GROW, WASH_BLUR, WASH_ALPHA, True),
        (-ox, -oy, spec['ghosts'][0], glow_r * 0.5, glow_r, 0.55, False),
        (+ox, +oy, spec['ghosts'][1], glow_r * 0.5, glow_r, 0.55, False),
    ]

    if spec['bg'] is None:
        base = Image.new('RGBA', (EDGE, EDGE), (0, 0, 0, 0))
    else:
        base = radial_background(*spec['bg']).convert('RGBA')

    for dx, dy, colour, grow, blur, alpha, fade in layers:
        mask = glow_mask(dx, dy, grow, blur)
        if fade:
            mask = ImageChops.multiply(mask, wash_fade_mask())
        a = alpha * spec['glow']
        if spec['bg'] is None:
            # 透明底只能用普通混合：screen 需要一个不透明的底才有意义
            layer = Image.new('RGBA', (EDGE, EDGE), colour + (0,))
            layer.putalpha(mask.point(lambda v: int(v * a)))
            base = Image.alpha_composite(base, layer)
        else:
            # 滤色（screen）而不是普通混合——发光是加色，普通混合会把底色盖掉，
            # 四层叠完中心就成了一块死板的纯色区
            lit = Image.new('RGB', (EDGE, EDGE), (0, 0, 0))
            lit.paste(Image.new('RGB', (EDGE, EDGE), colour),
                      mask=mask.point(lambda v: int(v * a)))
            base = ImageChops.screen(base.convert('RGB'), lit).convert('RGBA')

    # ---- 卡片与内容条：超采样绘制 ----
    art = Image.new('RGBA', (EDGE * SS, EDGE * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)
    radius = CARD_R * EDGE * SS
    draw.rounded_rectangle(rect_px(CARD, -ox, -oy, scale=SS), radius=radius,
                           fill=spec['ghosts'][0] + (255,))
    draw.rounded_rectangle(rect_px(CARD, +ox, +oy, scale=SS), radius=radius,
                           fill=spec['ghosts'][1] + (255,))
    draw.rounded_rectangle(rect_px(CARD, scale=SS), radius=radius, fill=spec['card'] + (255,))

    bar_h, gap = BAR_H * EDGE, BAR_GAP * EDGE
    inner_left = (CARD[0] + CARD_PAD) * EDGE
    inner_w = (CARD[2] - 2 * CARD_PAD) * EDGE
    block = 4 * bar_h + 3 * gap
    top = CARD[1] * EDGE + (CARD[3] * EDGE - block) / 2      # 四条整体在卡片里垂直居中
    for i, (frac, colour) in enumerate(zip(BAR_WIDTHS, spec['bars'])):
        y0 = top + i * (bar_h + gap)
        draw.rounded_rectangle(
            [inner_left * SS, y0 * SS, (inner_left + inner_w * frac) * SS, (y0 + bar_h) * SS],
            radius=bar_h * SS / 2,                            # 圆头 = 半个条高，与主图一致
            fill=colour + (255,))
    # BOX 而不是 LANCZOS：整数倍降采时 BOX 就是精确的面积平均，正是超采样想要的结果。
    # LANCZOS 会在骨白卡片与红蓝错位层的高对比边上振铃，卡片内沿多出一圈约 +10/255
    # 的亮边，而且边缘像素不再等于 #F7F3EA，连验收时量几何都量不准。
    base = Image.alpha_composite(base, art.resize((EDGE, EDGE), Image.BOX))

    # 不透明变体必须在这里丢掉 alpha 通道：只要通道还在，哪怕整幅都是 255，
    # 上传校验一样按「图标带透明度」判定
    return base if spec['alpha'] else base.convert('RGB')


DEST.mkdir(parents=True, exist_ok=True)
for name, spec in VARIANTS.items():
    img = render(spec)
    img.save(DEST / name, format='PNG')
    alpha = img.getchannel('A').getextrema() if img.mode == 'RGBA' else None
    print(f"  {name:22s} {img.mode} {img.size[0]}×{img.size[1]}"
          f"{'' if alpha is None else f' alpha{alpha}'}")

# appearances 三条目。缺了它们 iOS 18+ 会自己从浅色稿派生深色与单色版本，
# 而这张图是深底径向渐变 + 双色错位，自动派生的结果一塌糊涂。
# 手写而不是 json.dumps：Xcode 写这个文件用的是 "key" : value 的间隔，
# 交给 json.dumps 排版的话，下次在 Xcode 里点一下资产目录就会整份重排成无关的 diff。
(DEST / 'Contents.json').write_text('''{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "AppIcon-Dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "AppIcon-Tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
''')
print("  Contents.json          3 个外观条目（浅色 / 深色 / 单色）")
PY
  echo "iOS AppIcon 已更新: CopyoIOS/Assets.xcassets/AppIcon.appiconset (重新构建后生效)"
  exit 0
fi

MASTER="${1:-art/icon-master.png}"
DEST="Copyo/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$MASTER" ]]; then
  echo "找不到主图标: $MASTER" >&2
  exit 1
fi

WIDTH=$(sips -g pixelWidth "$MASTER" | awk '/pixelWidth/{print $2}')
HEIGHT=$(sips -g pixelHeight "$MASTER" | awk '/pixelHeight/{print $2}')
if ! [[ "$WIDTH" =~ ^[0-9]+$ && "$HEIGHT" =~ ^[0-9]+$ ]]; then
  echo "无法读取图片尺寸，请确认 $MASTER 是有效的 PNG" >&2
  exit 1
fi
if [[ "$WIDTH" -ne "$HEIGHT" ]]; then
  echo "主图标必须是正方形（sips 会强制拉伸变形），当前 ${WIDTH}×${HEIGHT}" >&2
  exit 1
fi
if [[ "$WIDTH" -lt 1024 ]]; then
  echo "主图标需要至少 1024×1024，当前 ${WIDTH}×${HEIGHT}" >&2
  exit 1
fi

mkdir -p "$DEST"

# 尺寸:文件名（mac 图标 10 个规格）
for entry in \
  16:icon_16x16 32:icon_16x16@2x \
  32:icon_32x32 64:icon_32x32@2x \
  128:icon_128x128 256:icon_128x128@2x \
  256:icon_256x256 512:icon_256x256@2x \
  512:icon_512x512 1024:icon_512x512@2x; do
  size="${entry%%:*}"
  name="${entry##*:}"
  sips -s format png -z "$size" "$size" "$MASTER" --out "$DEST/$name.png" >/dev/null
done

cat > "$DEST/Contents.json" <<'EOF'
{
  "images" : [
    { "filename" : "icon_16x16.png",      "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png",   "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png",      "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png",   "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png",    "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png",    "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png",    "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

echo "AppIcon 已更新: ${DEST} (重新构建后生效)"
# 上面这轮 sips 会把 16pt 那一档也按比例缩出来，而那一档必糊：内容条只剩 0.67px、
# 错位只剩 0.39px，卡片糊成一块灰。spec「光栅化规则」要求 16pt 手工重绘，成品在
# art/icon/appiconset/icon_16x16.png，跑完本脚本要手动覆盖回去：
#   cp art/icon/appiconset/icon_16x16.png Copyo/Assets.xcassets/AppIcon.appiconset/
