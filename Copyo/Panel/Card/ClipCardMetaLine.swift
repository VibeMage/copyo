import SwiftUI

/// 卡片头行的「来源 · 相对时间」。
///
/// 拆成两段（第八节第 37 条，`gen_v2.py` 的 `meta_line`）：时间段固有宽、永不被截，
/// 省略号只吃来源名。画板 v1 是单个 span 从尾部截，截掉的恰恰是时间，那是生成脚本的表达力限制，不照做。
///
/// 来源名段窄到放不下「两个全角字 + …」时连同「 · 」整段隐藏（第 37(b) 条）：
/// 剩一个字加省略号既认不出是哪个 App，又挤掉了本可以完整显示的时间。
/// 用 `ViewThatFits` 在两种排法之间选：第一种的理想宽把来源名封顶在阈值上，
/// 于是「阈值 + · + 时间」放得下就选它、实际排版时来源名再吃掉全部剩余宽度；放不下就退到只有时间。
/// 不用 `minimumScaleFactor`：第 37(b) 条明确不缩字。
struct ClipCardMetaLine: View {
    let source: String
    let time: String
    let color: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                CappedIdealWidth(cap: ClipCardMetrics.sourceNameMinWidth) {
                    Text(source)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                // 「·」两侧用内距而不是空格：文字首尾的空格是否计入宽度随排版引擎而变，内距是确定的
                Text(verbatim: "·")
                    .padding(.horizontal, 3)
                    .fixedSize()
                timeText
            }
            timeText
        }
        .font(CopyoTheme.Dense.Font.meta)
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeText: some View {
        Text(time)
            .lineLimit(1)
            .fixedSize()
    }
}

/// 只改「理想宽」的包装：不给宽度提议时报 `min(子视图理想宽, cap)`，给了具体宽度就原样转交。
/// `ViewThatFits` 按理想宽挑选项，所以它看到的来源名最多只有 `cap` 那么宽；
/// 真正排版时 `HStack` 给出具体宽度，来源名照常吃满剩余空间并在尾部截断。
private struct CappedIdealWidth: Layout {
    let cap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        if proposal.width == nil {
            let ideal = subview.sizeThatFits(.unspecified)
            return CGSize(width: min(ideal.width, cap), height: ideal.height)
        }
        return subview.sizeThatFits(proposal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
}
