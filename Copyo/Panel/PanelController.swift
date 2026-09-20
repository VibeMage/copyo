import AppKit
import CopyoCore
import SwiftData
import SwiftUI

/// 无边框面板：允许成为 key window 以接收键盘输入（搜索、方向键导航）
final class SlidePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 管理从屏幕底部滑出的主面板：显示/隐藏动画、焦点、粘贴回调。
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let panelHeight: CGFloat = 380

    private let panel: SlidePanel
    private let pasteService: PasteService
    /// 打开面板前的前台应用，粘贴时要把焦点还给它
    private(set) var previousApp: NSRunningApplication?
    private var isAnimatingOut = false
    /// 面板内弹出 alert（如新建 Pinboard）期间置 true，避免 resignKey 触发自动收起
    var suppressAutoHide = false

    var isVisible: Bool { panel.isVisible }

    init(container: ModelContainer, pasteService: PasteService) {
        self.pasteService = pasteService
        panel = SlidePanel(contentRect: .zero,
                           styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered,
                           defer: false)
        super.init()

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.delegate = self

        let rootView = PanelRootView(
            onCopy: { [weak self] item, asPlainText in
                self?.copyAndDismiss(item, asPlainText: asPlainText)
            },
            onClose: { [weak self] in
                self?.hide(reactivatePrevious: true)
            }
        )
        .modelContainer(container)

        let hostingView = NSHostingView(rootView: AnyView(rootView))
        panel.contentView = hostingView
    }

    func toggle() {
        if panel.isVisible {
            hide(reactivatePrevious: true)
        } else {
            show()
        }
    }

    func show() {
        guard !panel.isVisible else { return }
        // 前台应用可能已经是 Copyo 自己（如设置窗口在前台），此时保留上一次记录的目标应用
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }

        let screen = screenWithMouse() ?? NSScreen.main
        guard let screen else { return }
        let height = Self.panelHeight
        let finalFrame = NSRect(x: screen.frame.minX,
                                y: screen.frame.minY,
                                width: screen.frame.width,
                                height: height)
        panel.setFrame(finalFrame.offsetBy(dx: 0, dy: -height), display: false)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(finalFrame, display: true)
        }

        NotificationCenter.default.post(name: .copyoPanelDidShow, object: nil)
    }

    /// - Parameter reactivatePrevious: Esc/快捷键主动关闭或选中条目后把焦点还给之前的应用；
    ///   点击其他应用导致的收起则不需要（焦点已经在那个应用上）
    func hide(reactivatePrevious: Bool = false) {
        guard panel.isVisible, !isAnimatingOut else { return }
        isAnimatingOut = true
        let downFrame = panel.frame.offsetBy(dx: 0, dy: -panel.frame.height)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(downFrame, display: true)
        }, completionHandler: {
            MainActor.assumeIsolated {
                self.panel.orderOut(nil)
                self.isAnimatingOut = false
            }
        })
        if reactivatePrevious {
            previousApp?.activate(options: [])
        }
    }

    /// 不带动画地立刻收起。「删除所有数据」要在删之前确保面板不再显示已删对象，
    /// 而 hide() 是异步动画、而且 `guard panel.isVisible` 会让它在面板没开时直接返回。
    /// 注意这只是把窗口 orderOut：宿主视图和它的 @State 与进程同寿命，不会重建，
    /// 所以调用方还要发一次 .copyoDidEraseAll 让面板自己把瞬时状态清掉。
    func hideImmediately() {
        isAnimatingOut = false
        panel.orderOut(nil)
    }

    /// 面板内的 alert 关闭后重新拿回键盘焦点
    func makePanelKey() {
        guard panel.isVisible else { return }
        panel.makeKeyAndOrderFront(nil)
    }

    /// 选中条目：写回剪贴板，收起面板并把焦点还给之前的应用，用户接着按 ⌘V 即可
    private func copyAndDismiss(_ item: ClipItem, asPlainText: Bool) {
        pasteService.copyToPasteboard(item, asPlainText: asPlainText)
        hide(reactivatePrevious: true)
    }

    /// 面板显示在鼠标所在的屏幕（多显示器场景）
    private func screenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // 点击面板以外区域时自动收起；面板自己的 alert 抢走 key 时除外
        guard !suppressAutoHide else { return }
        hide()
    }
}

extension Notification.Name {
    /// 面板每次呼出时发出，供 PanelRootView 重置搜索/选中状态
    static let copyoPanelDidShow = Notification.Name("CopyoPanelDidShow")
    static let copyoDidEraseAll = Notification.Name("CopyoDidEraseAll")
}
