#!/bin/bash
# 把当前代码编成直分发版（Release 配置，Apple Development 签名），替换 /Applications/Copyo.app 并重启。
# 用途：本机日常用的那份 Copyo 就是最新 build。
#
# 用法:
#   ./scripts/install-local.sh           编译 → 替换 /Applications/Copyo.app → 重启
#   ./scripts/install-local.sh --help    打印用法
#
# 几个刻意的选择:
# - 用直分发配置（非沙盒）：它读 ~/Library/Application Support/Copyo，正是日常那份历史；
#   商店配置是沙盒，读的是 ~/Library/Containers/dev.vibemage.Copyo，那是另一份。
#   商店包要验证时走 TestFlight，本机不常驻。
# - 只手动运行，不挂 git 钩子：本仓库 core.hooksPath 指向入库的 .beads/hooks（beads 的钩子，公开文件），
#   没有链式调用本地钩子的地方，本机的自动安装不该写进公开仓库。也不在每次编译后自动装：
#   调试中的半成品会顶掉你日常在用的那份。
# - 不覆盖商店版：/Applications/Copyo.app 带 _MASReceipt 时直接停下，要先手动删掉；
#   目标位置不可写时也停下说明。这两项在编译前、退出 App 前各查一次，查不过什么都不动。
# - 只退出 /Applications/Copyo.app 这一份（按可执行文件路径认进程），用 AppleScript 按路径礼貌退出，
#   5 秒不走再 kill 那个 pid。别的 Copyo（Debug 构建、worktree 构建、-demoData 拍摄实例、
#   模拟器里的 iOS 版）一律不碰，只在最后提示哪些 Mac 实例还在跑：它们会和新装的抢 ⇧⌘V。
# - 本机只留一份：同一个 bundle ID 散落多份时，LaunchServices 与 Spotlight 会把它们全部登记，
#   「打开方式」和 Spotlight 里就是一排 Copyo（2026-09-27 清过一次十几份）。所以构建目录放在
#   build.noindex/ 下（Spotlight 跳过 .noindex 目录），装完把构建产物和旧版备份从 LaunchServices 注销。
# - 替换前把旧版挪进 build.noindex/install/previous/Copyo.app，装坏了可以手动挪回来；只保留一份备份。
#   新版没挪进去时自动把旧版挪回原位并重新打开；半成品 Copyo.installing.app 失败时清掉。
# - 同一时间只跑一个：build.noindex/install/.lock 是互斥锁（mkdir 原子创建），退出时删掉。
#
# 签名：Release 配置是 Apple Development 自动签名，描述文件由 -allowProvisioningUpdates 申请，
# iCloud / 推送这两项受限 entitlements 因此有效，iCloud 同步可用。没有登录 Xcode 账号时这一步会失败，
# 前置条件与 build-release.sh 头部相同。
set -euo pipefail

usage() {
  cat <<'USAGE'
用法: ./scripts/install-local.sh [--help]
  不带参数：编译直分发 Release → 替换 /Applications/Copyo.app → 重启
  -h, --help：打印本说明
USAGE
}

case "$#:${1:-}" in
  0:) ;;
  1:-h|1:--help) usage; exit 0 ;;
  *) echo "不认识的参数：$*" >&2; usage >&2; exit 2 ;;
esac

cd "$(dirname "$0")/.."

BUNDLE_ID=dev.vibemage.Copyo
DEST=/Applications/Copyo.app
DEST_EXE=$DEST/Contents/MacOS/Copyo
STAGING="${DEST%.app}.installing.app"
WORK=build.noindex/install
DERIVED=$WORK/dd
BUILT=$DERIVED/Build/Products/Release/Copyo.app
PREVIOUS=$WORK/previous/Copyo.app
LOG=$WORK/build.log
LOCK=$WORK/.lock
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

# ---------- 收尾（失败时回滚）----------

have_lock=0   # 锁是本次拿到的；没拿到锁的进程退出时什么都不收拾，免得删掉正在跑的那个的东西
quit_sent=0   # 已经让 /Applications 那份退出了；失败时要把原位上那份重新打开
moved_old=0   # 旧版已挪进（或正在挪进）$PREVIOUS
backed_up=0   # 这一次确实备份了旧版（previous/ 里可能是更早某次留下的）
installed=0   # 新版已就位

