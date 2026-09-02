import AppKit
import PasterCore
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
    /// 本次启动的容器是不是真的挂上了 CloudKit 镜像。
    /// 设置页据此判断「改完同步方式还需不需要重启」——尤其是从 iCloud 切走的时候，
    /// 不重启的话这次会话仍然在往 iCloud 上传。
    private(set) var cloudKitActive = false
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

        // 同步方式决定容器怎么建，必须在建库之前定下来（老配置的迁移也在这里发生）
        let syncMode = SyncMode.migrateIfNeeded()
        // 上一次启动留下的 iCloud 错误到此为止，这一轮的真实结果在下面重新记录；
        // 不清的话用户换回 iCloud 时会看到一条早就修好的旧错误
        CloudSyncStatus.clearErrors()

        do {
            let storeURL = try PasterStore.defaultStoreURL()
            // 没有 iCloud entitlement 时 SwiftData 照样能建出 CloudKit 容器，只是一个字节都传不出去，
            // 下面的 catch 永远抓不到，所以必须自己先判一次并把原因写给设置页。
            let wantsCloudKit = syncMode == .icloud && CloudSyncStatus.hasCloudKitEntitlement
            if syncMode == .icloud && !wantsCloudKit {
                CloudSyncStatus.record(containerError: String(localized: "This copy of Paster is not signed for iCloud sync."))
            }
            do {
                container = try PasterStore.makeContainer(url: storeURL, cloudKit: wantsCloudKit)
                cloudKitActive = wantsCloudKit
            } catch where wantsCloudKit {
                // CloudKit 镜像建不起来（数据库结构不满足 CloudKit 要求、容器不可用等）：
                // 退回同一个文件的本地容器，历史一条不少，只是这次启动不同步；
                // 原因记下来给设置页显示，绝不能因此崩溃或落到内存库。
                CloudSyncStatus.record(containerError: error.localizedDescription)
                container = try PasterStore.makeContainer(url: storeURL, cloudKit: false)
            }
        } catch {
            // 数据库损坏等极端情况：退化为内存存储，保证应用可用
            let schema = Schema(PasterSchema.models)
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: config)
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

        if cloudKitActive {
            // CloudKit 的远程变更靠静默推送下发。Paster 是常驻菜单栏的应用，
            // 一开就是好几天，不注册推送的话别的设备改了什么只有下次启动才看得到。
            // 按 Apple 文档（Syncing a Core Data store with CloudKit），下行数据由系统
            // 在后台完成，应用不需要把 didReceiveRemoteNotification 转发给容器。
            NSApplication.shared.registerForRemoteNotifications()
        }

        // 用户在系统设置里改动辅助功能授权后，让粘贴路径重新评估并允许再次提示
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pasteService.resetAccessibilityWarning()
            }
        }

        // 自动化/截图辅助：-forceDark 强制深色外观；-showSettings 直接打开设置窗口
        if ProcessInfo.processInfo.arguments.contains("-forceDark") {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        if ProcessInfo.processInfo.arguments.contains("-showSettings") {
            openSettings()
        }

        // 首次启动：LSUIElement 应用没有窗口也没有 Dock 图标，
        // 不主动引导的话用户根本不知道快捷键的存在
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            showWelcome()
        }
    }

    /// 推送注册失败：iCloud 同步本身还能用，只是变更要等下次启动才拉得下来，
    /// 记下来让设置页把这个降级说清楚。
    func application(_ application: NSApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        CloudSyncStatus.record(pushError: error.localizedDescription)
    }

    func application(_ application: NSApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        CloudSyncStatus.record(pushError: "")
    }

    /// 用户在 Applications 里再次双击 Paster 时呼出面板（否则毫无反应，会以为应用坏了）
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        panelController.show()
        return false
    }

    private func showWelcome() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Welcome to Paster")
#if APPSTORE
        // 沙盒版拿不到系统授权弹窗（PasteService.ensureAccessibility 里已说明），
        // 也就不能承诺「会引导授权」；同时这里是唯一能告诉用户设置在哪的地方。
        alert.informativeText = String(localized: """
        Paster lives in the menu bar (the clipboard icon in the top-right corner).

        • Press \(HotkeyConfig.load().displayString) anytime to bring up the clipboard panel
        • Everything you copy is saved automatically — type to search
        • Select an item and press Return to paste it into the previous app. Turn Paster on in System Settings → Privacy & Security → Accessibility to allow this
        • Open Settings from the gear in the panel, or by right-clicking the menu bar icon
        """)
#else
        alert.informativeText = String(localized: """
        Paster lives in the menu bar (the clipboard icon in the top-right corner).

        • Press \(HotkeyConfig.load().displayString) anytime to bring up the clipboard panel
        • Everything you copy is saved automatically — type to search
        • Select an item and press Return to paste it into the previous app (requires Accessibility permission; you’ll be guided through granting it the first time)
        """)
#endif
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
