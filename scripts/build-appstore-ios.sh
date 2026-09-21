#!/bin/bash
# 构建 iOS / iPadOS 上架包（Release-AppStore 配置），归档后导出可上传的 .ipa 到
# build/appstore-ios/
#
# 用法:
#   ./scripts/build-appstore-ios.sh            # 出包
#   UPLOAD=1 ./scripts/build-appstore-ios.sh   # 出包并直接上传 App Store Connect
#   NO_BUMP=1 ./scripts/build-appstore-ios.sh  # 不递增构建号（重试失败的那一次时用）
#
# 与 build-appstore.sh（macOS）分开而不是加一个平台参数：两边的产物形态、签名身份、
# 校验项都不一样——macOS 出 .pkg 且需要 Mac Installer Distribution 证书，iOS 出 .ipa
# 只需要 Apple Distribution。硬合成一个脚本，一半的分支会永远只在一个平台上跑到。
#
# 前置条件（一次性）:
#   1. Xcode → Settings → Accounts 登录，团队 9A94W79V84，且有 Apple Distribution 证书
#   2. 开发者后台三个 App ID 都开了 App Group group.dev.vibemage.Copyo；
#      主应用另开 iCloud 容器 iCloud.dev.vibemage.Copyo 与 Push
#      （2026-09-19 已完成）
#   3. App Store Connect 的应用记录里「添加平台 → iOS」
#      —— 这一条不做也能出包，但上传会被拒
#   描述文件由 -allowProvisioningUpdates 自动申请，不需要手动下载。
#
# 注意：键盘扩展（CopyoKeyboard）**刻意不在包里**，见 docs/ios-plan.md 3.6。
#   本脚本末尾会校验这一点——哪天把它挂回 Embed 阶段，校验会提醒你这是一次
#   审核面的扩大（4.4.1 + 完全访问），不要不小心带进去。
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID=9A94W79V84
BUNDLE_ID=dev.vibemage.Copyo
SCHEME="Copyo iOS"
ARCHIVE=build/ios-archive/Copyo.xcarchive
EXPORT_DIR=build/appstore-ios

# 构建号自动递增。**必须传 --ios**：bump-build-number.sh 按平台成组地改，
# iOS 这一组是主应用 + 两个扩展三个 target 一起动——Apple 不收「内嵌 .appex 的
# CFBundleVersion 与宿主不一致」的包，少动一个就是一次注定失败的上传。
if [[ "${NO_BUMP:-0}" != "1" ]]; then
  echo "==> 递增 iOS 上架构建号"
  ./scripts/bump-build-number.sh --ios | sed 's/^/    /'
  echo "    （这会改动 project.pbxproj，记得连同本次发布一起提交）"
fi

echo "==> 读取 Release-AppStore 构建设置"
if ! BUILD_SETTINGS=$(xcodebuild -project Copyo.xcodeproj -scheme "$SCHEME" \
     -configuration Release-AppStore -showBuildSettings 2>/dev/null); then
  echo "无法读取 Release-AppStore 构建设置" >&2
  exit 1
fi
build_setting() {
  printf '%s\n' "$BUILD_SETTINGS" | sed -n "s/^ *$1 = \(.*\)\$/\1/p" | head -1
}
VERSION=$(build_setting MARKETING_VERSION)
BUILD_NUMBER=$(build_setting CURRENT_PROJECT_VERSION)
if [[ -z "$VERSION" || -z "$BUILD_NUMBER" ]]; then
  echo "读不出 MARKETING_VERSION / CURRENT_PROJECT_VERSION" >&2
  exit 1
fi
echo "    版本 ${VERSION} (${BUILD_NUMBER})"

echo "==> 归档"
rm -rf "$ARCHIVE"
xcodebuild archive \
  -project Copyo.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release-AppStore \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  | grep -E "^\*\*|error:" || true
if [[ ! -d "$ARCHIVE" ]]; then
  echo "归档失败：没有产出 $ARCHIVE" >&2
  exit 1
fi

