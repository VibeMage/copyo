#!/bin/bash
# 把 1024×1024 的 PNG 主图标生成为 Xcode 资产目录所需的全部尺寸
# 用法: ./scripts/make-icon.sh [master.png]   (默认 art/icon-master.png)
set -euo pipefail
cd "$(dirname "$0")/.."

MASTER="${1:-art/icon-master.png}"
DEST="Paster/Assets.xcassets/AppIcon.appiconset"

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
