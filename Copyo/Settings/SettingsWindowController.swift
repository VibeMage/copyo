import AppKit
import SwiftData
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    /// 当前页。窗口只建一次、之后反复 show，所以选页状态必须活在窗口外面，
    /// 不然「窗口已开着时从同步格点进来」切不过去。
    private let selection = SettingsSelection()

    convenience init(container: ModelContainer) {
        // 窗口外框固定 540 × 460，内容区高度由 SettingsLayout 按标题栏扣出来（第八节第 9 条）
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0,
                                                  width: SettingsLayout.width,
                                                  height: SettingsLayout.contentHeight),
                              styleMask: SettingsLayout.styleMask,
                              backing: .buffered,
                              defer: false)
        // 设计稿标题栏只写「设置」
        window.title = String(localized: "Settings")
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.contentView = NSHostingView(rootView: SettingsView(selection: selection).modelContainer(container))
    }

    /// 打开并切到指定页；`tab` 为 nil 时停在上次看的那页。
    /// 窗口已经开着也照切——面板顶栏的同步格点进来必须直达「同步」。
    func show(tab: SettingsTab? = nil) {
        if let tab {
            selection.tab = tab
        }
        NSApp.activate(ignoringOtherApps: true)
        // 已经在屏幕上就别再居中：用户拖过的位置不该被每次打开抢回去
        if window?.isVisible != true {
            window?.center()
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
