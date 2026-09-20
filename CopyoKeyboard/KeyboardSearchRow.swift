import SwiftUI

/// 设计 07 的搜索行：高 36、圆角 10、底色 `key`、左右内距 10、元素间距 6，
/// 15pt `sec` 的占位「搜索历史」+ `magnifyingglass`，右端 12pt `ter` 的提示。
///
/// **右端那句提示改了文案。** 设计稿写的是「↑ 长按卡片预览」，那个 `↑` 指的是预览从卡片
/// **向上弹出**——`.contextMenu(preview:)` 就是那么弹的。但自定义键盘不许在键盘主视图的
/// 上边界之外显示按键图形，向上弹出的预览正好撞在这条上。预览因此改成盖在 330 之内的浮层
/// （见 `ClipPreviewOverlay`），提示里的箭头一并去掉，只剩「长按卡片预览」。
/// 已记进 design-spec 第八节等待设计确认。
///
/// 这一行同时是**搜索的入口**：点它就把键位调出来，敲的字进查询而不是进宿主输入框。
/// 设计稿没有画搜索进行中的样子，这里的处理（accent 描边 + 右端命中条数）是新加的，
/// 同样记进了第八节。
struct KeyboardSearchRow: View {
    /// 外观。理由见 `CopyoTheme.keyCap(for:)`
    let scheme: ColorScheme
    /// 查询状态。**这是全键盘唯一读 `query` 的地方**，理由写在 `KeyboardSearch` 的文档注释里：
    /// 读它的视图每敲一个字符就要重画一次，所以只能是这 36pt 的一行，不能是根视图
    let search: KeyboardSearch
    /// 当前可筛的全部条目。命中条数在**本视图**里算而不是由上层算好传进来，
    /// 正是上面那条理由的延伸——算一遍就要读一次 `query`，交给上层等于把上层也拖进重画
    let clips: [KeyboardClip]
    /// 键位敲出来的字**此刻**正在进这个查询。
    ///
    /// 与 `search.isActive` 不是一回事：按下「搜索」去看结果之后，搜索这一程还没结束
    /// （查询还在、清除按钮还在），但正文区已经换回卡片条、键位也交还给宿主输入框了。
    /// accent 环画的是「字往哪儿去」，所以只能跟这个值走，不能跟 `isActive` 走——
    /// 跟错了就会在键位其实写宿主的时候还亮着环，那是**主动误导**
    let capturesKeys: Bool
    /// 点这一行（除了右端的清除按钮）
    let onActivate: () -> Void
    /// 清除查询并退出搜索
    let onClear: () -> Void

    /// 行高（设计 07）。用 `minHeight` 而不是 `height`：字号放大档位下写死高度会把
    /// 「搜索历史」四个字从上下切掉，比不跟随放大还糟。36 不在系统文本样式的默认点数上，
    /// 按 `KindBadge` 的写法用 `@ScaledMetric`
    @ScaledMetric(relativeTo: .subheadline) private var minHeight: CGFloat = 36
    /// 圆角（设计 07）
    var cornerRadius: CGFloat = 10
    /// 元素间距（设计 07 `gap:6`）
    var spacing: CGFloat = 6
    /// 左右内距（设计 07 `padding:0 10`）
    var horizontalPadding: CGFloat = 10

    private var query: String { search.query }
    private var isActive: Bool { search.isActive }
    private var hasQuery: Bool { !query.isEmpty }

    /// 当前查询命中几条。只在查询非空时显示——它是**边打边看**的唯一反馈：
    /// 330pt 里塞不下「键位 + 结果」两块（算一遍就知道：正文区 228 减掉三排键的 148
    /// 只剩 80，而一张 dense 卡片放不进去），所以打字的时候卡片条是看不见的。
    /// 没有这个数字，用户就在完全没有回声的情况下打字。
    ///
    /// 40 条 × 一次 240 字以内的子串查找，每敲一个字符跑一遍，量级可以忽略
    private var matchCount: Int {
        clips.filter { $0.matches(query: query) }.count
    }

