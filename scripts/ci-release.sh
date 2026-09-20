#!/bin/bash
# CI 专用：在 GitHub Actions 的 macOS runner 上归档、以 Developer ID 手动签名导出、
# 提交 Apple 公证并打包成 DMG + ZIP，产物落在 dist/。由 .github/workflows/release.yml 调用。
#
# 为什么不复用 scripts/build-release.sh：
#   那个脚本走自动签名 + -allowProvisioningUpdates，依赖 Xcode 里登录过的 Apple ID 会话；
#   更致命的是它归档时用 "Apple Development" 身份，那需要一张按设备列表签发的
#   Mac App Development 描述文件，账号里必须至少注册过一台 Mac —— 一次性 runner
#   这两个条件都永远不满足。Developer ID 描述文件按 App ID 签发、不含设备列表，正好绕开。
#   两条路在归档身份、描述文件来源、公证凭据、日志策略上每一步都不同，硬合并买不到多少复用，
#   却会把维护者唯一验证过的本地发版路径变脆 —— 改坏了不会在 CI 上红，会在下次发版时红。
#   代价是两份脚本要一起维护：产物命名与 DMG 布局刻意与 build-release.sh 逐字一致，改一边要改另一边。
#
# 用法（workflow 之外，本机也能用同一组环境变量复现）:
#   VERSION=1.0.1 \
#   CI_SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
#   CI_PROVISIONING_PROFILE=<描述文件 UUID> \
#   CI_KEYCHAIN=/path/to/build.keychain-db \
#     ./scripts/ci-release.sh
#   再设齐 NOTARY_KEY_PATH / NOTARY_KEY_ID / NOTARY_ISSUER_ID 则提交公证并 staple；
#   三个里缺任何一个都跳过公证（用于先单独验证签名链路）。
#
# 注意：macOS 自带的是 bash 3.2.57，没有 mapfile / ${var,,}；
#   `set -u` 下 "${ARR[@]}" 展开空数组会直接 unbound variable 退出，
#   所以可选参数数组一律写成 ${ARR[@]+"${ARR[@]}"}。
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID=9A94W79V84
BUNDLE_ID=dev.vibemage.Copyo
# 本地脚本用 build/Copyo-Release.xcarchive，上架脚本用 build/Copyo.xcarchive，
# 这里再起一个名字，三者互不覆盖。
ARCHIVE=build/Copyo-CI.xcarchive
LOG_DIR=${LOG_DIR:-build/logs}

require() {
  local name=$1
  # 用间接展开而不是 eval：CI_SIGN_IDENTITY 这类值必然带空格和括号，
  # eval 会把它当命令行重新分词。
  if [[ -z "${!name:-}" ]]; then
    echo "缺少环境变量 ${name}，见本脚本头部的用法说明" >&2
    exit 1
  fi
}
require VERSION
require CI_SIGN_IDENTITY
require CI_PROVISIONING_PROFILE
require CI_KEYCHAIN

# 跑一条命令，输出同时进日志文件，返回这条命令自己的退出码（而不是管道末端 tee 的）。
# 这正是 Actions 默认 shell 最容易踩的坑：xcodebuild 挂了、tee 成功，作业却是绿的。
run_logged() {
  local log=$1
  shift
  local status
  set +e
  "$@" 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  set -e
  return "$status"
}

mkdir -p "$LOG_DIR"

# 所有临时产物都挂在同一个目录下，用 trap 统一收尾。
# 原先散落的几个 mktemp -d 在脚本任何一次提前退出时都会留在磁盘上 ——
# 一次性 runner 上无所谓，但这个脚本也支持在本机复现，那里就是实打实的垃圾。
WORK_TMP=$(mktemp -d)
cleanup() { rm -rf "$WORK_TMP"; }
trap cleanup EXIT

