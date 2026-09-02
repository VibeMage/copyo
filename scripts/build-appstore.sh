#!/bin/bash
# 构建 Mac App Store 版本（Release-AppStore 配置：沙盒 + 书签式同步目录），
# 归档后导出可上传的 .pkg 到 build/appstore/
# （刻意避开 dist/：build-release.sh 会 rm -rf dist，把上架包一并删掉）
#
# 用法:
#   ./scripts/build-appstore.sh
#
# 前置条件（一次性，在 Xcode 里完成）:
#   1. Xcode → Settings → Accounts 登录有 App Store 权限的 Apple ID
#   2. 该团队下创建两张证书:
#        Apple Distribution         —— 给 Paster.app 签名
#        Mac Installer Distribution —— 给导出的 .pkg 签名
#   3. App Store Connect 里建好 bundle id 为 dev.vibemage.Paster 的 App 记录
# 描述文件由 -allowProvisioningUpdates 自动申请，无需手动下载。
#
# 注意：不要用 Xcode 的 Product → Archive 归档上架包。
#   scheme 的 ArchiveAction 绑定的是 Release 配置——不带沙盒、没有 APPSTORE 编译条件、
#   用 ad-hoc 身份签名（因而带 get-task-allow）。那样归档出来的包上传必被拒，
#   而且在 Organizer 里和本脚本的归档长得一模一样，肉眼分辨不出来。
#   只有本脚本会用 -configuration Release-AppStore 覆盖配置。
#   若走 Organizer → Distribute App，务必挑本脚本刚产出的那次归档。
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID=9A94W79V84
BUNDLE_ID=dev.vibemage.Paster
ARCHIVE=build/Paster.xcarchive

# 版本号必须取自真正被归档的那份配置。project.pbxproj 里三个 target 配置各有一行
# MARKETING_VERSION / CURRENT_PROJECT_VERSION，按文件顺序 sed 到的第一行是 Debug 的值；
# 只把 Release-AppStore 的构建号 +1（正确做法）时，脚本就会印出并校验一个陈旧的号。
echo "==> 读取 Release-AppStore 构建设置"
if ! BUILD_SETTINGS=$(xcodebuild -project Paster.xcodeproj -scheme Paster \
     -configuration Release-AppStore -showBuildSettings 2>/dev/null); then
  echo "无法读取 Release-AppStore 构建设置" >&2
  exit 1
fi
build_setting() {
  printf '%s\n' "$BUILD_SETTINGS" | sed -n "s/^ *$1 = \(.*\)\$/\1/p" | head -1
}
VERSION=$(build_setting MARKETING_VERSION)
if [[ -z "$VERSION" ]]; then
  echo "Release-AppStore 配置里读不到 MARKETING_VERSION" >&2
  exit 1
fi
BUILD_NUMBER=$(build_setting CURRENT_PROJECT_VERSION)
if [[ -z "$BUILD_NUMBER" ]]; then
  echo "Release-AppStore 配置里读不到 CURRENT_PROJECT_VERSION" >&2
  exit 1
fi
# 刻意不放进 dist/：build-release.sh 每次跑都会 rm -rf dist，
# 先出上架包再出直分发包的话，.pkg 会被无声删掉。build/ 已在 .gitignore 里。
PKG_DIR=build/appstore
PKG="${PKG_DIR}/Paster-${VERSION}-appstore.pkg"

# 证书缺失是这个脚本最常见的失败原因，日志里那一大段 provisioning 报错很难读，
# 命中关键字时直接给出该去 Xcode 做什么。
print_signing_help() {
  cat >&2 <<HELP

看起来是签名证书或描述文件缺失。请在 Xcode 里补齐后重试：
  1. Xcode → Settings → Accounts，登录后选中团队 ${TEAM_ID}
  2. Manage Certificates… → 左下角 + 号，创建这两张证书：
       Apple Distribution         （给 Paster.app 签名）
       Mac Installer Distribution （给导出的 .pkg 签名）
  3. 确认 App Store Connect 里已存在 bundle id 为 ${BUNDLE_ID} 的 App 记录，
     否则自动申请描述文件会失败
HELP
}

matches_signing_error() {
  grep -qE "No signing certificate|no valid signing identity|doesn't include signing certificate|No profiles for|requires a provisioning profile|No account for team|No Accounts|valid signing identity|Distribution certificate" "$1"
}

echo "==> 归档 Paster ${VERSION} (build ${BUILD_NUMBER}, Release-AppStore)"
rm -rf "$ARCHIVE"
ARCHIVE_LOG=$(mktemp)
if ! xcodebuild -project Paster.xcodeproj -scheme Paster -configuration Release-AppStore \
     -archivePath "$ARCHIVE" \
     -allowProvisioningUpdates \
     CODE_SIGN_STYLE=Automatic \
     DEVELOPMENT_TEAM="$TEAM_ID" \
     CODE_SIGN_IDENTITY="Apple Development" \
     archive > "$ARCHIVE_LOG" 2>&1; then
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
  echo "归档失败：找不到 ${ARCHIVE}" >&2
  exit 1