# 顺手把归档复制进 Organizer 会扫描的目录。`-archivePath` 指到 build/ 之下是为了让产物
# 跟着仓库走、好清理，但 Xcode 的 Organizer **只认** ~/Library/Developer/Xcode/Archives，
# 不复制的话「Distribute App」那条最顺手的上传路径根本看不到这次归档，
# 而人在 Organizer 里翻不到时，很容易改用 Product → Archive 重新归一次档——
# 那一次绑的是 Release 配置，出来的包上传必被拒（见本文件开头的注意事项）。
ORGANIZER_DIR="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)"
ORGANIZER_ARCHIVE="$ORGANIZER_DIR/Copyo iOS $(date +%Y-%m-%d\ %H.%M).xcarchive"
mkdir -p "$ORGANIZER_DIR"
rm -rf "$ORGANIZER_ARCHIVE"
cp -R "$ARCHIVE" "$ORGANIZER_ARCHIVE"
echo "    已复制到 Organizer：${ORGANIZER_ARCHIVE/#$HOME/~}"

# 归档阶段的签名是 Apple Development、aps-environment 是 development，**这是正常的**——
# -exportArchive 会重签成 Apple Distribution 并切到 production。要核验的是导出后的 .ipa，
# 不是归档。（macOS 那边同一个坑，见 docs/appstore-submission.md 第十八节。）
echo "==> 导出 .ipa"
rm -rf "$EXPORT_DIR"
PLIST=$(mktemp -t ios-export)
cat > "$PLIST" <<'EXPORTPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>9A94W79V84</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<key>destination</key>
	<string>export</string>
	<!-- 不让 Xcode 自作主张改版本号与构建号。缺省时它会把构建号抬成「ASC 上已有的最大值 + 1」，
	     于是出包的号和 project.pbxproj 里的号对不上，脚本印出来的号就是假的。
	     设成 false 之后，出的包就是仓库里记着的那个号，可复现、可追溯。 -->
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
EXPORTPLIST
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$PLIST" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  | grep -E "^\*\*|error:" || true
rm -f "$PLIST"

IPA=$(find "$EXPORT_DIR" -name "*.ipa" -maxdepth 1 | head -1)
if [[ -z "$IPA" ]]; then
  echo "导出失败：$EXPORT_DIR 下没有 .ipa" >&2
  exit 1
fi

echo "==> 核验产物"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
unzip -q "$IPA" -d "$WORK"
APP="$WORK/Payload/Copyo.app"
[[ -d "$APP" ]] || { echo "包里没有 Payload/Copyo.app" >&2; exit 1; }

fail() { echo "核验不通过：$1" >&2; exit 1; }
plist_get() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Info.plist" 2>/dev/null || true; }

# 版本号：包里的必须与配置一致，否则上面印的号是假的
PKG_VERSION=$(plist_get "$APP" CFBundleShortVersionString)
PKG_BUILD=$(plist_get "$APP" CFBundleVersion)
[[ "$PKG_VERSION" == "$VERSION" ]]   || fail "包里版本 $PKG_VERSION ≠ 配置 $VERSION"
[[ "$PKG_BUILD"   == "$BUILD_NUMBER" ]] || fail "包里构建号 $PKG_BUILD ≠ 配置 $BUILD_NUMBER（导出选项没生效？）"

