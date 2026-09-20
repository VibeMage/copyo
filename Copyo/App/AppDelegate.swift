import AppKit
import CopyoCore
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
    /// 这次启动解析出来的数据库位置。defaultStoreURL() 会建目录、还会跑一次旧库搬迁，
    /// 不适合在「删除所有数据」的对话框里反复调用，所以启动时存下来。
    private(set) var storeURL: URL?
    private let hotkey = HotkeyManager()
    private var statusItem: NSStatusItem!
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        UserDefaults.standard.register(defaults: [
            "historyLimit": 500,
            "plainTextPaste": false,
        ])

        // 同步方式决定容器怎么建，必须在建库之前定下来（老配置的迁移也在这里发生）
        let syncMode = SyncMode.migrateIfNeeded()
        // 迁移之后立刻记「这份库镜像过 CloudKit」。「删除所有数据」靠它判断能不能删
        // 库文件——删掉的同时也会删掉服务器变更令牌，而云端那份还在。
        DataEraser.markMirroredIfNeeded()
        // 上一次启动留下的 iCloud 错误到此为止，这一轮的真实结果在下面重新记录；
        // 不清的话用户换回 iCloud 时会看到一条早就修好的旧错误
        CloudSyncStatus.clearErrors()

        do {
            let storeURL = try CopyoStore.defaultStoreURL()
            self.storeURL = storeURL
            // 「删除所有数据」的收尾：SQLite 不会把释放的页清零，行删掉了正文还能从文件里
            // 捞出来（实测 400 条擦除后还剩 83 条可读，-wal 里另有 240 条）。容器一建起来
            // 就没有关闭的 API，所以只能趁现在、在 makeContainer 之前把库文件整个删掉重建。
            // 先清标记再动文件：万一删到一半出事，下次启动不会卡在同一步上反复重来。
            if UserDefaults.standard.bool(forKey: DataEraser.pendingScrubKey) {
                UserDefaults.standard.set(false, forKey: DataEraser.pendingScrubKey)
                CopyoStore.destroyStore(at: storeURL)
            }
            // 没有 iCloud entitlement 时 SwiftData 照样能建出 CloudKit 容器，只是一个字节都传不出去，
            // 下面的 catch 永远抓不到，所以必须自己先判一次并把原因写给设置页。
            let wantsCloudKit = syncMode == .icloud && CloudSyncStatus.hasCloudKitEntitlement
            if syncMode == .icloud && !wantsCloudKit {
                CloudSyncStatus.record(containerError: String(localized: "This copy of Copyo is not signed for iCloud sync."))
            }
            do {
                container = try CopyoStore.makeContainer(url: storeURL, cloudKit: wantsCloudKit)
                cloudKitActive = wantsCloudKit
                if wantsCloudKit {
                    // 这份库被 CloudKit 镜像打开过。「删除所有数据」要靠它判断云端是不是
                    // 有一份这次会话够不着的副本——够不着的时候既不能吹「一起删了」，
                    // 也不能删库文件。
                    UserDefaults.standard.set(true, forKey: DataEraser.everMirroredKey)
                }
            } catch where wantsCloudKit {
                // CloudKit 镜像建不起来（数据库结构不满足 CloudKit 要求、容器不可用等）：
                // 退回同一个文件的本地容器，历史一条不少，只是这次启动不同步；
                // 原因记下来给设置页显示，绝不能因此崩溃或落到内存库。
                CloudSyncStatus.record(containerError: error.localizedDescription)
                container = try CopyoStore.makeContainer(url: storeURL, cloudKit: false)
            }
        } catch {
            // 数据库损坏等极端情况：退化为内存存储，保证应用可用
            let schema = Schema(CopyoSchema.models)
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
            // CloudKit 的远程变更靠静默推送下发。Copyo 是常驻菜单栏的应用，
            // 一开就是好几天，不注册推送的话别的设备改了什么只有下次启动才看得到。
            // 按 Apple 文档（Syncing a Core Data store with CloudKit），下行数据由系统
            // 在后台完成，应用不需要把 didReceiveRemoteNotification 转发给容器。
            NSApplication.shared.registerForRemoteNotifications()
        } else {
            // 这次会话不镜像到 CloudKit，就不该继续挂着推送注册。隐私政策里把 iCloud
            // 那一段的推送写成「iCloud 方式专有」，不撤销的话那句话是假的。
            // 注意它只撤销本机的 APNs 注册：CloudKit 自己在私有数据库里建的
            // CKDatabaseSubscription 不受影响，Copyo 没有删除它的途径。
            NSApplication.shared.unregisterForRemoteNotifications()
        }

        // 自动化/截图辅助：-forceDark 强制深色外观；-showSettings 直接打开设置窗口；
        // -showPanel 启动即拉起面板（拍商店截图时用，省得去模拟 ⇧⌘V——
        // 全局快捷键走 Carbon，模拟按键要给控制方开辅助功能权限）
        if ProcessInfo.processInfo.arguments.contains("-forceDark") {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        if ProcessInfo.processInfo.arguments.contains("-showSettings") {
            openSettings()
        }
        if ProcessInfo.processInfo.arguments.contains("-showPanel") {
            panelController.show()
        }

        // 首次启动：LSUIElement 应用没有窗口也没有 Dock 图标，
        // 不主动引导的话用户根本不知道快捷键的存在
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            showWelcome()
        }

        // 「删除所有数据」会让应用自己退出再起来。LSUIElement 没有 Dock 图标也没有窗口，
        // 不给一句交代的话用户只看到菜单栏图标消失又出现，会以为崩了、然后再按一次。
        if UserDefaults.standard.bool(forKey: DataEraser.justErasedKey) {
            UserDefaults.standard.set(false, forKey: DataEraser.justErasedKey)
            let done = NSAlert()
            done.messageText = String(localized: "Everything on this Mac was deleted.")
            NSApp.activate(ignoringOtherApps: true)
            done.runModal()
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

    /// 用户在 Applications 里再次双击 Copyo 时呼出面板（否则毫无反应，会以为应用坏了）
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        panelController.show()
        return false
    }

    private func showWelcome() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Welcome to Copyo")