echo "==> 归档 Copyo $VERSION (Release, 手动签名)"
rm -rf "$ARCHIVE"
# -configuration Release 不可省：scheme 的 ArchiveAction 绑的是 Release-AppStore，
# 那套用 CopyoAppStore.entitlements（带 app-sandbox）且 CODE_SIGN_IDENTITY="-"（ad-hoc），
# 省掉这个参数会「全绿地」产出一个根本不能直分发的包。
#
# 命令行直接传 PROVISIONING_PROFILE_SPECIFIER 在这条路径上是安全的：macOS 的 Copyo target
# 只有 Sources / Frameworks / Resources 三个构建阶段、依赖为空，工程里唯一的
# Embed Foundation Extensions 属于 iOS app，两个 appex 也都是 SDKROOT=iphoneos ——
# macOS 包里不含任何扩展，不存在「一条命令要喂多份描述文件」的问题。
#
# 签名身份要连 sdk 限定的那份一起覆盖：工程里同时写了 CODE_SIGN_IDENTITY 和
# CODE_SIGN_IDENTITY[sdk=macosx*]，两个都是 "Apple Development"。只覆盖无条件的那个，
# 万一限定版仍然生效，归档就会去找一张 runner 上根本没有的 Apple Development 证书。
#
# 绝不要清空 CODE_SIGN_ENTITLEMENTS：entitlements 里的 aps-environment 写的是
# $(APS_ENVIRONMENT)，靠 build setting 代入；丢了它会展开成空串，
# 轻则 codesign 失败，重则签出一个和描述文件对不上、在用户机器上被系统直接终止的包。
if ! run_logged "$LOG_DIR/archive.log" \
  xcodebuild archive \
    -project Copyo.xcodeproj \
    -scheme Copyo \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    -derivedDataPath build \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$CI_SIGN_IDENTITY" \
    "CODE_SIGN_IDENTITY[sdk=macosx*]=$CI_SIGN_IDENTITY" \
    PROVISIONING_PROFILE_SPECIFIER="$CI_PROVISIONING_PROFILE" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    OTHER_CODE_SIGN_FLAGS="--keychain $CI_KEYCHAIN"; then
  echo "归档失败" >&2
  grep -E "error:" "$LOG_DIR/archive.log" >&2 || tail -30 "$LOG_DIR/archive.log" >&2
  exit 1
fi
# xcodebuild 在「跳过了 target」之类的情况下照样返回 0
if [[ ! -d "$ARCHIVE/Products/Applications/Copyo.app" ]]; then
  echo "归档返回 0 但没产出 $ARCHIVE/Products/Applications/Copyo.app" >&2
  exit 1
fi

echo "==> 导出 Developer ID 应用"
EXPORT_DIR="$WORK_TMP/export"
mkdir -p "$EXPORT_DIR"
EXPORT_PLIST="$EXPORT_DIR/exportOptions.plist"
# method 的合法值是小写连字符标识符：直分发是 developer-id。
# Organizer 界面上那个带空格的「Developer ID」是按钮文案，写进 plist 会直接报错。
# provisioningProfiles 只需要一条 —— 理由同上，macOS 包里没有 appex。
cat > "$EXPORT_PLIST" <<PLIST
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
	<string>manual</string>
	<key>signingCertificate</key>
	<string>${CI_SIGN_IDENTITY}</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>${BUNDLE_ID}</key>
		<string>${CI_PROVISIONING_PROFILE}</string>
	</dict>
</dict>
</plist>
PLIST
plutil -lint "$EXPORT_PLIST"

# 手动签名不需要 -allowProvisioningUpdates（那是去 Apple 现申请描述文件用的，
# 在无人值守 runner 上既没有账号会话也申请不下来）。
if ! run_logged "$LOG_DIR/export.log" \
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR/out" \
    -exportOptionsPlist "$EXPORT_PLIST"; then
  echo "导出失败" >&2
  grep -E "error:|Error Domain" "$LOG_DIR/export.log" >&2 || tail -30 "$LOG_DIR/export.log" >&2
  exit 1
fi

APP="$EXPORT_DIR/out/Copyo.app"
if [[ ! -d "$APP" ]]; then
  echo "导出返回 0 但没找到 Copyo.app，请检查 $EXPORT_DIR/out" >&2
  exit 1
fi

echo "==> 产物自检"
codesign --verify --strict --verbose=2 "$APP" 2>&1 | tee "$LOG_DIR/verify.log"
# 把实际签名标志（要含 runtime，即强化运行时）和实际 entitlements 打进日志，
# 出问题时这是唯一能事后核对「签进去的到底是哪一份」的证据。
codesign -dv --verbose=4 "$APP" 2>&1 | tee -a "$LOG_DIR/verify.log"
codesign -d --entitlements :- "$APP" 2>&1 | tee "$LOG_DIR/entitlements.log"
# 下面三条断言防的是同一类事故：配置选错了，但每一步都返回 0，一路全绿地发出去。
# 强化运行时是公证的硬前提，签名标志里必须能看到 runtime。
if ! grep -q 'flags=.*runtime' "$LOG_DIR/verify.log"; then
  echo "签名里没有强化运行时（hardened runtime），公证一定会被拒" >&2
  exit 1
