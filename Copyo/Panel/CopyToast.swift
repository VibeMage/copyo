import AppKit
import SwiftUI

/// 「已复制」轻提示（design-spec 第八节第 6 条）。
///
/// 复制之后面板会在 0.18s 内收起，画在面板上的提示会跟着一起消失，所以它是一个独立的小窗：
/// 不抢焦点（焦点此刻正要交还给原来的 App，用户马上要按 ⌘V）、不接收鼠标，
/// 出现在同一块屏幕的底部居中、底边落在面板原来的底边处——用户的视线本来就在那里。
/// 约 1.2s 后淡出。只有这一种提示：固定、删除时面板还开着，卡片本身的变化就是反馈。
@MainActor
final class CopyToast {
    private let window: NSPanel
    private let hosting: NSHostingView<ToastView>
    private var hideWork: DispatchWorkItem?
    /// 每次 show 加一。淡出动画一旦开始就取消不了，它的 completion 只在代次没变时才收窗口——
    /// 否则淡出途中再复制一次，刚出来的新提示会被上一次的收尾顺手收掉
    private var generation = 0

    init() {
        window = NSPanel(contentRect: .zero,
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered,
                         defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.level = .statusBar
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hosting = NSHostingView(rootView: ToastView(plainText: false))
        window.contentView = hosting
    }

    /// - Parameters:
    ///   - bottomCenter: 面板底边中点的屏幕坐标
    func show(bottomCenter: NSPoint, plainText: Bool) {
        hideWork?.cancel()
        generation += 1
        let current = generation
        hosting.rootView = ToastView(plainText: plainText)
        let size = hosting.fittingSize
        let finalFrame = NSRect(x: bottomCenter.x - size.width / 2, y: bottomCenter.y,
                                width: size.width, height: size.height)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // 进场从下方 8pt 上移到位并淡入（4.6）；减弱动态时直接出现
        window.setFrame(reduceMotion ? finalFrame : finalFrame.offsetBy(dx: 0, dy: -8), display: true)
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0 : 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(finalFrame, display: true)
            window.animator().alphaValue = 1
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == current else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = reduceMotion ? 0 : 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.window.animator().alphaValue = 0
            }, completionHandler: {
                MainActor.assumeIsolated {
                    guard self.generation == current else { return }
                    self.window.orderOut(nil)
                }
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
        // 小窗不进可访问性焦点，读屏用户靠这句播报知道复制成功了
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: plainText
                ? String(localized: "Copied as plain text · press ⌘V to paste")
                : String(localized: "Copied · press ⌘V to paste"),
            .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
    }
}

private struct ToastView: View {
    let plainText: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(CopyoTheme.success)
            Text(plainText ? "Copied as plain text · press ⌘V to paste" : "Copied · press ⌘V to paste")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CopyoTheme.label)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(GlassBackground(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}
