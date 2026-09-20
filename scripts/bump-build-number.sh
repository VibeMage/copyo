#!/usr/bin/env bash
# 把某个平台上架配置的构建号 +1。
#
# macOS 与 iOS 是**同一条** App Store Connect 记录下的两个平台（两个 app target 的
# bundle id 都是 dev.vibemage.Copyo），而 App Store Connect 的构建号是按平台各记各的：
# 两边互不影响，也不需要对齐。所以本脚本按平台**成组**地改，而不是一次改光所有 target，
# 也不是只改一个——以前只改 macOS 那一个，iOS 三个 target 至今还停在 1。
#
# 每个平台要动的 Release-AppStore 配置对象（project.pbxproj 里的对象 ID）：
#   macos : Copyo                AB0000000000000000000011
#   ios   : Copyo iOS            AB000000000000000000003F
#           CopyoShareExtension  AB0000000000000000000042
#           CopyoWidgets         AB0000000000000000000045
#
# iOS 那三个必须一起改。App 包里嵌的 .appex 的 CFBundleVersion 与宿主 App 不一致时，
# Apple 会退回整个提交，而这三个 target 平时谁也不会想起另外两个——所以这里一次改三个，
# 并在改之前校验三者本来就一致，不一致直接报错。宁可在这里停下，也不要出一个
# 归档十几分钟、上传后才被退回的包。
#
# Debug / Release 两个配置是直分发版用的，归 build-release.sh 管，这里一律不碰——
# 它们和上架构建号没有关系。
#
# 用法：
#   ./scripts/bump-build-number.sh                 # macOS +1（默认平台，保持原有用法）
#   ./scripts/bump-build-number.sh --ios           # iOS 三个 target 同步 +1
#   ./scripts/bump-build-number.sh --ios --show    # 只打印当前值，不改
#   ./scripts/bump-build-number.sh --macos 7       # 直接设成 7（必须大于当前值）
#
# 参数冲突一律报错，不做「后者覆盖前者」：重复的平台标志、重复的构建号、
# --show 与构建号同时出现，都会停在参数解析这一步，一个字节也不写。
#
# build-appstore.sh 默认会先调用本脚本；传 NO_BUMP=1 可跳过（重试失败的构建时用，
# 构建号本身只要递增就行，跳号无害）。
set -euo pipefail
cd "$(dirname "$0")/.."

PBXPROJ=Copyo.xcodeproj/project.pbxproj

# 平台标志与构建号参数不限先后顺序，但每一类**只允许出现一次**，冲突一律报错。
# 曾经把 --show 和显式构建号存进同一个变量、后者覆盖前者：`--show 7` 于是变成一次
# 静默的写入，而调用者以为自己只是在查看；`--ios --macos` 同理会安静地改到另一个
# 平台上去。这和下面「未知参数一律报错」是同一条理由——写错平台名时若默默退回默认值，
# 改的就是另一个平台的构建号，而这件事要到上传被拒时才看得出来。
PLATFORM=""
SHOW=0
NUMBER=""
for a in "$@"; do
  case "$a" in
    --macos|--ios)
      if [[ -n "$PLATFORM" ]]; then
        echo "平台只能指定一次：已经收到 --$PLATFORM，又收到 $a" >&2
        exit 1
      fi
      PLATFORM="${a#--}"
      ;;
    --show)
      if [[ "$SHOW" == 1 ]]; then
        echo "--show 重复出现" >&2
        exit 1
      fi
      SHOW=1
      ;;
    -*)
      echo "未知参数：$a（可用：--macos / --ios / --show / <构建号>）" >&2
      exit 1
      ;;
    *)
      # 空串也要拦：NUMBER 用「非空」判断有没有给构建号，放进来就成了一次看不见的默认 +1
      if [[ -z "$a" ]]; then
        echo "收到一个空参数（可用：--macos / --ios / --show / <构建号>）" >&2
        exit 1
      fi
      if [[ -n "$NUMBER" ]]; then
        echo "构建号只能指定一次：已经收到 $NUMBER，又收到 $a" >&2
        exit 1
      fi
      NUMBER="$a"
      ;;
  esac
