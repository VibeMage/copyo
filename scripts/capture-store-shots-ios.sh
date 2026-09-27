#!/bin/bash
# 采集 iOS / iPadOS 商店截图的原始界面，供 make-store-shots-ios.py 合成。
#
# 用法:
#   ./scripts/capture-store-shots-ios.sh <输出目录> [Copyo.app 路径]
#
# 全部用 -demoData 的样例库拍（设计稿第六节的数据），不碰真实剪贴板与真实库。
# 每种语言拍之前把**模拟器的系统语言**也切过去并重启：-AppleLanguages 只管应用自己，
# iPad 状态栏上的日期（「9月27日周日」）跟的是系统语言，不切的话英文截图顶上是中文日期。
#
# 采集清单与 make-store-shots-ios.py 的 SHOTS 表一一对应，改一边要同步改另一边。
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=${1:?用法：$0 <输出目录> [Copyo.app]}
APP=${2:-build/Build/Products/Debug-iphonesimulator/Copyo.app}
PHONE="iPhone 17 Pro Max"      # 6.9 英寸，1320×2868
PAD="iPad Pro 13-inch (M5)"    # 13 英寸，2064×2752
BUNDLE=dev.vibemage.Copyo

[[ -d "$APP" ]] || { echo "找不到 $APP，先构建 Copyo iOS（Debug，模拟器）" >&2; exit 1; }
mkdir -p "$OUT"

udid() { xcrun simctl list devices available | sed -n "s/^ *$1 (\([0-9A-F-]*\)).*/\1/p" | head -1; }

wait_booted() {
  for _ in $(seq 1 90); do
    xcrun simctl list devices | grep "$1" | grep -q Booted && { sleep 8; return; }
    sleep 2
  done
  echo "模拟器 $1 启动超时" >&2; exit 1
}

prepare() { # udid lang(zh|en)
  local dev=$1 lang=$2 apple locale
  if [[ $lang == zh ]]; then apple=zh-Hans; locale=zh_CN; else apple=en; locale=en_US; fi
  xcrun simctl shutdown "$dev" 2>/dev/null || true
  xcrun simctl boot "$dev" 2>/dev/null || true
  wait_booted "$dev"
  xcrun simctl spawn "$dev" defaults write -g AppleLanguages -array "$apple"
  xcrun simctl spawn "$dev" defaults write -g AppleLocale -string "$locale"
  # 键盘第一次弹出时系统会盖一层「滑行输入」介绍（搜索那张图会拍到它），先标成看过
  xcrun simctl spawn "$dev" defaults write com.apple.Preferences DidShowContinuousPathIntroduction -bool true
  xcrun simctl spawn "$dev" defaults write com.apple.keyboard.ContinuousPath CPTutorialShown -bool true 2>/dev/null || true
  # 语言要重启一次 SpringBoard 才落到状态栏
  xcrun simctl shutdown "$dev"; xcrun simctl boot "$dev"; wait_booted "$dev"
  xcrun simctl status_bar "$dev" override --time 9:41 --batteryState discharging \
    --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi
  xcrun simctl install "$dev" "$APP"
}

shot() { # udid 输出名 启动参数...
  local dev=$1 name=$2; shift 2
  xcrun simctl launch --terminate-running-process "$dev" "$BUNDLE" \
    -demoData -skipOnboarding -demoTheme light "$@" >/dev/null
  sleep 4
  xcrun simctl io "$dev" screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "    $name"
}

P=$(udid "$PHONE"); D=$(udid "$PAD")
[[ -n $P && -n $D ]] || { echo "找不到 $PHONE 或 $PAD 模拟器" >&2; exit 1; }

for lang in zh en; do
  apple=$([[ $lang == zh ]] && echo zh-Hans || echo en)
  echo "==> $PHONE / $lang"
  prepare "$P" $lang
  for route in history history-search detail-text share settings-quicksave pinboard-content; do
    shot "$P" "phone-$lang-$route" -demoScreen $route -AppleLanguages "($apple)"
  done
  echo "==> $PAD / $lang"
  prepare "$D" $lang
  shot "$D" "pad-$lang-sidebar-history" -demoSidebar history -AppleLanguages "($apple)"
  shot "$D" "pad-$lang-sidebar-pinboard" -demoSidebar pinboard -AppleLanguages "($apple)"
  shot "$D" "pad-$lang-sidebar-color" -demoSidebar color -AppleLanguages "($apple)"
  shot "$D" "pad-$lang-share" -demoScreen share -AppleLanguages "($apple)"
done
echo "完成：$OUT"