# 扩展的构建号必须与宿主一致，Apple 会因此拒收
for ex in "$APP"/PlugIns/*.appex; do
  [[ -e "$ex" ]] || continue
  EX_BUILD=$(plist_get "$ex" CFBundleVersion)
  [[ "$EX_BUILD" == "$BUILD_NUMBER" ]] \
    || fail "$(basename "$ex") 构建号 $EX_BUILD ≠ 宿主 $BUILD_NUMBER"
done

# 下面一律「先把输出收进变量，再用 bash 自己的匹配判断」，**不要写 `… | grep -q …`**。
# `set -o pipefail` 下那是个陷阱：`grep -q` 一命中就退出并关闭管道，上游收到 SIGPIPE
# 非零退出，pipefail 于是把整条管道判成失败——校验恒假。反过来同样的写法也能造出
# 恒真的校验，那比恒假危险得多（放行一个签错的包）。第一版就栽在这上面。
SIGN_INFO=$(codesign -dvvv "$APP" 2>&1 || true)
[[ "$SIGN_INFO" == *"Authority=Apple Distribution"* ]] \
  || fail "主应用不是 Apple Distribution 签名（归档那份是 Development，说明重签没生效）"

ENTS=$(codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -convert xml1 -o - - || true)
# get-task-allow 必须为 false，否则上传被拒
GTA=$(printf '%s' "$ENTS" | grep -A1 "get-task-allow" || true)
[[ "$GTA" == *"<false/>"* ]] || fail "get-task-allow 不是 false"
[[ "$ENTS" == *"group.dev.vibemage.Copyo"* ]]  || fail "缺 App Group entitlement"
[[ "$ENTS" == *"iCloud.dev.vibemage.Copyo"* ]] || fail "缺 iCloud 容器 entitlement"
APS=$(printf '%s' "$ENTS" | grep -A1 "aps-environment" || true)
[[ "$APS" == *"production"* ]] || fail "aps-environment 不是 production"

# 出口合规：缺这个键，每次上传后都要在网页上手工回答一遍
[[ "$(plist_get "$APP" ITSAppUsesNonExemptEncryption)" == "false" ]] \
  || fail "Info.plist 缺 ITSAppUsesNonExemptEncryption=false"

# 图标：actool 处理过的图标名会写进 Info.plist，缺了就是灰底白图上架
[[ -n "$(plist_get "$APP" CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName)" ]] \
  || fail "Info.plist 里没有 CFBundleIconName"

# 键盘不该在包里（见 docs/ios-plan.md 3.6）
if [[ -d "$APP/PlugIns/CopyoKeyboard.appex" ]]; then
  echo "⚠️  包里带上了 CopyoKeyboard.appex。" >&2
  echo "   这会把 iOS 版拖进审核指南 4.4.1 的审视范围，并需要为它注册 App ID。" >&2
  echo "   若是有意为之，把 docs/ios-plan.md 3.6 一并更新；否则检查 project.pbxproj。" >&2
  exit 1
fi

# `|| true`：PlugIns 目录不存在时整条管道会非零退出，而 `set -e` 会就地终止——
# 那等于因为「没有扩展」这件本身合法的事，把一次成功的核验判成失败
EXTS=$(find "$APP/PlugIns" -maxdepth 1 -name "*.appex" 2>/dev/null | xargs -n1 basename 2>/dev/null | sort | tr '\n' ' ' || true)
echo "    版本        ${PKG_VERSION} (${PKG_BUILD})"
echo "    签名        Apple Distribution"
echo "    内嵌扩展    ${EXTS:-（无）}"
echo "    entitlements App Group / iCloud / aps-environment=production ✓"

echo ""
ls -lh "$IPA"
echo ""

if [[ "${UPLOAD:-0}" == "1" ]]; then
  echo "==> 上传 App Store Connect"
  # 上传需要凭据：Xcode 里登录过的账号不会被 altool 自动取用。
  # 用 App Store Connect API 密钥（推荐，不会因为改密码失效）：
  #   export ASC_KEY_ID=... ASC_ISSUER_ID=...
  #   密钥放在 ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
  if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
    echo "缺 ASC_KEY_ID / ASC_ISSUER_ID，无法上传。" >&2
    echo "也可以改用 Xcode → Organizer，或 Transporter 拖入：$IPA" >&2
    exit 1
  fi
  xcrun altool --upload-app -f "$IPA" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
else
  echo "上传方式（任选其一）："
  echo "  1. UPLOAD=1 重跑本脚本（需要 ASC_KEY_ID / ASC_ISSUER_ID）"
  echo "  2. Xcode → Window → Organizer，选刚产出的这次归档 → Distribute App"
  echo "  3. App Store 装 Transporter，把上面这个 .ipa 拖进去"
  echo ""
  echo "上传前确认：App Store Connect 的应用记录已「添加平台 → iOS」，"
  echo "且构建号 ${BUILD_NUMBER} 大于该平台上一次上传过的号。"
fi