done
if [[ "$SHOW" == 1 && -n "$NUMBER" ]]; then
  echo "--show 只读不写，不能和显式构建号 $NUMBER 一起用（想设成 $NUMBER 就去掉 --show）" >&2
  exit 1
fi
# 平台缺省为 macos，保持原有用法：不带参数就是 macOS +1
PLATFORM="${PLATFORM:-macos}"

python3 - "$PBXPROJ" "$PLATFORM" "$SHOW" "$NUMBER" <<'PY'
import re, sys, pathlib

path, platform, show, number = sys.argv[1], sys.argv[2], sys.argv[3] == '1', sys.argv[4]

# 平台 -> [(target 名, Release-AppStore 配置对象 ID)]。改工程结构时若某个 ID 变了，
# 下面会直接报错而不是改错配置。
CONFIGS = {
    'macos': [('Copyo', 'AB0000000000000000000011')],
    'ios': [('Copyo iOS', 'AB000000000000000000003F'),
            ('CopyoShareExtension', 'AB0000000000000000000042'),
            ('CopyoWidgets', 'AB0000000000000000000045')],
}

text = pathlib.Path(path).read_text()


def read_version(source, name, config_id):
    """从 pbxproj 文本里取出某个配置对象的 CURRENT_PROJECT_VERSION，返回 (匹配块, 值)。"""
    # 必须锚到**定义**而不是引用：同一个对象 ID 在 pbxproj 里出现两次，一次是
    # XCBuildConfiguration 的定义，一次是 XCConfigurationList 的 buildConfigurations 引用。
    # 旧写法只要 `ID ... = {`，再靠 re.S 下的 `.*?` 跨行找块尾——实测把定义行改个名，
    # 它就从 XCConfigurationList 里那行引用重新匹配上，并一路吃到下一个无关的块里去。
    # 今天不出事只是因为 XCBuildConfiguration 段恰好排在 XCConfigurationList 之前。
    # 三重锚点：行首正好两个 Tab（引用行是三个）、`= {` 之后紧跟 `isa = XCBuildConfiguration;`、
    # 块尾是顶层缩进的 `\n\t\t};`。
    pattern = re.compile(
        r'^\t\t' + re.escape(config_id) + r'\b[^\n{]*=\s*\{\n'
        r'\t\t\tisa = XCBuildConfiguration;\n'
        r'.*?\n\t\t\};$',
        re.S | re.M)
    found = list(pattern.finditer(source))
    # 0 个和 2 个以上都必须炸掉：静默取第一个，等于在工程结构变化后继续「成功」地改错配置
    if len(found) != 1:
        sys.exit(f"在 {path} 里定位 {name} 的 XCBuildConfiguration {config_id} 失败："
                 f"匹配到 {len(found)} 处（期望 1 处）；工程结构变了，请更新脚本")
    block = found[0]
    field = re.search(r'^\t+CURRENT_PROJECT_VERSION = (\d+);$', block.group(0), re.M)
    if not field:
        sys.exit(f"{name} 的配置 {config_id} 里没有 CURRENT_PROJECT_VERSION")
    return block, int(field.group(1))


def scan_versions(source):
    """逐行扫描出「顶层对象 ID -> CURRENT_PROJECT_VERSION」，供核对使用。

    刻意**不复用** read_version 那条跨行正则：拿写入时用的同一条表达式再读一遍，
    只能证明这条表达式自洽，证不了它当初定位对了——改错的块会被原样重新找到，
    然后拿刚写进去的值自我确认，报告成功。
    这里换一条路：pbxproj 的顶层对象一律「两个 Tab + 对象 ID + ... = {」起头、
    「两个 Tab + };」结尾，块内设置至少三个 Tab，按缩进切块不依赖任何跨行匹配。
    """
    versions = {}
    current = None
    for line in source.splitlines():
        head = re.match(r'^\t\t([0-9A-Fa-f]{24})\b[^\n{]*= \{$', line)
        if head:
            current = head.group(1)
            continue
        if line == '\t\t};':
            current = None
            continue
        field = re.match(r'^\t+CURRENT_PROJECT_VERSION = (\d+);$', line)
        if field and current is not None:
            versions[current] = int(field.group(1))
    return versions