fi
# 直分发版用的是 Copyo.entitlements（不带沙盒）。如果这里出现了 app-sandbox，
# 说明归档跑的是 Release-AppStore 配置 —— 那是上架包，装到用户机器上行为完全不同。
if grep -q 'com.apple.security.app-sandbox' "$LOG_DIR/entitlements.log"; then
  echo "产物带了 app-sandbox，说明归档用错了配置（应为 Release 而非 Release-AppStore）" >&2
  exit 1
fi
# 反过来，iCloud 容器必须在，否则同步功能会在用户机器上静默失效
if ! grep -q 'iCloud.dev.vibemage.Copyo' "$LOG_DIR/entitlements.log"; then
  echo "产物的 entitlements 里没有 iCloud 容器，同步会失效" >&2
  exit 1
fi
# 受限 entitlements（iCloud / aps-environment）必须靠包里这份描述文件授权，
# 缺了它应用在用户机器上会被系统直接终止，而 CI 这边一路全绿。
if [[ ! -f "$APP/Contents/embedded.provisionprofile" ]]; then
  echo "包里没有 embedded.provisionprofile，受限 entitlements 不会被授权" >&2
  exit 1
fi
# Release 没设 ONLY_ACTIVE_ARCH，默认产出通用二进制。runner 是 arm64，
# 一旦有人为了提速给发布路径加上 ONLY_ACTIVE_ARCH=YES 或 ARCHS=arm64，
# Intel 用户会拿到跑不起来的包，而且不报任何错 —— 所以这里硬断言两个架构都在。
APP_ARCHS=$(lipo -archs "$APP/Contents/MacOS/Copyo")
echo "架构：$APP_ARCHS"
case "$APP_ARCHS" in *arm64*) ;; *) echo "产物缺 arm64：$APP_ARCHS" >&2; exit 1 ;; esac
case "$APP_ARCHS" in *x86_64*) ;; *) echo "产物缺 x86_64：$APP_ARCHS" >&2; exit 1 ;; esac

