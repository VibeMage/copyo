#!/bin/bash
# 构建 Release 版本并打包为 DMG + ZIP，输出到 dist/
#
# 用法:
#   ./scripts/build-release.sh                        # 本地签名（Sign to Run Locally）
#   SIGN_IDENTITY="Developer ID Application: 你的名字 (TEAMID)" ./scripts/build-release.sh
#
# 如有 Apple Developer 账号，签名后可继续公证（使用者安装零障碍）:
#   xcrun notarytool submit dist/Paster-<版本>.zip --keychain-profile <配置名> --wait
#   xcrun stapler staple <Paster.app 路径>   # 然后重新打 DMG
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/.*MARKETING_VERSION = "\{0,1\}\([0-9][0-9.A-Za-z-]*\)"\{0,1\};.*/\1/p' Paster.xcodeproj/project.pbxproj | head -1)
if [[ -z "$VERSION" ]]; then
  echo "无法从 project.pbxproj 解析 MARKETING_VERSION" >&2
  exit 1
fi
APP=build/Build/Products/Release/Paster.app

echo "==> 构建 Paster $VERSION (Release)"
# 先删掉旧产物，确保打包的一定是本次构建的结果
rm -rf "$APP"
BUILD_LOG=$(mktemp)
if ! xcodebuild -project Paster.xcodeproj -scheme Paster -configuration Release \
     -derivedDataPath build build > "$BUILD_LOG" 2>&1; then
  grep -E "error:" "$BUILD_LOG" >&2 || tail -20 "$BUILD_LOG" >&2
  rm -f "$BUILD_LOG"
  echo "构建失败" >&2
  exit 1
fi
grep -E "warning:|BUILD SUCCEEDED" "$BUILD_LOG" | grep -v appintentsmetadata || true
rm -f "$BUILD_LOG"

if [[ ! -d "$APP" ]]; then
  echo "构建失败：找不到 $APP" >&2
  exit 1
fi

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "==> 使用 Developer ID 重新签名"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --strict "$APP"
fi

rm -rf dist
mkdir -p dist

echo "==> 生成 DMG"
STAGING=$(mktemp -d)
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Paster" -srcfolder "$STAGING" -ov -quiet \
  -format UDZO "dist/Paster-$VERSION.dmg"
rm -rf "$STAGING"

echo "==> 生成 ZIP"
ditto -c -k --keepParent "$APP" "dist/Paster-$VERSION.zip"

echo ""
ls -lh dist/
echo ""
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "完成。已用 Developer ID 签名；建议继续公证（见脚本顶部注释），"
  echo "未公证时首次打开需在 系统设置 → 隐私与安全性 底部点「仍要打开」。"
else
  echo "完成。注意：ad-hoc 签名的包在其他机器上双击会提示「已损坏，无法打开」，"
  echo "这是 Gatekeeper 对无开发者身份应用的固定提示，不是包真的坏了。"
  echo "安装后需在终端执行一次："
  echo "  xattr -cr /Applications/Paster.app"
  echo "之后即可正常打开。"
fi