targets = CONFIGS[platform]
blocks = [(name, cid) + read_version(text, name, cid) for name, cid in targets]

# 写之前先用扫描器交叉核对一次定位结果。两条独立的路径都指向同一个块、读出同一个值，
# 才说明「匹配到了」也「匹配对了」；不一致就在动文件之前停下。
scanned_before = scan_versions(text)
for name, cid, _, value in blocks:
    if scanned_before.get(cid) != value:
        sys.exit(f"{name} 的配置 {cid} 定位存疑：正则读出 {value}，"
                 f"独立扫描读出 {scanned_before.get(cid)}；未改动 {path}，请更新脚本")

values = {value for *_, value in blocks}
current = max(values)

if len(values) > 1:
    detail = '，'.join(f'{name} = {value}' for name, _, _, value in blocks)
    # 不一致就不能靠 +1 修好：+1 只会把差值原样带到下一个号。必须显式指定一个号，
    # 把三个 target 一次拉平。
    if show or not number:
        sys.exit(f"{platform} 各 target 的构建号不一致（{detail}）。\n"
                 f"嵌入的 .appex 与宿主 App 的 CFBundleVersion 不一致，整个提交会被 Apple 退回。\n"
                 f"用 ./scripts/bump-build-number.sh --{platform} {current + 1} 把它们一次对齐。")
    print(f"注意：原本不一致（{detail}），本次统一设为指定值")

if show:
    print(current)
    raise SystemExit(0)

if number:
    try:
        new = int(number)
    except ValueError:
        sys.exit(f"构建号必须是整数，收到：{number}")
    if new <= current:
        sys.exit(f"构建号只能递增：当前 {current}，要设成 {new}")
else:
    new = current + 1

# 从文件末尾往前改。每次替换都会改变后面内容的偏移量，按正序写回的话，
# 第二个块之后拿到的 span() 就全错位了。
for name, config_id, block, value in sorted(blocks, key=lambda b: b[2].start(), reverse=True):
    start, end = block.span()
    updated_block = block.group(0).replace(
        f'CURRENT_PROJECT_VERSION = {value};',
        f'CURRENT_PROJECT_VERSION = {new};', 1)
    text = text[:start] + updated_block + text[end:]
pathlib.Path(path).write_text(text)

# 写回后用扫描器（而不是写入时那条正则）重新读一遍全文核对。「匹配到了」不等于「改对了」，
# 所以核对两件事：该改的都改成了 new，**以及**全文里其他配置的构建号一个都没动。
# 后半条才是真正能抓住「改到别的块上去」的那一条——只查前半条的话，写错块之后
# 目标块反而没变，核对同样会失败，但错误信息会指向一个看不出问题的地方。
# 改错的代价是一个归档十几分钟、上传后才被退回的包，在这里多扫一遍文件便宜得多。
verify = pathlib.Path(path).read_text()
scanned_after = scan_versions(verify)
expected = dict(scanned_before)
for _, config_id in targets:
    expected[config_id] = new
if scanned_after != expected:
    drift = [f"{cid}: {scanned_before.get(cid)} -> {scanned_after.get(cid)}"
             f"（期望 {expected.get(cid)}）"
             for cid in sorted(set(expected) | set(scanned_after))
             if scanned_after.get(cid) != expected.get(cid)]
    sys.exit("写回后核对失败，以下配置对象与预期不符：\n  " + "\n  ".join(drift)
             + f"\n请检查 {path}")

suffix = '' if len(targets) == 1 else '（' + ' / '.join(n for n, _ in targets) + ' 同步）'
print(f"{current} -> {new}{suffix}")
PY
