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
#        Apple Distribution         —— 给 Copyo.app 签名
#        Mac Installer Distribution —— 给导出的 .pkg 签名
#   3. App Store Connect 里建好 bundle id 为 dev.vibemage.Copyo 的 App 记录
#   4. 开发者后台 → Identifiers → dev.vibemage.Copyo 勾选 iCloud (CloudKit)
#      与 Push Notifications，容器选 iCloud.dev.vibemage.Copyo
#      （sandbox 版的 entitlements 里带这两项，App ID 上没开就申请不到描述文件）
#   5. 在 Xcode 里打开本工程 → target Copyo → Signing & Capabilities，
#      勾上 Automatically manage signing 并选团队 9A94W79V84，
#      让 Xcode 把本机注册进账号：归档用的 Apple Development 身份需要一张
#      Mac App Development 描述文件，而这类描述文件要求账号里至少有一台
#      已注册的 Mac，xcodebuild 自己不会注册设备
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
BUNDLE_ID=dev.vibemage.Copyo
ARCHIVE=build/Copyo.xcarchive

# 版本号必须取自真正被归档的那份配置。project.pbxproj 里三个 target 配置各有一行
# MARKETING_VERSION / CURRENT_PROJECT_VERSION，按文件顺序 sed 到的第一行是 Debug 的值；
# 只把 Release-AppStore 的构建号 +1（正确做法）时，脚本就会印出并校验一个陈旧的号。
# 构建号自动递增。以前要手动去 project.pbxproj 里 +1，忘了就会上传失败
# （App Store Connect 不接受重复的构建号）。NO_BUMP=1 可跳过——重试一次失败的
# 构建时用，构建号只要递增即可，跳号无害。
# 显式传 --macos：bump-build-number.sh 现在按平台成组地改，iOS 那三个 target
# 与本脚本无关（本脚本只归档 macOS）。不写平台虽然也是 macOS，但那是默认值，
# 哪天默认值变了，这里就会悄悄去动 iOS 的构建号。
if [[ "${NO_BUMP:-0}" != "1" ]]; then
  echo "==> 递增 macOS 上架构建号"
  ./scripts/bump-build-number.sh --macos | sed 's/^/    CURRENT_PROJECT_VERSION /'
  echo "    （这会改动 project.pbxproj，记得连同本次发布一起提交）"
fi

echo "==> 读取 Release-AppStore 构建设置"
if ! BUILD_SETTINGS=$(xcodebuild -project Copyo.xcodeproj -scheme Copyo \
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
PKG="${PKG_DIR}/Copyo-${VERSION}-appstore.pkg"

# 证书缺失是这个脚本最常见的失败原因，日志里那一大段 provisioning 报错很难读，
# 命中关键字时直接给出该去 Xcode 做什么。
print_signing_help() {
  cat >&2 <<HELP

看起来是签名证书或描述文件缺失。请在 Xcode 里补齐后重试：
  1. Xcode → Settings → Accounts，登录后选中团队 ${TEAM_ID}
  2. Manage Certificates… → 左下角 + 号，创建这两张证书：
       Apple Distribution         （给 Copyo.app 签名）
       Mac Installer Distribution （给导出的 .pkg 签名）
  3. 确认 App Store Connect 里已存在 bundle id 为 ${BUNDLE_ID} 的 App 记录，
     否则自动申请描述文件会失败
  4. 开发者后台 → Identifiers → ${BUNDLE_ID}，勾选 iCloud（CloudKit）与
     Push Notifications，并创建 / 勾选容器 iCloud.${BUNDLE_ID}；
     entitlements 里有这两项而 App ID 没开，描述文件同样申请不下来。
     报「doesn't support the iCloud and Push Notifications capability」
     就是卡在这一步
  5. 若报「no devices from which to generate a provisioning profile」：
     归档用的是 Apple Development 身份，要一张 Mac App Development
     描述文件，而这类描述文件必须账号里至少注册过一台 Mac。用 Xcode 打开
     Copyo.xcodeproj → target Copyo → Signing & Capabilities，勾上
     Automatically manage signing 并选团队 ${TEAM_ID}，Xcode 会把本机注册
     进账号；也可以在开发者后台 Devices 里手工添加本机的 Provisioning UDID
     （系统信息 → 硬件 → 预置 UDID）。xcodebuild 自己不会注册设备
HELP
}

matches_signing_error() {
  grep -qE "No signing certificate|no valid signing identity|doesn't include signing certificate|No profiles for|requires a provisioning profile|No account for team|No Accounts|valid signing identity|Distribution certificate|no devices from which|doesn't support the|conflicting provisioning settings" "$1"
}

echo "==> 归档 Copyo ${VERSION} (build ${BUILD_NUMBER}, Release-AppStore)"
rm -rf "$ARCHIVE"
ARCHIVE_LOG=$(mktemp)
if ! xcodebuild -project Copyo.xcodeproj -scheme Copyo -configuration Release-AppStore \
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
	<!-- 不让 Xcode 自作主张改版本号与构建号。这个键缺省时 Xcode 会把构建号抬成
	     「App Store Connect 上已有的最大值 + 1」，于是出包的号和 project.pbxproj
	     里的号对不上，脚本打印的构建号就是假的（1.0 那次：配置里是 4，实际出包是 5）。
	     设成 false 之后，出的包就是仓库里记着的那个号，可复现、可追溯。 -->
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
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

# 核对包里的真实构建号。manageAppVersionAndBuildNumber=false 之后两者应当一致；
# 不一致说明导出选项没生效，此时打印出来的构建号会误导后续的上传判断。
VERIFY_DIR=$(mktemp -d)
if pkgutil --expand-full "$PKG" "$VERIFY_DIR/pkg" >/dev/null 2>&1; then
  PKG_APP=$(find "$VERIFY_DIR/pkg" -maxdepth 6 -name "Copyo.app" -type d | head -1)
  if [[ -n "$PKG_APP" ]]; then
    PKG_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PKG_APP/Contents/Info.plist" 2>/dev/null || true)
    PKG_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PKG_APP/Contents/Info.plist" 2>/dev/null || true)
    if [[ -n "$PKG_BUILD" && "$PKG_BUILD" != "$BUILD_NUMBER" ]]; then
      echo "包里的构建号（${PKG_BUILD}）与配置（${BUILD_NUMBER}）不一致——" >&2
      echo "多半是导出选项里的 manageAppVersionAndBuildNumber 没生效，Xcode 又自己改了号。" >&2
      rm -rf "$VERIFY_DIR"
      exit 1
    fi
    echo "==> 包内版本核对通过：${PKG_VERSION} (${PKG_BUILD})"
  fi
fi
rm -rf "$VERIFY_DIR"

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
for _p in build/Copyo.xcarchive/Products/Applications/Copyo.app build/Build/Products/Release-AppStore/Copyo.app; do
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
echo "（构建号由本脚本自动递增，无需手动改 project.pbxproj；"
echo " 只想看或指定构建号用 ./scripts/bump-build-number.sh --macos --show / --macos <数字>，"
echo " 重试失败的构建时加 NO_BUMP=1 跳过递增）。"
echo ""
echo "注意：这里的构建号只属于 macOS 平台。iOS 在同一条 App Store Connect 记录下"
echo "单独记构建号，由 ./scripts/bump-build-number.sh --ios 递增（会把 Copyo iOS 与"
echo "两个扩展一起改——嵌入的 .appex 与宿主 App 的构建号不一致，整个提交会被退回）。"
