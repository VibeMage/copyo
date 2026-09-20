import SwiftUI

/// 双列瀑布流。设计稿用 CSS `column-count: 2`，SwiftUI 没有等价物：
/// `LazyVGrid` 会把同一行的卡片拉成等高，破坏「高度由内容决定」这一条。
///
/// 这里按估算高度把条目发给当前最矮的那一列，再用两个 `LazyVStack` 铺开。
/// **本身不含 ScrollView**，调用方自己套（历史页要在同一个 ScrollView 里放大标题、搜索栏和 chips）。
struct MasonryGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    var columns: Int = 2
    var spacing: CGFloat = CopyoTheme.Metrics.gridGap
    /// 估算高度，只用于分列；返回值不影响实际渲染
    let estimatedHeight: (Item) -> CGFloat
    @ViewBuilder let content: (Item) -> Content

    init(items: [Item],
         columns: Int = 2,
         spacing: CGFloat = CopyoTheme.Metrics.gridGap,
         estimatedHeight: @escaping (Item) -> CGFloat,
         @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.estimatedHeight = estimatedHeight
        self.content = content
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(distribute().enumerated()), id: \.offset) { _, column in
                LazyVStack(spacing: spacing) {
                    ForEach(column, id: \.item.id) { entry in
                        content(entry.item)
                            // VoiceOver 默认按几何位置走：左列从上到下读完，再回到右列顶上。
                            // 这里的两列是同一条时间线被贪心分列拆开的，几何顺序读出来
                            // 就是「最新、第三新、第五新…」然后跳回「第二新」，完全没法听。
                            // 排序优先级越大越先读，按原下标取负数就还原成时间顺序。
                            .accessibilitySortPriority(-Double(entry.index))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    /// 分列结果里带上原始下标，供旁白还原阅读顺序
    private struct Placed {
        let index: Int
        let item: Item
    }

    /// 贪心分列：每次把下一个条目放进当前累计高度最小的列
    private func distribute() -> [[Placed]] {
        let count = max(1, columns)
        var buckets = Array(repeating: [Placed](), count: count)
        var heights = Array(repeating: CGFloat.zero, count: count)
        for (index, item) in items.enumerated() {
            var target = 0
            for column in 1..<count where heights[column] < heights[target] {
                target = column
            }
            buckets[target].append(Placed(index: index, item: item))
            heights[target] += estimatedHeight(item) + spacing
        }
        return buckets
    }
}