if [[ -n "${NOTARY_KEY_PATH:-}" && -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER_ID:-}" ]]; then
  echo "==> 提交 Apple 公证（通常 1-5 分钟）"
  NOTARY_ARGS=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
  NOTARY_TMP="$WORK_TMP/notary"
  mkdir -p "$NOTARY_TMP"
  ditto -c -k --keepParent "$APP" "$NOTARY_TMP/Copyo.zip"

  # 从 notarytool 的 JSON 里取一个顶层字段。刻意不引入 python/jq 依赖：
  # 原始 JSON 已经完整写进日志，这里只需要把值抠出来。
  json_field() {
    sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
  }

  # 不要写成 `X=$(... | tee ...)`：set -e + pipefail 下 notarytool 一失败，
  # 整个命令替换就失败并当场退出脚本，下面那几行错误处理永远执行不到。
  SUBMIT_JSON=$(xcrun notarytool submit "$NOTARY_TMP/Copyo.zip" \
    "${NOTARY_ARGS[@]}" --output-format json 2>&1) || SUBMIT_JSON=""
  printf '%s\n' "$SUBMIT_JSON" > "$LOG_DIR/notary-submit.json"
  SUBMISSION_ID=$(printf '%s' "$SUBMIT_JSON" | json_field id)
  if [[ -z "$SUBMISSION_ID" ]]; then
    echo "提交公证失败，没能解析出提交 ID。notarytool 的输出：" >&2
    cat "$LOG_DIR/notary-submit.json" >&2
    exit 1
  fi
  echo "提交 ID：$SUBMISSION_ID"

  # 刻意不用 `notarytool submit --wait`：它的退出码两个方向都骗人 ——
  # 最终状态 Invalid 时它仍然退出 0，而轮询途中一次网络超时又会在实际 Accepted 时让它非 0。
  # 只有自己轮询 info 并认准 status 才靠谱，外面再套一个总时限兜底
  # （Apple 的公证服务会瞬时 5xx，也会偶尔排长队，不能无限等）。
  DEADLINE=$(( $(date +%s) + 1800 ))
  NOTARY_STATUS=""
  while :; do
    if [[ $(date +%s) -ge $DEADLINE ]]; then
      echo "公证等待超过 30 分钟仍未出结果，提交 ID $SUBMISSION_ID" >&2
      exit 1
    fi
    sleep 30
    if ! INFO_JSON=$(xcrun notarytool info "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" --output-format json 2>&1); then
      echo "::warning::查询公证状态失败，当作瞬时错误继续重试"
      continue
    fi
    NOTARY_STATUS=$(printf '%s' "$INFO_JSON" | json_field status)
    echo "公证状态：${NOTARY_STATUS:-未知}"
    case "$NOTARY_STATUS" in
      Accepted) break ;;
      Invalid|Rejected)
        # 真正的原因永远在 log 的 issues[] 里，submit/info 只会告诉你「不行」
        echo "公证被拒（状态 $NOTARY_STATUS），详情：" >&2
        if xcrun notarytool log "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" "$LOG_DIR/notary-log.json"; then
          cat "$LOG_DIR/notary-log.json" >&2
        else
          # 日志偶尔要等几十秒才生成得出来。取不到就别让唯一的诊断信息也一起没了，
          # 至少把 info 的原始返回留下，以及怎么自己补查。
          echo "（取不到 notarytool log，下面是 info 的原始返回）" >&2
          printf '%s\n' "$INFO_JSON" >&2
          echo "稍后可手工补查：xcrun notarytool log $SUBMISSION_ID --key ... --key-id ... --issuer ..." >&2
        fi
        exit 1
        ;;
      *) ;;
    esac
  done

  echo "==> Staple 公证票据"
  # 公证刚判 Accepted 时票据未必已经全网可取，头一两次 staple 偶发失败。
  # 这时重试的代价是几十秒，不重试的代价是刚等完的那 30 分钟公证全白费。
  staple_ok=0
  for attempt in 1 2 3; do
    if xcrun stapler staple "$APP"; then
      staple_ok=1
      break
    fi
    echo "stapler 第 $attempt 次失败，30 秒后重试" >&2
    [[ "$attempt" -lt 3 ]] && sleep 30
  done
  if [[ "$staple_ok" -ne 1 ]]; then
    echo "stapler 连续三次失败，提交 ID $SUBMISSION_ID 已公证但票据没贴上" >&2
    exit 1
  fi
  xcrun stapler validate "$APP"
else
  echo "==> 跳过公证（NOTARY_KEY_PATH / NOTARY_KEY_ID / NOTARY_ISSUER_ID 未设齐）"
  echo "    产物只签了名没公证，用户首次打开需要在 系统设置 → 隐私与安全性 里点「仍要打开」。"
fi

rm -rf dist
mkdir -p dist

echo "==> 生成 DMG"
# 顺序和本地脚本一致：先 staple 好 .app 再做 DMG，Gatekeeper 查的是映像里的那个 .app。
STAGING="$WORK_TMP/staging"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
# 不加 -quiet：runner 上 hdiutil 偶发 "Resource busy"，-quiet 会把原因一起藏掉。
dmg_ok=0
for attempt in 1 2 3; do
  if hdiutil create -volname "Copyo" -srcfolder "$STAGING" -ov \
       -format UDZO "dist/Copyo-$VERSION.dmg"; then
    dmg_ok=1
    break
  fi
  echo "::warning::hdiutil 第 $attempt 次失败"
  [[ "$attempt" -lt 3 ]] && sleep 10
done
if [[ "$dmg_ok" -ne 1 ]]; then
  echo "hdiutil 连续三次失败" >&2
  exit 1
fi

echo "==> 生成 ZIP"
ditto -c -k --keepParent "$APP" "dist/Copyo-$VERSION.zip"

echo "==> 生成校验和"
( cd dist && shasum -a 256 "Copyo-$VERSION.dmg" "Copyo-$VERSION.zip" > SHA256SUMS.txt )

echo ""
ls -lh dist/
echo ""
cat dist/SHA256SUMS.txt