fi

EXPORT_DIR=$(mktemp -d)
EXPORT_PLIST="$EXPORT_DIR/exportOptions.plist"

# method 名在 Xcode 15 改过：新名 app-store-connect，旧名 app-store。
# 先按新名导出，被拒再退回旧名，脚本在两代 Xcode 上都能跑。
write_export_plist() {
  cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>$1</string>
	<key>destination</key>
	<string>export</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST
}

# 回退只应发生在「Xcode 不认识这个 method 名」时。判定要求同一行里既出现
# method，又出现「不支持 / 无效」的措辞——早先只扫 "not a valid" 之类子串，
# 会被 "... is not a valid provisioning profile" 这种普通签名错误命中：
# 于是打印一句错误的诊断、把整个导出白跑第二遍，最后报的还是第二次的错。
method_not_recognized() {
  grep -iE "method" "$1" | grep -qiE "unsupported|unrecognized|not supported|invalid|not a valid|expected one of"
}

run_export() {
  write_export_plist "$1"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR/out" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -allowProvisioningUpdates > "$EXPORT_LOG" 2>&1
}

echo "==> 导出 App Store 安装包"
mkdir -p "$PKG_DIR"
rm -f "$PKG"
EXPORT_LOG=$(mktemp)
EXPORT_OK=0
if run_export app-store-connect; then
  EXPORT_OK=1
elif method_not_recognized "$EXPORT_LOG"; then
  echo "==> 当前 Xcode 不认识 app-store-connect，改用旧方法名 app-store"
  rm -rf "$EXPORT_DIR/out"
  if run_export app-store; then
    EXPORT_OK=1
  fi
fi

if [[ "$EXPORT_OK" -ne 1 ]]; then
  echo "导出失败" >&2
  grep -E "error:|Error Domain" "$EXPORT_LOG" >&2 || tail -20 "$EXPORT_LOG" >&2
  if matches_signing_error "$EXPORT_LOG"; then
    print_signing_help
  fi
  echo "" >&2
  echo "完整日志：${EXPORT_LOG}" >&2
  exit 1
fi
rm -f "$EXPORT_LOG"

EXPORTED=$(find "$EXPORT_DIR/out" -maxdepth 1 -name "*.pkg" | head -1)
if [[ -z "$EXPORTED" ]]; then
  echo "导出成功但没找到 .pkg，请检查 ${EXPORT_DIR}/out" >&2
  exit 1
fi
mv "$EXPORTED" "$PKG"
rm -rf "$EXPORT_DIR"

echo ""
ls -lh "$PKG"
echo ""
echo "完成。归档：${ARCHIVE}"
# UPLOAD=1 时直接上传到 App Store Connect（复用 Xcode 登录的账号，无需 Transporter）
if [[ "${UPLOAD:-0}" == "1" ]]; then
  echo "==> 上传到 App Store Connect"
  UPLOAD_OPTS=$(mktemp).plist
  cat > "$UPLOAD_OPTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>upload</string>
    <key>teamID</key><string>9A94W79V84</string>
    <key>signingStyle</key><string>automatic</string>
    <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST
  if xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$UPLOAD_OPTS" \
       -exportPath build/appstore-upload -allowProvisioningUpdates 2>&1 | grep -E "Uploaded|error:|EXPORT"; then
    echo "上传完成：几分钟后在 App Store Connect 的「构建版本」中可选"
  else
    echo "上传失败，可改用 Transporter 手动拖入 ${PKG}" >&2
  fi
  rm -f "$UPLOAD_OPTS"
fi

# 归档产物不进启动台/Spotlight
for _p in build/Paster.xcarchive/Products/Applications/Paster.app build/Build/Products/Release-AppStore/Paster.app; do
  [ -d "$_p" ] && /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -u "$_p" 2>/dev/null || true
done
echo "安装包：${PKG}"
echo ""
echo "下一步，上传到 App Store Connect："
echo "  • 推荐：Transporter.app → 拖入上面的 .pkg → Deliver"
echo "  • 或 Xcode → Window → Organizer → Distribute App，但务必选中刚才这次归档"
echo "    （Organizer 里 Product → Archive 产出的 Release 归档长得一模一样，"
echo "     那份没有沙盒权限，上传必被拒——认准时间戳）"
echo ""
echo "上传前确认：App Store Connect 已有 ${BUNDLE_ID} 的 App 记录，"
echo "且构建号 ${BUILD_NUMBER} 大于上一次上传过的构建号"
echo "（下次上传前，只需把 project.pbxproj 里 Release-AppStore 配置"
echo " AB0000000000000000000011 的 CURRENT_PROJECT_VERSION +1，"
echo " Debug / Release 两个配置不要动——那是直分发版的构建号）。"