#if APPSTORE
        // 沙盒版的面板里有齿轮按钮，这里是唯一能告诉用户设置在哪的地方；
        // 直接分发版只能靠右键菜单栏图标打开设置。
        alert.informativeText = String(localized: """
        Copyo lives in the menu bar (the clipboard icon in the top-right corner).

        • Press \(HotkeyConfig.load().displayString) anytime to bring up the clipboard panel
        • Everything you copy is saved automatically — type to search
        • Select an item and press Return to put it back on the clipboard, then paste it with ⌘V
        • Open Settings from the gear in the panel, or by right-clicking the menu bar icon
        """)
#else
        alert.informativeText = String(localized: """
        Copyo lives in the menu bar (the clipboard icon in the top-right corner).

        • Press \(HotkeyConfig.load().displayString) anytime to bring up the clipboard panel
        • Everything you copy is saved automatically — type to search
        • Select an item and press Return to put it back on the clipboard, then paste it with ⌘V
        • Open Settings by right-clicking the menu bar icon
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
            icon?.accessibilityDescription = "Copyo"
            button.image = icon ?? NSImage(systemSymbolName: "doc.on.clipboard.fill",
                                           accessibilityDescription: "Copyo")
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
        let openItem = NSMenuItem(title: String(localized: "Open Copyo"),
                                  action: #selector(openPanel),
                                  keyEquivalent: config.keyEquivalentCharacter ?? "")
        openItem.keyEquivalentModifierMask = config.cocoaModifiers
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: String(localized: "Clear History…"), action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        let eraseItem = NSMenuItem(title: String(localized: "Delete All Data…"), action: #selector(deleteAllData), keyEquivalent: "")
        eraseItem.target = self
        menu.addItem(eraseItem)

        let settingsItem = NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: String(localized: "Quit Copyo"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        // 临时挂载菜单以支持右键弹出，弹出后立即移除，保持左键点击直接开面板
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPanel() {
        panelController.show()
    }

    /// 为了换同步方式重启自己。重启回来直接停在同步页，否则 LSUIElement 应用回来
    /// 什么都不显示，跟没反应一样。
    ///
    /// 派不出子进程时绝不能退出，只能如实报告——设置本身已经由 @AppStorage 写进
    /// UserDefaults 了，所以无论用户什么时候手动重开，生效的都是新方式。
    @discardableResult
    func restartForSyncChange() -> Bool {
        guard PasteService.relaunch(arguments: ["-showSettings",
                                                "-settingsTab", String(SettingsTab.sync.rawValue)]) else {
            let alert = NSAlert()
            alert.messageText = String(localized: "Copyo could not restart itself.")
            alert.informativeText = String(localized: "Quit Copyo from the menu bar icon and open it again. Your new sync setting is already saved.")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return false
        }
        return true
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
        alert.informativeText = String(localized: "This deletes every clipboard entry that isn’t pinned to a Pinboard. Pinned entries and Pinboards are kept — use Delete All Data to remove those too. This action cannot be undone.")
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

    /// 「删除所有数据」。设置页也调它——两条路必须是同一个流程，而且 SwiftUI 在一个
    /// alert 的动作里再弹第二个 alert 会被直接吞掉，失败时就什么都不显示。NSAlert 没这问题。
    @objc func deleteAllData() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Delete All Data?")
        alert.informativeText = DataEraser.confirmationMessage
        alert.alertStyle = .critical
        alert.addButton(withTitle: String(localized: "Delete All"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        // NSAlert 默认把先加进去的那个按钮绑到 Return 上。销毁性操作不能是默认按钮：
        // 随手敲一下回车就把全部数据删了。位置不变（销毁项在右），只改键。
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        report(DataEraser.eraseAll())
    }

    /// 擦除结果一律要有回声：菜单栏这条路没有窗口，什么都不说的话用户会再按一次
    private func report(_ result: DataEraser.Result) {
        guard result.outcome != .relaunching else { return }   // 进程马上就没了，弹窗没意义
        let alert = NSAlert()
        switch result.outcome {
        case .relaunching:
            return
        case .failed:
            alert.alertStyle = .critical
            alert.messageText = String(localized: "Copyo could not delete your clipboard history.")
            alert.informativeText = String(localized: "Nothing was deleted. Try again, and if it keeps failing, quit Copyo from the menu bar icon and open it again.")
        case .cloudWipePending:
            alert.messageText = String(localized: "Everything on this Mac was deleted.")
            alert.informativeText = String(localized: "Copyo is sending the deletion to your iCloud private database. Keep Copyo open and signed in to iCloud. Copyo cannot tell you when this has finished.")
        case .icloudCopyRemains:
            alert.messageText = String(localized: "Everything on this Mac was deleted.")
            alert.informativeText = String(localized: "The copy in your iCloud private database was not touched, because iCloud sync is off. Set Sync to iCloud, reopen Copyo and delete again to remove it too.")
        case .relaunchFailed:
            alert.messageText = String(localized: "Everything on this Mac was deleted.")
            alert.informativeText = String(localized: "Quit Copyo from the menu bar icon and open it again — it finishes clearing the database file on the next launch.")
        }
        if result.syncFolderUnreachable {
            alert.informativeText += " " + String(localized: "Copyo could not reach your sync folder, so the copy there was not deleted. Choose the folder again in Settings, or delete it yourself.")
        }
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// CloudKit 那一路的后半程，由设置页那一行的按钮调用
    @objc func finishErasing() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Finish erasing this Mac?")
        alert.informativeText = String(localized: "Copyo restarts and clears the database file, so the entries you deleted cannot be recovered from this Mac. Anything the deletion has not reached in your iCloud private database stays there and will come back to this Mac.")
        alert.alertStyle = .critical
        alert.addButton(withTitle: String(localized: "Restart Copyo"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard DataEraser.finishScrub() == false else { return }
        let failed = NSAlert()
        failed.messageText = String(localized: "Copyo could not restart itself.")
        failed.informativeText = String(localized: "Quit Copyo from the menu bar icon and open it again — it finishes clearing the database file on the next launch.")
        NSApp.activate(ignoringOtherApps: true)
        failed.runModal()
    }
}
