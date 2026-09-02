#!/bin/bash
# 构建直分发版（Release 配置：Developer ID 签名）并打包为 DMG + ZIP，输出到 dist/
#
# 流程是 xcodebuild archive + -exportArchive，签名、entitlements 展开和
# Developer ID 描述文件的嵌入全部交给 Xcode 做。
# 早先的做法是先 CODE_SIGNING_ALLOWED=NO 构建、再手工 codesign --force 重签，
# 那样既要自己拼 entitlements 文件，也没法把描述文件放进包里；
# 而 iCloud/推送属于受限 entitlements，没有描述文件授权就带着它们签名，
# 应用在用户机器上会被系统直接终止。
#
# 用法:
#   ./scripts/build-release.sh
#     - 自动签名，描述文件由 -allowProvisioningUpdates 自动申请
#   NOTARY_PROFILE=paster-notary ./scripts/build-release.sh
#     - 导出后提交 Apple 公证并 staple。需先做一次性配置:
#       xcrun notarytool store-credentials paster-notary \
#         --apple-id <AppleID邮箱> --team-id <TEAMID> --password <App专用密码>
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/build-release.sh
#     - 可选覆盖：钥匙串里有多张 Developer ID 证书时指定用哪一张，
#       不设则由 Xcode 自动挑选
#
# 前置条件（一次性，在 Xcode 里完成）:
#   1. Xcode → Settings → Accounts 登录 Apple ID 并选中团队 9A94W79V84
#   2. Manage Certificates… → + 号创建 Developer ID Application 证书
#   3. 开发者后台 → Identifiers → dev.vibemage.Paster 勾选 iCloud (CloudKit)
#      与 Push Notifications，容器选 iCloud.dev.vibemage.Paster；
#      App ID 上没开这两项，带 iCloud entitlements 的描述文件申请不下来
#   4. 在 Xcode 里打开本工程 → target Paster → Signing & Capabilities，
#      勾上 Automatically manage signing 并选团队 9A94W79V84。
#      归档这一步是用 Apple Development 身份签的，需要一张 Mac App
#      Development 描述文件，而这类描述文件要求账号里至少注册过一台 Mac；
#      Xcode 打开工程时会顺手把本机注册进去，xcodebuild 自己不会
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID=9A94W79V84
BUNDLE_ID=dev.vibemage.Paster
# 上架脚本用的是 build/Paster.xcarchive，这里另起一个名字，两个脚本互不覆盖
ARCHIVE=build/Paster-Release.xcarchive

VERSION=$(sed -n 's/.*MARKETING_VERSION = "\{0,1\}\([0-9][0-9.A-Za-z-]*\)"\{0,1\};.*/\1/p' Paster.xcodeproj/project.pbxproj | head -1)
if [[ -z "$VERSION" ]]; then
  echo "无法从 project.pbxproj 解析 MARKETING_VERSION" >&2
  exit 1
fi

# 证书或描述文件缺失是这个脚本最常见的失败原因，日志里那一大段 provisioning
# 报错很难读，命中关键字时直接给出该去 Xcode 做什么。
print_signing_help() {
  cat >&2 <<HELP

看起来是签名证书或描述文件缺失。请补齐后重试：
  1. Xcode → Settings → Accounts，登录后选中团队 ${TEAM_ID}
  2. Manage Certificates… → 左下角 + 号，创建 Developer ID Application 证书
  3. 开发者后台 → Identifiers → ${BUNDLE_ID}，勾选 iCloud（CloudKit）与
     Push Notifications，并创建 / 勾选容器 iCloud.${BUNDLE_ID}；
     entitlements 里有这两项而 App ID 没开，描述文件申请不下来
  4. 若报「no devices from which to generate a provisioning profile」：
     自动签名归档要一张 Mac App Development 描述文件，而这类描述文件
     必须至少有一台已注册的 Mac。用 Xcode 打开 Paster.xcodeproj →
     target Paster → Signing & Capabilities，勾上 Automatically manage
     signing 并选团队 ${TEAM_ID}，Xcode 会把本机注册进账号并生成描述文件；
     也可以在开发者后台 Devices 里手工添加本机的 Provisioning UDID
     （系统信息 → 硬件 → 预置 UDID）
HELP
}

matches_signing_error() {
  grep -qE "No signing certificate|no valid signing identity|doesn't include signing certificate|No profiles for|requires a provisioning profile|No account for team|No Accounts|valid signing identity|no devices from which|doesn't support the|conflicting provisioning settings" "$1"
}

