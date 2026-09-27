#!/bin/bash
# 录一段给 App 审核看的 iOS 演示视频（审核附件），全程在模拟器里自动完成。
#
# 用法:
#   ./scripts/record-review-video.sh [输出.mp4]
#
# 做的事：
#   1. 准备一台专用模拟器「Copyo Review」（iPhone 17 Pro），每次先抹掉，系统语言切英文，状态栏固定 9:41
#   2. 本机起 HTTP 服务，把 scripts/review-video/ 这页给模拟器里的 Safari 打开
#   3. 构建 CopyoIOSUITests，跑 ReviewWalkthrough（步骤见那个文件的注释），录像取 Xcode 测试自带的录屏
#   4. 用 ffmpeg 剪掉开头测试宿主启动的那一秒，压成 30 帧 H.264 mp4
#
# 录的是模拟器，没有 iCloud 账号，右上角同步胶囊会是「未同步」。审核备注里要说明这一点。
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=${1:-build/review/copyo-ios-review.mp4}
DEVICE_NAME="Copyo Review"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
PORT=${PORT:-8779}
DERIVED=build/review/DerivedData
RESULT=build/review/walkthrough.xcresult
ATTACH=build/review/attachments
LOG=build/review/test.log
mkdir -p build/review "$(dirname "$OUT")"

udid=$(xcrun simctl list devices available | sed -n "s/^ *$DEVICE_NAME (\([0-9A-F-]*\)).*/\1/p" | head -1)
if [[ -z $udid ]]; then
  runtime=$(xcrun simctl list runtimes available | sed -n 's/^iOS .* - \(com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]*\)$/\1/p' | tail -1)
  udid=$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$runtime")
fi
echo "==> 模拟器 $DEVICE_NAME ($udid)"

wait_booted() {
  for _ in $(seq 1 90); do
    xcrun simctl list devices | grep "$udid" | grep -q Booted && { sleep 8; return; }
    sleep 2
  done
  echo "模拟器启动超时" >&2; exit 1
}

if [[ -n ${KEEP_SIM:-} ]]; then
  # 调脚本时省掉抹机和两次开机：只把 Copyo 删掉重装，引导照样从头走
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl uninstall "$udid" dev.vibemage.Copyo 2>/dev/null || true
else
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  xcrun simctl erase "$udid"
  xcrun simctl boot "$udid"; wait_booted
  xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array en
  xcrun simctl spawn "$udid" defaults write -g AppleLocale -string en_US
  xcrun simctl spawn "$udid" defaults write com.apple.Preferences DidShowContinuousPathIntroduction -bool true
  xcrun simctl spawn "$udid" defaults write com.apple.keyboard.ContinuousPath CPTutorialShown -bool true 2>/dev/null || true
  # 语言要重启一次才落到 SpringBoard 和 Safari
  xcrun simctl shutdown "$udid"; xcrun simctl boot "$udid"; wait_booted
  # 新机开机后半分钟左右系统会弹「Apple Intelligence 已就绪」之类的通知横幅，等它弹完再开录
  sleep 30
fi
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState discharging \
  --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi

echo "==> 构建"
xcodebuild build-for-testing -project Copyo.xcodeproj -scheme CopyoIOSUITests \
  -destination "id=$udid" -derivedDataPath "$DERIVED" -quiet
# xcodebuild 要等测试里调用 launch() 才装目标 App；演示是从主屏幕点图标开始的，得先装好
xcrun simctl install "$udid" "$DERIVED/Build/Products/Debug-iphonesimulator/Copyo.app"

python3 -m http.server "$PORT" --bind 127.0.0.1 --directory scripts/review-video >/dev/null 2>&1 &
server=$!
sleep 1
# 端口被别的服务占着时 Safari 会打开那个服务的页面，演示在第一步就找不到按钮
curl -fs "http://127.0.0.1:$PORT/" | grep -q "Weekend in Lisbon" \
  || { echo "演示网页没起来（端口 $PORT 被占？换一个：PORT=xxxx $0）" >&2; exit 1; }
trap 'kill "$server" 2>/dev/null || true' EXIT

# 录像用 Xcode 测试自带的录屏（满分辨率 H.264，从测试开跑那一刻录起），scheme 里设了成功也保留。
# 不再另开 `simctl io recordVideo`：两路录屏同时抓一台模拟器时，它的 io 会整个卡死，截图都截不了
# Safari 第一次开网页要七八秒，先在录像外开一次预热，再关掉
xcrun simctl openurl "$udid" "http://127.0.0.1:$PORT/" 2>/dev/null || true   # 新开机时偶尔超时，不影响后面
sleep 10
xcrun simctl terminate "$udid" com.apple.mobilesafari 2>/dev/null || true

echo "==> 跑演示（Xcode 录屏）"
rm -rf "$RESULT"
status=0
TEST_RUNNER_REVIEW_PAGE_URL="http://127.0.0.1:$PORT/" \
  xcodebuild test-without-building -project Copyo.xcodeproj -scheme CopyoIOSUITests \
  -destination "id=$udid" -derivedDataPath "$DERIVED" -resultBundlePath "$RESULT" \
  -only-testing:CopyoIOSUITests/ReviewWalkthrough/testReviewWalkthrough >"$LOG" 2>&1 || status=$?

rm -rf "$ATTACH"; mkdir -p "$ATTACH"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$ATTACH" >/dev/null 2>&1 || true
raw=$(command ls -S "$ATTACH"/*.mp4 2>/dev/null | head -1 || true)
if [[ $status -ne 0 ]]; then
  echo "演示没走完（xcodebuild 退出码 ${status}），日志：${LOG}；录像：${raw:-无}" >&2
  grep -aE "not found|error:|missing" "$LOG" | head -20 >&2 || true
  exit 1
fi
[[ -n $raw ]] || { echo "结果包里没有录屏：${RESULT}" >&2; exit 1; }

# 开头是测试宿主刚起来、还没按 Home 的那一秒，剪掉。Xcode 的录屏是可变帧率，转成恒定 30 帧
skip=${TRIM_START:-1}
echo "==> 剪掉开头 ${skip}s，压缩"
ffmpeg -y -loglevel error -ss "$skip" -i "$raw" -vf "scale=-2:1920,fps=30" -c:v libx264 -preset slow -crf 22 \
  -pix_fmt yuv420p -movflags +faststart -an "$OUT"
echo "完成：${OUT}（$(du -h "$OUT" | cut -f1)，$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT" | cut -d. -f1) 秒）"
