import AppKit
import CopyoCore
import SwiftData
import SwiftUI

/// 无边框面板：允许成为 key window 以接收键盘输入（搜索、方向键导航）
final class SlidePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 管理 ⇧⌘V 唤出的悬浮面板：定位、显示 / 隐藏动画、预览子窗口、「已复制」轻提示。
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: SlidePanel
    private let pasteService: PasteService
    private let preview = PreviewWindowController()
    private let toast = CopyToast()
    /// 打开面板前的前台应用，复制后要把焦点还给它
    private(set) var previousApp: NSRunningApplication?
    private var isAnimatingOut = false

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
            actions: PanelActions(
                copy: { [weak self] item, asPlainText in
                    self?.copyAndDismiss(item, asPlainText: asPlainText)
                },
                close: { [weak self] in
                    self?.hide(reactivatePrevious: true)
                },
                preview: { [weak self] item in
                    self?.setPreview(item)
                },
                openSettings: { [weak self] tab in
                    self?.hide(reactivatePrevious: false)
                    AppDelegate.shared?.openSettings(tab: tab)
                },
                toScreen: { [weak self] point in
                    // SwiftUI 的 .global 坐标以窗口内容左上角为原点，屏幕坐标以左下角为原点
                    guard let frame = self?.panel.frame else { return .zero }
                    return NSPoint(x: frame.minX + point.x, y: frame.maxY - point.y)
                }
            )
        )
        .modelContainer(container)

        let hostingView = NSHostingView(rootView: AnyView(rootView))
        panel.contentView = hostingView
    }

    // MARK: - 几何

    /// 面板在屏幕上的位置（design-spec 第八节第 1 条）：以鼠标所在屏幕的 visibleFrame 为基准
    /// （扣掉菜单栏与 Dock，此前用 screen.frame 会压在 Dock 下面）；宽 min(1280, 可用宽 − 32)，
    /// 水平居中，底边离 Dock 顶 12。窄屏时卡片不缩，只是同时露出的卡变少、靠横向滚动。
    /// 尺寸是死点数，不随系统文字大小变（第 34 条），1× 与 2× 屏用同一套 pt。
    static func frame(on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let width = min(maxWidth, visible.width - 2 * CopyoTheme.Dense.panelSideMargin)
        return NSRect(x: (visible.midX - width / 2).rounded(),
                      y: visible.minY + CopyoTheme.Dense.panelBottomInset,
                      width: width,
                      height: CopyoTheme.Dense.panelHeight)
    }

    /// 截图辅助：-panelWidth <pt> 把面板宽度上限压窄，效果等同于窄屏（只能压窄，不会超过 1280）。
    /// 商店截图用 1104 = 内距 16 + 4 × 卡宽 260 + 4 × 间距 12：第五张卡的左缘正好落在面板边缘外。
    /// 卡片轨道一直延伸到面板边缘（内距只是轨道内容的起点），取对称的 1108 时第五张会露出 4pt 细边。
    /// 满宽时第五张露出六成，宣传图里像截歪了（2026-09-27 维护者对 1.2.0 截图的意见）。
    private static let maxWidth: CGFloat = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-panelWidth"), args.indices.contains(i + 1),
              let value = Double(args[i + 1]), value > 0 else { return CopyoTheme.Dense.panelWidth }
        return min(CopyoTheme.Dense.panelWidth, CGFloat(value))
    }()

    // MARK: - 显示 / 隐藏

    func toggle() {
        // 淡出途中再按一次快捷键，是想把它叫回来
        if panel.isVisible && !isAnimatingOut {
            hide(reactivatePrevious: true)
        } else {
            show()
        }
    }

    func show() {
        guard !panel.isVisible || isAnimatingOut else { return }
        // 前台应用可能已经是 Copyo 自己（如设置窗口在前台），此时保留上一次记录的目标应用
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }

        guard let screen = screenWithMouse() ?? NSScreen.main else { return }
        isAnimatingOut = false
        let finalFrame = Self.frame(on: screen)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // 从下方 16pt 处上浮并淡入；减弱动态时只淡入
        panel.setFrame(reduceMotion ? finalFrame : finalFrame.offsetBy(dx: 0, dy: -16), display: false)
        panel.alphaValue = 0
        NotificationCenter.default.post(name: .copyoPanelDidShow, object: nil)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            // 减弱动态：直接出现（4.6.1 要求 duration 置 0，不是只去掉位移）
            context.duration = reduceMotion ? 0 : 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(finalFrame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    /// - Parameter reactivatePrevious: Esc / 快捷键主动关闭或复制后把焦点还给之前的应用；
    ///   点击其他应用导致的收起则不需要（焦点已经在那个应用上）
    func hide(reactivatePrevious: Bool = false) {
        guard panel.isVisible, !isAnimatingOut else { return }
        isAnimatingOut = true
        preview.hide()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let downFrame = reduceMotion ? panel.frame : panel.frame.offsetBy(dx: 0, dy: -16)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = reduceMotion ? 0 : 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(downFrame, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated {
                // 收起动画途中又被唤出的话，show() 已经把 isAnimatingOut 复位，这里别把面板收掉
                guard self.isAnimatingOut else { return }
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
        preview.hide()
        panel.orderOut(nil)
    }

    // MARK: - 复制与预览

    /// 选中条目：写回剪贴板，收起面板并把焦点还给之前的应用，用户接着按 ⌘V 即可。
    /// 「已复制」提示出现在面板原来底边的位置（第八节第 6 条）。
    private func copyAndDismiss(_ item: ClipItem, asPlainText: Bool) {
        pasteService.copyToPasteboard(item, asPlainText: asPlainText)
        let bottomCenter = NSPoint(x: panel.frame.midX,
                                   y: (panel.screen?.visibleFrame.minY ?? panel.frame.minY) + CopyoTheme.Dense.panelBottomInset)
        hide(reactivatePrevious: true)
        toast.show(bottomCenter: bottomCenter)
    }

    private func setPreview(_ item: ClipItem?) {
        guard let item, panel.isVisible, !isAnimatingOut else {
            preview.hide()
            return
        }
        preview.show(item, above: panel)
    }

    /// 面板显示在鼠标所在的屏幕（多显示器场景）
    private func screenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // 点击面板以外区域时自动收起。预览窗与轻提示都不能成为 key、菜单在本进程里跟踪、
        // 新建 Pinboard 是面板内联输入，所以这里不再需要任何「抑制自动收起」的例外（第 20 条）
        hide()
    }
}

/// 面板视图向外发出的动作。视图不直接持有控制器，免得预览、轻提示这些窗口逻辑渗进 SwiftUI。
struct PanelActions {
    var copy: (ClipItem, _ asPlainText: Bool) -> Void
    var close: () -> Void
    /// nil 表示关闭预览
    var preview: (ClipItem?) -> Void
    var openSettings: (SettingsTab?) -> Void
    /// SwiftUI .global 坐标 → 屏幕坐标，给弹出菜单定位用
    var toScreen: (CGPoint) -> NSPoint
}

extension Notification.Name {
    /// 面板每次呼出时发出，供 PanelRootView 重置搜索/选中状态
    static let copyoPanelDidShow = Notification.Name("CopyoPanelDidShow")
    static let copyoDidEraseAll = Notification.Name("CopyoDidEraseAll")
}