    var body: some View {
        HStack(spacing: spacing) {
            // 图标与文字合成**一个**无障碍元素，右端的清除按钮留在外面自成一个：
            // 用 `.combine` 把整行（含按钮）并成一个的话，旁白就再也点不到那颗按钮了，
            // 而「清除搜索」是这一行上唯一的退出口
            HStack(spacing: spacing) {
                // 设计第五节：搜索 = `magnifyingglass`
                Image(systemName: "magnifyingglass")
                    // 设计 07 这一行 15pt → 契约里的 `.subheadline`
                    .font(.subheadline)
                    .foregroundStyle(CopyoTheme.labelSecondary)

                Text(hasQuery ? query : String(localized: "Search history"))
                    .font(.subheadline)
                    // 有查询时是用户自己敲的内容，要用主文字色；占位才是 `sec`
                    .foregroundStyle(hasQuery ? CopyoTheme.label : CopyoTheme.labelSecondary)
                    .lineLimit(1)
                    // 查询长了从**头部**截：末尾几个字符是刚敲进去的，看不见刚敲的字
                    // 等于在盲打
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onActivate)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Search history"))
            .accessibilityValue(query)
            .accessibilityAddTraits([.isSearchField, .isButton])

            trailing
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 2)
        .frame(minHeight: minHeight)
        .background(CopyoTheme.keyCap(for: scheme),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            // 设计稿没有搜索进行中这一态。描边是这里加的：键位敲出来的字进的是这一行
            // 而不是宿主输入框，这件事必须一眼看得见，否则用户会以为自己把字打进了消息里
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(CopyoTheme.accent, lineWidth: capturesKeys ? 2 : 0)
        }
    }

    /// 右端这块位置：搜索这一程里是「命中条数 + 清除」，其余时候是那句提示。
    ///
    /// **判据是 `isActive` 而不是 `hasQuery`。** 查询为空时也必须给出清除按钮——
    /// 否则「点了搜索行、一个字还没敲」这个状态没有任何退出口，
    /// 用户会以为键盘把字吃了。
    @ViewBuilder
    private var trailing: some View {
        if isActive {
            HStack(spacing: spacing) {
                if hasQuery {
                    Text(matchCountText)
                        // 设计 07 右端提示 12pt → 契约里的 `.caption`
                        .font(.caption)
                        .foregroundStyle(CopyoTheme.labelTertiary)
                        .lineLimit(1)
                }
                Button(action: onClear) {
                    // 设计第五节：关闭 = `xmark`；这里用带底的一档，36 高的行里
                    // 光一个 `xmark` 的点按目标太小
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(CopyoTheme.labelSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Clear Search"))
            }
            .fixedSize(horizontal: true, vertical: false)
        } else {
            // 不在搜索中才显示提示：搜索时这块位置要留给「N 条」与清除按钮，
            // 而一句「长按卡片预览」在打字的时候也没人会读
            Text(String(localized: "Hold a card to preview"))
                .font(.caption)
                .foregroundStyle(CopyoTheme.labelTertiary)
                .lineLimit(1)
                // 法语这句（`Appui long : aperçu`）比中英文长一截，而左边的占位
                // `Rechercher dans l’historique` 更长。窄机身上两边抢不过来时，
                // **让提示先让位**：占位说的是这一行能做什么，提示只是锦上添花。
                // 低优先级 + 先缩后截，是这条取舍的两半
                .minimumScaleFactor(0.8)
                .layoutPriority(-1)
        }
    }

    /// 英语的 `1 matches` 是错的，所以单数单独一个键——与本仓库
    /// `1 character · Plain text` / `%lld characters · Plain text` 同一种写法，
    /// 不用 xcstrings 的 variations（目录是手工维护的，多一层结构就多一处会漏掉的地方）
    private var matchCountText: String {
        matchCount == 1
            ? String(localized: "1 match")
            : String(format: String(localized: "%lld matches"), matchCount)
    }
}