echo "==> 归档 Paster $VERSION (Release)"
rm -rf "$ARCHIVE"
ARCHIVE_LOG=$(mktemp)
ARCHIVE_ARGS=(
  -project Paster.xcodeproj
  -scheme Paster
  -configuration Release
  -archivePath "$ARCHIVE"
  -derivedDataPath build
  -allowProvisioningUpdates
  CODE_SIGN_STYLE=Automatic
  DEVELOPMENT_TEAM="$TEAM_ID"
  # 自动签名归档时只认 Apple Development 身份（写别的会被判成
  # 「自动签名却手工指定了冲突的身份」而直接失败）。
  # 换成 Developer ID 是下面 -exportArchive 的事，那一步会整包重签。
  CODE_SIGN_IDENTITY="Apple Development"
)
# scheme 的 ArchiveAction 绑定的是 Release-AppStore，上面的 -configuration Release 会覆盖它
if ! xcodebuild "${ARCHIVE_ARGS[@]}" archive > "$ARCHIVE_LOG" 2>&1; then
  echo "归档失败" >&2
  grep -E "error:" "$ARCHIVE_LOG" >&2 || tail -20 "$ARCHIVE_LOG" >&2
  if matches_signing_error "$ARCHIVE_LOG"; then
    print_signing_help
  fi
  echo "" >&2
  echo "完整日志：${ARCHIVE_LOG}" >&2
  exit 1
fi
grep -E "warning:|ARCHIVE SUCCEEDED" "$ARCHIVE_LOG" | grep -v appintentsmetadata || true
rm -f "$ARCHIVE_LOG"

if [[ ! -d "$ARCHIVE" ]]; then
  echo "归档失败：找不到 $ARCHIVE" >&2
  exit 1
fi

echo "==> 导出 Developer ID 应用"
EXPORT_DIR=$(mktemp -d)
EXPORT_PLIST="$EXPORT_DIR/exportOptions.plist"
# destination=export 只导出本地文件；换成 upload 会走 Apple 的公证服务上传
{
  cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>destination</key>
	<string>export</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>automatic</string>
PLIST
  # 多张 Developer ID 证书时才需要指名道姓，默认让 Xcode 自己挑
  if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    printf '\t<key>signingCertificate</key>\n\t<string>%s</string>\n' "$SIGN_IDENTITY"
  fi
  cat <<'PLIST'
</dict>
</plist>
PLIST
} > "$EXPORT_PLIST"

EXPORT_LOG=$(mktemp)
if ! xcodebuild -exportArchive \
     -archivePath "$ARCHIVE" \
     -exportPath "$EXPORT_DIR/out" \
     -exportOptionsPlist "$EXPORT_PLIST" \
     -allowProvisioningUpdates > "$EXPORT_LOG" 2>&1; then
  echo "导出失败" >&2
  grep -E "error:|Error Domain" "$EXPORT_LOG" >&2 || tail -20 "$EXPORT_LOG" >&2
  if matches_signing_error "$EXPORT_LOG"; then
    print_signing_help
  fi
  echo "" >&2
  echo "完整日志：${EXPORT_LOG}" >&2
  exit 1
fi
grep -E "warning:" "$EXPORT_LOG" | grep -v appintentsmetadata || true
rm -f "$EXPORT_LOG"

APP="$EXPORT_DIR/out/Paster.app"
if [[ ! -d "$APP" ]]; then
  echo "导出成功但没找到 Paster.app，请检查 ${EXPORT_DIR}/out" >&2
  exit 1
fi
codesign --verify --strict "$APP"

# 公证：设置 NOTARY_PROFILE（notarytool 钥匙串配置名）时执行
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
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

rm -rf "$EXPORT_DIR"

# 构建产物不进启动台/Spotlight（xcodebuild 每次都会自动注册）
for _p in "$ARCHIVE/Products/Applications/Paster.app" build/Build/Products/Release/Paster.app; do
  [ -d "$_p" ] && /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -u "$_p" 2>/dev/null || true
done

echo ""
ls -lh dist/
echo ""
echo "归档：${ARCHIVE}"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "完成。已签名并通过 Apple 公证：双击即装，仅首次有一次「从互联网下载」的标准确认。"
else
  echo "完成。已用 Developer ID 自动签名；建议加 NOTARY_PROFILE=<配置名> 继续公证。"
  echo "未公证时首次打开需在 系统设置 → 隐私与安全性 底部点「仍要打开」，"
  echo "spctl 也会报 rejected —— 这是没公证的正常表现，不是签名坏了。"
fi
