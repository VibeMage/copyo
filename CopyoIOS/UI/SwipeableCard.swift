import SwiftUI

/// 左滑删除（红）/ 右滑固定（蓝）。
///
/// 瀑布流不是 List，`swipeActions` 用不了，只能自己接手势。关键是只在**水平位移明显占优**时才接管，
/// 否则纵向滚动会被吃掉——两列卡片本来就窄，横向误判非常明显。
struct SwipeableCard<Content: View>: View {
    var onDelete: (() -> Void)?
    var onPin: (() -> Void)?
    /// 已经固定过的条目不再提供右滑固定
    var pinEnabled: Bool = true
    @ViewBuilder var content: () -> Content

    /// 全滑阈值：越过就直接执行，不停在半开状态（设计稿的位移量）
    private let actionThreshold: CGFloat = 96
    /// 判定「这是横滑不是纵滚」的最小水平位移
    private let engageThreshold: CGFloat = 12

    /// 24 不在系统文本样式的默认点数上（title2 是 22、title 是 28），按 title2 缩；
    /// 下面那行 12 正好是 `caption`，两者一起跟随辅助功能字号长大。
    @ScaledMetric(relativeTo: .title2) private var actionSymbolSize: CGFloat = 24

    @State private var offset: CGFloat = 0
    @State private var isHorizontal = false

    var body: some View {
        ZStack {
            actionLayer
            content()
                .offset(x: offset)
                .gesture(dragGesture)
                // 左右滑是一条裸 `DragGesture`，旁白用户根本做不出这个手势——
                // 不补这两条具名动作，删除与固定对他们就只存在于「被包的内容恰好也提供了菜单」里。
                //
                // 挂在 `content()` 上而不是外面那个 ZStack 上：卡片是一个合成的无障碍元素，
                // 挂在它自己身上才一定落到那个停留点。
                //
                // 「删除」「固定」这两条具名动作**归这一层所有**：手势是它的，名字也该是它的。
                // 被包的内容不要再给同名动作——两层合成的是同一个停留点，重一条的效果是
                // 转子里连着念两次「删除」，名字一样、落点不同，旁白用户无从分辨。
                // （`HistoryCardView` 因此不给「删除」，它那边的注释也写了归属在这里。）
                .accessibilityActions { swipeActions }
        }
    }

    @ViewBuilder
    private var swipeActions: some View {
        if let onDelete {
            Button(String(localized: "Delete"), action: onDelete)
        }
        if pinEnabled, let onPin {
            Button(String(localized: "Pin"), action: onPin)
        }
    }

    private var actionLayer: some View {
        ZStack {
            if offset < 0 {
                HStack {
                    Spacer()
                    actionLabel(symbol: "trash", title: String(localized: "Delete"))
                        .padding(.trailing, 22)
                }
                .background(CopyoTheme.destructive)
            } else if offset > 0 {
                HStack {
                    actionLabel(symbol: "pin", title: String(localized: "Pin"))
                        .padding(.leading, 22)
                    Spacer()
                }
                .background(CopyoTheme.accent)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous))
        // 这一层只是卡片滑开后露出的底色，语义由上面两条具名动作承担；
        // 不藏起来旁白会在「删除」「固定」两个装饰标签上白停一次
        .accessibilityHidden(true)
    }

    private func actionLabel(symbol: String, title: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: actionSymbolSize, weight: .semibold))
            Text(title)
                .font(.system(.caption, weight: .semibold))
        }
        .foregroundStyle(.white)
    }

    /// 越过阈值后加阻尼，手感上告诉用户「已经到位了」
    private func damped(_ translation: CGFloat) -> CGFloat {
        let magnitude = abs(translation)
        guard magnitude > actionThreshold else { return translation }
        let excess = (magnitude - actionThreshold) * 0.25
        return translation < 0 ? -(actionThreshold + excess) : actionThreshold + excess
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !isHorizontal {
                    // 水平位移要明显大于垂直位移才接管，否则让 ScrollView 继续滚
                    guard abs(value.translation.width) > engageThreshold,
                          abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    isHorizontal = true
                }
                var translation = value.translation.width
                if translation > 0 && (!pinEnabled || onPin == nil) { translation = 0 }
                if translation < 0 && onDelete == nil { translation = 0 }
                offset = damped(translation)
            }
            .onEnded { _ in
                let finished = offset
                isHorizontal = false
                if finished <= -actionThreshold, let onDelete {
                    withAnimation(CopyoTheme.springAnimation) { offset = 0 }
                    onDelete()
                } else if finished >= actionThreshold, pinEnabled, let onPin {
                    withAnimation(CopyoTheme.springAnimation) { offset = 0 }
                    onPin()
                } else {
                    withAnimation(CopyoTheme.springAnimation) { offset = 0 }
                }
            }
    }
}
