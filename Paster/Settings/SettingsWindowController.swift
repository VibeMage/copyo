import AppKit
import SwiftData
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    convenience init(container: ModelContainer) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "Paster 设置"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView().modelContainer(container))
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
