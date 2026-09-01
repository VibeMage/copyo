import AppKit
import SwiftData
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) static var shared: AppDelegate?

    private(set) var container: ModelContainer!
    private(set) var monitor: ClipboardMonitor!
    private(set) var pasteService: PasteService!
    private(set) var panelController: PanelController!
    private(set) var syncService: SyncService!
    private let hotkey = HotkeyManager()
    private var statusItem: NSStatusItem!
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        UserDefaults.standard.register(defaults: [
            "historyLimit": 500,
            "autoPaste": true,
            "pasteSound": true,
            "plainTextPaste": false,
        ])

        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeDirectory = appSupport.appendingPathComponent("Paster", isDirectory: true)
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            let config = ModelConfiguration(url: storeDirectory.appendingPathComponent("Paster.store"))
            container = try ModelContainer(for: ClipItem.self, Pinboard.self, configurations: config)
        } catch {
            // 数据库损坏等极端情况：退化为内存存储，保证应用可用
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: ClipItem.self, Pinboard.self, configurations: config)
        }

        monitor = ClipboardMonitor(context: container.mainContext)
        pasteService = PasteService(monitor: monitor)
        panelController = PanelController(container: container, pasteService: pasteService)
        syncService = SyncService(context: container.mainContext)

        setupStatusItem()

        hotkey.onHotkey = { [weak self] in
            Task { @MainActor in
                self?.panelController.toggle()
            }
        }
        hotkey.register(HotkeyConfig.load())
        monitor.start()
        syncService.updateActivation()

        // 首次启动：LSUIElement 应用没有窗口也没有 Dock 图标，
        // 不主动引导的话用户根本不知道快捷键的存在
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            showWelcome()
        }
    }

    /// 用户在 Applications 里再次双击 Paster 时呼出面板（否则毫无反应，会以为应用坏了）
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        panelController.show()
        return false
    }

    private func showWelcome() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Welcome to Paster")
        alert.informativeText = String(localized: """
        Paster lives in the menu bar (the clipboard icon in the top-right corner).

        • Press \(HotkeyConfig.load().displayString) anytime to bring up the clipboard panel
        • Everything you copy is saved automatically — type to search
        • Select an item and press Return to paste it into the previous app (requires Accessibility permission; you’ll be guided through granting it the first time)
        """)
        alert.addButton(withTitle: String(localized: "Try It Now"))
        alert.addButton(withTitle: String(localized: "Got It"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            panelController.show()
        }
    }

    /// 设置里改了快捷键后重新注册
    func reloadHotkey() {
        hotkey.register(HotkeyConfig.load())
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            // 自定义模板图标（纯黑+透明），系统按明暗模式自动反色
            let icon = NSImage(named: "MenuBarIcon")
            icon?.isTemplate = true
            icon?.accessibilityDescription = "Paster"
            button.image = icon ?? NSImage(systemSymbolName: "doc.on.clipboard.fill",
                                           accessibilityDescription: "Paster")
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            panelController.toggle()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()

        let config = HotkeyConfig.load()
        let openItem = NSMenuItem(title: String(localized: "Open Paster"),
                                  action: #selector(openPanel),
                                  keyEquivalent: config.keyEquivalentCharacter ?? "")
        openItem.keyEquivalentModifierMask = config.cocoaModifiers
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: String(localized: "Clear History…"), action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        let settingsItem = NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: String(localized: "Quit Paster"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        // 临时挂载菜单以支持右键弹出，弹出后立即移除，保持左键点击直接开面板
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPanel() {
        panelController.show()
    }

    @objc func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(container: container)
        }
        settingsController?.show()
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear History?")
        alert.informativeText = String(localized: "This deletes every clipboard entry that isn’t pinned to a Pinboard. This action cannot be undone.")
        alert.addButton(withTitle: String(localized: "Clear"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let context = container.mainContext
        let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.pinboard == nil })
        if let items = try? context.fetch(descriptor) {
            for item in items {
                context.delete(item)
            }
            try? context.save()
        }
        ThumbnailCache.removeAll()
    }
}
