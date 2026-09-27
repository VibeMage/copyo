import AppKit
import SwiftUI

/// ClipCard · dense 内部用到、但不属于共享 token 的几何量。数值取自 `gen_v2.py` 的 `card()` / `body_*()`；
/// 两端共用的尺寸（260 × 184、内距 12、圆角 12、缩略图圆角 10）仍从 `CopyoTheme.Dense` 取。
enum ClipCardMetrics {
    /// 头行高 18、底行高 20、三段之间 gap 8（design-spec 3.1）
    static let headerHeight: CGFloat = 18
    static let footerHeight: CGFloat = 20
    static let sectionSpacing: CGFloat = 8
    static let headerSpacing: CGFloat = 6
    /// 底行来源图标位 20 × 20、圆角 5
    static let sourceIconSize: CGFloat = 20
    static let sourceIconRadius: CGFloat = 5

    /// 第八节第 37(b) 条：来源名段可用宽小于「两个全角字 + …」时整段隐藏，只留时间
    static let sourceNameMinWidth: CGFloat = 33

    /// 设计稿给的是 CSS 行高（12/16、11/15），SwiftUI 只有行距可调，行距 = 行高 − 字体自身的行高。
    /// 不能照搬 iOS 的 `cardLineSpacing(dense:) = 4`：那是按 13pt 的 17 行高推的，
    /// 套在 12pt 上每行变成 18.4，6 行（第 38 条）就装不进 106pt 的正文区，末行会被切掉半截。
    /// Mac 不跟随系统文字大小（第 34 条），字体是死的，算一次即可。
    static let bodyLineSpacing = lineSpacing(for: .systemFont(ofSize: 12), lineHeight: 16)
    static let monoLineSpacing = lineSpacing(for: .monospacedSystemFont(ofSize: 11, weight: .regular), lineHeight: 15)

    private static func lineSpacing(for font: NSFont, lineHeight: CGFloat) -> CGFloat {
        max(0, lineHeight - NSLayoutManager().defaultLineHeight(for: font))
    }

    /// 正文最多读多少字符进 `Text`。可见的只有 6 行 × 约 40 字；把几十 KB 的整段日志交给文字排版，
    /// 每次重绘都要从头排一遍，面板横向滚动时会掉帧。
    static let bodyCharacterBudget = 800

    /// 朗读摘要截断到 120 个字符（design-spec 4.7.2，第八节第 24 条整体采纳）
    static let accessibilitySummaryLimit = 120
}

extension View {
    /// 可点元素的光标：macOS 15+ 用 `.pointerStyle(.link)`，14 回退 `NSCursor.pointingHand`（design-spec 4.3「光标形态」）。
    ///
    /// `nested` 给卡片里面的动作簇按钮用：它们与卡片同为手型，14 上由卡片一处负责即可，按钮自己不再动光标。
    func clipCardPointer(nested: Bool = false) -> some View {
        modifier(ClipCardPointerModifier(nested: nested))
    }
}

/// 14 上不用 push / pop：SwiftUI 在视图被移除（从自己的垃圾桶按钮删掉这张卡）或面板 orderOut 时
/// 不会补发 onHover(false)，栈里会留下没弹出的手型，之后别的卡 pop 回去的还是手型，整个面板光标都变成手。
/// 改成 `onContinuousHover` 每次移动都 `set()`：不依赖成对的进出事件，被 AppKit 光标矩形改回箭头也会在下一次移动时纠正；
/// 离开时设回箭头，视图消失时若指针还在里面也设回箭头。
private struct ClipCardPointerModifier: ViewModifier {
    let nested: Bool
    @State private var isInside = false

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.pointerStyle(.link)
        } else if nested {
            content
        } else {
            content
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        if !isInside { isInside = true }
                        NSCursor.pointingHand.set()
                    case .ended:
                        isInside = false
                        NSCursor.arrow.set()
                    }
                }
                .onDisappear {
                    guard isInside else { return }
                    isInside = false
                    NSCursor.arrow.set()
                }
        }
    }
}
