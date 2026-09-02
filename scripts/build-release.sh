#!/bin/bash
# 构建 Release 版本并打包为 DMG + ZIP，输出到 dist/
#
# 用法:
#   ./scripts/build-release.sh
#     - 钥匙串里有 Developer ID Application 证书时自动用它签名，否则退回本地 ad-hoc 签名
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/build-release.sh
#     - 显式指定签名身份
#   NOTARY_PROFILE=paster-notary ./scripts/build-release.sh
#     - 签名后提交 Apple 公证并 staple。需先做一次性配置:
#       xcrun notarytool store-credentials paster-notary \
#         --apple-id <AppleID邮箱> --team-id <TEAMID> --password <App专用密码>
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

# 签名身份：优先 SIGN_IDENTITY 环境变量，否则自动探测钥匙串中的 Developer ID 证书
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)
  if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "==> 自动检测到签名身份: $SIGN_IDENTITY"
  fi
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "==> 使用 Developer ID 签名"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --strict "$APP"
fi

# 公证：设置 NOTARY_PROFILE（notarytool 钥匙串配置名）时执行
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "公证需要 Developer ID 签名，但未找到签名身份" >&2
    exit 1
  fi
  echo "==> 提交 Apple 公证（通常 1-5 分钟）"
  NOTARY_TMP=$(mktemp -d)
  ditto -c -k --keepParent "$APP" "$NOTARY_TMP/Paster.zip"
  xcrun notarytool submit "$NOTARY_TMP/Paster.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  rm -rf "$NOTARY_TMP"
  echo "==> Staple 公证票据"
  xcrun stapler staple "$APP"
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

# 构建产物不进启动台/Spotlight（xcodebuild 每次都会自动注册）
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -u "$APP" 2>/dev/null || true

echo ""
ls -lh dist/
echo ""
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "完成。已签名并通过 Apple 公证：双击即装，仅首次有一次「从互联网下载」的标准确认。"
elif [[ -n "$SIGN_IDENTITY" ]]; then
  echo "完成。已用 Developer ID 签名；建议加 NOTARY_PROFILE=<配置名> 继续公证。"
  echo "未公证时首次打开需在 系统设置 → 隐私与安全性 底部点「仍要打开」。"
else
  echo "完成。注意：ad-hoc 签名的包在其他机器上双击会提示「已损坏，无法打开」，"
  echo "这是 Gatekeeper 对无开发者身份应用的固定提示，不是包真的坏了。"
  echo "安装后需在终端执行一次："
  echo "  xattr -cr /Applications/Paster.app"
  echo "之后即可正常打开。"
fi