cleanup() {
  local status=$?
  trap - EXIT
  # 收尾里某一步失败也要把后面的做完，不能让 set -e 把回滚截断
  set +e
  if ((have_lock && !installed)); then
    if [[ -e "$STAGING" ]]; then
      rm -rf "$STAGING"
    fi
    if ((moved_old)) && [[ ! -e "$DEST" && -e "$PREVIOUS" ]]; then
      if mv "$PREVIOUS" "$DEST"; then
        "$LSREGISTER" -f "$DEST" >/dev/null 2>&1
        echo "新版没装上，已把旧版挪回 $DEST" >&2
      else
        echo "新版没装上，旧版也没能挪回去：它在 ${PREVIOUS}，请手动挪回 $DEST" >&2
      fi
    fi
    if ((quit_sent)) && [[ -e "$DEST" ]]; then
      echo "重新打开原来那份：$DEST" >&2
      open "$DEST"
    fi
  fi
  if ((have_lock)); then
    rm -rf "$LOCK"
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ---------- 互斥 ----------

mkdir -p "$WORK"
if ! mkdir "$LOCK" 2>/dev/null; then
  holder=$(cat "$LOCK/pid" 2>/dev/null || true)
  echo "已有一个 install-local.sh 在跑（锁：${LOCK}，pid ${holder:-未知}）。" >&2
  if [[ -n "$holder" ]] && ! kill -0 "$holder" 2>/dev/null; then
    echo "pid $holder 已经不在了，多半是上次被强杀留下的锁；确认没有别的安装在跑后执行 rm -rf $LOCK 再试。" >&2
  fi
  exit 1
fi
have_lock=1
echo $$ > "$LOCK/pid"

# ---------- 检查目标 ----------

check_dest() {
  local dir
  dir=$(dirname "$DEST")
  if [[ -e "$DEST/Contents/_MASReceipt" ]]; then
    echo "$DEST 是从 Mac App Store 装的商店版（带 _MASReceipt），本脚本不覆盖它，什么都没动。" >&2
    echo "商店版是沙盒配置，历史在 ~/Library/Containers/${BUNDLE_ID}；直分发版读 ~/Library/Application Support/Copyo，两份互不相通。" >&2
    echo "要改用本机构建：先退出商店版，把 $DEST 移到废纸篓（商店装的归 root，Finder 会要管理员密码），再重跑本脚本。" >&2
    exit 1
  fi
  # 替换要在 $dir 里挪走旧版、放进新版；把 .app 挪到别的目录还要求它本身可写
  if [[ ! -w "$dir" ]]; then
    echo "当前用户（$(id -un)）没有写 $dir 的权限，什么都没动。" >&2
    echo "本脚本不用 sudo：换一个对 $dir 有写权限的账户（通常是管理员）来跑。" >&2
    exit 1
  fi
  if [[ -e "$DEST" && ! -w "$DEST" ]]; then
    echo "当前用户（$(id -un)）没有写 $DEST 的权限（属主多半是 root），挪不走旧版，什么都没动。" >&2
    echo "本脚本不用 sudo：先 sudo chown -R $(id -un) ${DEST}，或手动把它删掉，再重跑本脚本。" >&2
    exit 1
  fi
}

check_dest

# ---------- 编译 ----------

echo "编译 Release（直分发配置）…"
if ! xcodebuild build \
      -project Copyo.xcodeproj \
      -scheme Copyo \
      -configuration Release \
      -destination "platform=macOS,arch=$(uname -m)" \
      -derivedDataPath "$DERIVED" \
      -allowProvisioningUpdates \
      > "$LOG" 2>&1; then
  echo "编译失败，完整日志：$LOG" >&2
  grep -E "error:" "$LOG" | head -20 >&2 || tail -20 "$LOG" >&2
  if grep -qiE "provisioning profile|signing certificate|No Account for Team|requires a development team" "$LOG"; then
    echo "" >&2
    echo "看起来是签名问题：Xcode → Settings → Accounts 登录并选中团队 9A94W79V84，" >&2
    echo "再用 Xcode 打开一次工程让它注册本机。详见 scripts/build-release.sh 头部。" >&2
  fi
  exit 1
fi
# xcodebuild 在「跳过了 target」之类的情况下照样返回 0（ci.yml 里踩过），产物得自己确认
[[ -d "$BUILT" ]] || { echo "xcodebuild 返回 0 但没产出 $BUILT" >&2; exit 1; }
codesign --verify --strict "$BUILT"

version=$(defaults read "$PWD/$BUILT/Contents/Info.plist" CFBundleShortVersionString)
build=$(defaults read "$PWD/$BUILT/Contents/Info.plist" CFBundleVersion)
commit=$(git rev-parse --short HEAD)
dirty=$(git diff --quiet HEAD -- . 2>/dev/null && echo "" || echo "（含未提交改动）")
echo "编译完成：$version ($build)，$commit$dirty"

# 先把新版拷到目标旁边：和 $DEST 在同一个卷上，之后换上去是一次 rename，退出 App 后停机最短
rm -rf "$STAGING"
ditto "$BUILT" "$STAGING"

# ---------- 退出 /Applications 那一份 ----------

# 列出当前用户的 Copyo 进程，每行「pid<TAB>可执行文件路径」。
# 进程名都叫 Copyo：Debug / worktree 构建、-demoData 拍摄实例、模拟器里的 iOS 版都在内，靠路径区分。
copyo_processes() {
  local pid exe
  for pid in $(pgrep -x -U "$(id -u)" Copyo || true); do
    exe=$(ps -o comm= -p "$pid" 2>/dev/null || true)
    if [[ -n "$exe" ]]; then
      printf '%s\t%s\n' "$pid" "$exe"
    fi
  done
}

dest_pids() {
  copyo_processes | awk -F '\t' -v exe="$DEST_EXE" '$2 == exe { print $1 }'
}

# 编译要几分钟，这期间目标可能变了，退出 App 前再查一次
check_dest

pids=$(dest_pids)
if [[ -n "$pids" ]]; then
  echo "退出正在运行的 ${DEST}（pid ${pids//$'\n'/ }）…"
  quit_sent=1
  # 先礼貌地退出，让 SwiftData 把 -wal 落盘。按路径 tell 只会发给这个路径下的那一份，
  # 同 bundle ID 的其他实例收不到（用两个同 ID 的小程序实测过）；它没在跑时也不会被拉起来。
  # osascript 会同步等对方回复，App 卡死时默认要等 120 秒才超时；这里限定 5 秒，超时就走下面的 kill
  osascript -e 'with timeout of 5 seconds' -e "tell application \"$DEST\" to quit" -e 'end timeout' >/dev/null 2>&1 || true
  for _ in $(seq 1 25); do
    [[ -z "$(dest_pids)" ]] && break
    sleep 0.2
  done
  remaining=$(dest_pids)
  if [[ -n "$remaining" ]]; then
    echo "5 秒还没退，结束 pid ${remaining//$'\n'/ }" >&2
    # shellcheck disable=SC2086  # 可能不止一个 pid，按空白拆开
    kill $remaining 2>/dev/null || true
    for _ in $(seq 1 10); do
      [[ -z "$(dest_pids)" ]] && break
      sleep 0.2
    done
    remaining=$(dest_pids)
    if [[ -n "$remaining" ]]; then
      echo "pid ${remaining//$'\n'/ } 结束不掉，没有替换。" >&2
      exit 1
    fi
  fi
fi

# ---------- 替换 ----------

if [[ -e "$DEST" ]]; then
  rm -rf "$PREVIOUS"
  mkdir -p "$(dirname "$PREVIOUS")"
  # 先记下再挪：信号恰好落在 mv 期间时，cleanup 仍会按「目标不在、备份在」把旧版挪回来
  moved_old=1
  mv "$DEST" "$PREVIOUS"
  backed_up=1
  "$LSREGISTER" -u "$PREVIOUS" >/dev/null 2>&1 || true
fi
mv "$STAGING" "$DEST"
installed=1

# 构建产物也会被 Xcode 登记进 LaunchServices，注销掉，本机只认 /Applications 这一份
"$LSREGISTER" -u "$PWD/$BUILT" >/dev/null 2>&1 || true
"$LSREGISTER" -f "$DEST" >/dev/null 2>&1 || true

open "$DEST"
echo "已安装并启动：${DEST}（$version ($build)，$commit${dirty}）"
if ((backed_up)); then
  echo "上一版备份在 $PREVIOUS"
fi

# 别的 Mac 实例不碰，只提醒；模拟器里的 iOS 版不注册 Mac 的全局快捷键，不提
others=$(copyo_processes | awk -F '\t' -v exe="$DEST_EXE" '$2 != exe && $2 !~ /\/CoreSimulator\//')
if [[ -n "$others" ]]; then
  echo ""
  echo "注意：还有别的 Copyo 在跑，它们会和刚装的这份抢 ⇧⌘V，用完记得退出："
  echo "$others" | while IFS=$'\t' read -r pid exe; do
    echo "  pid $pid  $exe"
  done
fi
