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

    @State private var offset: CGFloat = 0
    @State private var isHorizontal = false

    var body: some View {
        ZStack {
            actionLayer
            content()
                .offset(x: offset)
                .gesture(dragGesture)
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
                .background(PasterTheme.destructive)
            } else if offset > 0 {
                HStack {
                    actionLabel(symbol: "pin", title: String(localized: "Pin"))
                        .padding(.leading, 22)
                    Spacer()
                }
                .background(PasterTheme.accent)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PasterTheme.Radius.card, style: .continuous))
    }

    private func actionLabel(symbol: String, title: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
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
                    withAnimation(PasterTheme.springAnimation) { offset = 0 }
                    onDelete()
                } else if finished >= actionThreshold, pinEnabled, let onPin {
                    withAnimation(PasterTheme.springAnimation) { offset = 0 }
                    onPin()
                } else {
                    withAnimation(PasterTheme.springAnimation) { offset = 0 }
                }
            }
    }
}
