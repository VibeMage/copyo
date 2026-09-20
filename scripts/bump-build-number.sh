#!/usr/bin/env bash
# 把上架配置的构建号 +1。
#
# 只动 Copyo target 的 Release-AppStore 配置（project.pbxproj 里的对象
# AB0000000000000000000011）。Debug / Release 两个配置是直分发版用的，
# 归 build-release.sh 管，这里一律不碰——它们和上架构建号没有关系。
#
# 用法：
#   ./scripts/bump-build-number.sh          # +1
#   ./scripts/bump-build-number.sh --show   # 只打印当前值，不改
#   ./scripts/bump-build-number.sh 7        # 直接设成 7（必须大于当前值）
#
# build-appstore.sh 默认会先调用本脚本；传 NO_BUMP=1 可跳过（重试失败的构建时用，
# 构建号本身只要递增就行，跳号无害）。
set -euo pipefail
cd "$(dirname "$0")/.."

PBXPROJ=Copyo.xcodeproj/project.pbxproj
# 上架配置的对象 ID。改工程结构时若这个 ID 变了，本脚本会直接报错而不是改错配置。
APPSTORE_CONFIG_ID=AB0000000000000000000011

python3 - "$PBXPROJ" "$APPSTORE_CONFIG_ID" "${1:-}" <<'PY'
import re, sys, pathlib

path, config_id, arg = sys.argv[1], sys.argv[2], sys.argv[3]
text = pathlib.Path(path).read_text()

# 定位该配置块：从对象 ID 起到本块结束，避免命中别的配置里同名的设置
block = re.search(
    re.escape(config_id) + r'\s*/\*.*?\*/\s*=\s*\{.*?\n\t\t\};',
    text, re.S)
if not block:
    sys.exit(f"在 {path} 里找不到配置对象 {config_id}；工程结构变了，请更新脚本")

field = re.search(r'CURRENT_PROJECT_VERSION = (\d+);', block.group(0))
if not field:
    sys.exit(f"配置 {config_id} 里没有 CURRENT_PROJECT_VERSION")

current = int(field.group(1))

if arg == '--show':
    print(current)
    raise SystemExit(0)

if arg:
    try:
        new = int(arg)
    except ValueError:
        sys.exit(f"构建号必须是整数，收到：{arg}")
    if new <= current:
        sys.exit(f"构建号只能递增：当前 {current}，要设成 {new}")
else:
    new = current + 1

start, end = block.span()
updated_block = block.group(0).replace(
    f'CURRENT_PROJECT_VERSION = {current};',
    f'CURRENT_PROJECT_VERSION = {new};', 1)
pathlib.Path(path).write_text(text[:start] + updated_block + text[end:])
print(f"{current} -> {new}")
PY
