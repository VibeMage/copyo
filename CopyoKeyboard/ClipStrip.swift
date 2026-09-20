import SwiftUI

/// 设计 07 的横向剪贴卡片条：dense 卡片，宽 168，间距 8，高度吃满正文区。
struct ClipStrip: View {
    /// 已经按查询筛过的条目
    let clips: [KeyboardClip]
    /// 外观。理由见 `CopyoTheme.keyCap(for:)`
    let scheme: ColorScheme
    /// 查询非空 = 空列表要说「没有匹配的内容」，而不是「还没有剪贴内容」。
    /// 两句话指向完全不同的下一步：一个是改关键词，一个是先去复制点什么
    let isFiltered: Bool
    let onInsert: (KeyboardClip) -> Void
    let onPreview: (KeyboardClip) -> Void

    /// 卡片间距（设计 07 `gap:8`）
    var spacing: CGFloat = 8
    /// 卡片宽（设计 07）
    var cardWidth: CGFloat = 168

    var body: some View {
        if clips.isEmpty {
            emptyState
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                // `LazyHStack` 而不是 `HStack`：一次取 40 条，全部实体化就是 40 张卡片
                // 同时活着，而键盘的预算按 30MB 规划。一屏只看得见两张半
                LazyHStack(spacing: spacing) {
                    ForEach(clips) { clip in
                        ClipStripCard(clip: clip,
                                      scheme: scheme,
                                      onTap: { onInsert(clip) },
                                      onLongPress: { onPreview(clip) },
                                      width: cardWidth)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            // 不用管「筛完要滑回最左」：搜索期间正文区换成了字母面，本视图整个被
            // 从视图树上摘掉，按下「搜索」时是新建的一份，滚动位置本来就从头开始。
            // 真去挂一条 `.scrollPosition(id:)` 反而要小心把用户正在滑的手打断
        }
    }

    private var emptyState: some View {
        Text(isFiltered ? String(localized: "No matches") : String(localized: "No clips yet"))
            .font(.subheadline)
            .foregroundStyle(CopyoTheme.labelSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
