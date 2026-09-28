#!/usr/bin/env python3
"""生成 Mac 商店素材的浅色舞台背景。

    python3 scripts/make-store-plate.py                       # art/store/_background-plate.png（2560 × 1600）
    python3 scripts/make-store-plate.py --stage <输出.png>     # 另出拍摄用的 16:9 舞台（3840 × 2160）

拍摄时把 16:9 舞台铺成全屏窗口（1920 × 1080pt 的 2x，逐像素显示），面板与预览窗的玻璃按它真实合成；
make-store-shots.py 合成设置窗口那张时也贴在它上面。16:9 舞台就是 16:10 画布上下各去掉 5% 的那一段，
直接按目标分辨率渲染，不从 2560 的图放大，免得放大后再量化一次。

底色与 iOS 商店图同一奶白（make-store-shots-ios.py 的 BACKGROUND）。左红右蓝，每侧两团品牌色光：
一团大而柔的上光，中心在舞台顶边附近、所有取景之上；一团贴边的侧光，中心落在视频宽取景的左右边上。
两团叠成一道从画外照进来的边光：截图与视频紧取景里是左上 / 右上的角光，宽取景里是两侧的光墙，
标题、副标题、玻璃面板和宣传页横幅的边缘都不着色。左右故意不完全镜像（蓝侧略高、略大、峰值约 1.1 倍，
蓝色在奶白上显得淡）。上光不能拿掉：侧光的上半段衰减太陡，单独使用时 4K 舞台上会出现 2 级色阶。
参数由 build.noindex/store-light/sim/ 的模拟器、设计评审与验收脚本（retune/measure_all.py）挑定，
改动后要重跑它复核这些约束。

衰减用平顶的 peak × (1 − d²)²：中心与边缘斜率都为 0，没有 (1 − d)² 那种中心尖峰。
按浮点混色，最后用 4 × 4 Bayer 有序抖动量化到 8 位，压住色带；只用 PIL、无随机数，逐字节可复现。
"""

import argparse
from pathlib import Path

from PIL import Image, ImageMath

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "art" / "store" / "_background-plate.png"
W, H = 2560, 1600
STAGE_SIZE = (3840, 2160)
# 16:9 舞台在 16:10 画布上的纵向范围（上下各裁 5%）
STAGE_WINDOW = (0.0, 0.05, 1.0, 0.95)
BASE = (244, 242, 237)
RED, BLUE = (255, 45, 85), (10, 132, 255)
# (颜色, 中心 x, 中心 y, 横半径, 纵半径, 峰值不透明度)，坐标与半径按 16:10 画布的比例
GLOWS = [
    (RED, 0.125, 0.101, 0.274, 0.541, 0.263),   # 上光
    (BLUE, 0.894, 0.079, 0.296, 0.572, 0.297),
    (RED, 0.100, 0.394, 0.297, 0.194, 0.194),   # 侧光
    (BLUE, 0.903, 0.392, 0.305, 0.212, 0.216),
]
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def glow_mask(size, window, cx, cy, rx, ry, peak):
    """浮点不透明度图。先在 1/8 网格上逐点求值，再双三次放大并夹回 [0, peak]。"""
    w, h = max(2, size[0] // 8), max(2, size[1] // 8)
    x0, y0, x1, y1 = window
    values = []
    for j in range(h):
        y = y0 + (y1 - y0) * (j + 0.5) / h
        for i in range(w):
            x = x0 + (x1 - x0) * (i + 0.5) / w
            d2 = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            values.append(peak * (1 - d2) ** 2 if d2 < 1 else 0.0)
    mask = Image.new("F", (w, h))
    mask.putdata(values)
    mask = mask.resize(size, Image.BICUBIC)
    return ImageMath.unsafe_eval("min(max(m, 0.0), p)", m=mask, p=float(peak))


def bayer(size):
    """4 × 4 有序抖动的阈值图，取值 (k + 0.5) / 16；加上后截断取整即为抖动 + 四舍五入。"""
    strip = Image.new("F", (size[0], 4))
    strip.putdata([(BAYER[r][c % 4] + 0.5) / 16 for r in range(4) for c in range(size[0])])
    tile = Image.new("F", size)
    for top in range(0, size[1], 4):
        tile.paste(strip, (0, top))
    return tile


def render(base=BASE, glows=GLOWS, size=(W, H), window=(0.0, 0.0, 1.0, 1.0)):
    channels = [Image.new("F", size, float(value)) for value in base]
    for color, *geometry in glows:
        alpha = glow_mask(size, window, *geometry)
        channels = [ImageMath.unsafe_eval("ch * (1 - a) + a * c", ch=ch, a=alpha, c=float(value))
                    for ch, value in zip(channels, color)]
    threshold = bayer(size)
    return Image.merge("RGB", [ImageMath.unsafe_eval("convert(ch + t, 'L')", ch=ch, t=threshold)
                               for ch in channels])


def main():
    parser = argparse.ArgumentParser(description="生成商店素材的浅色舞台背景")
    parser.add_argument("--stage", type=Path, help="另存拍摄用的 3840 × 2160 舞台")
    args = parser.parse_args()
    render().save(OUT, optimize=True)
    print(OUT)
    if args.stage:
        render(size=STAGE_SIZE, window=STAGE_WINDOW).save(args.stage, optimize=True)
        print(args.stage)


if __name__ == "__main__":
    main()
