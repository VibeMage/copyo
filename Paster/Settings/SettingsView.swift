import AppKit
import Carbon.HIToolbox
import CloudKit
import PasterCore
import ServiceManagement
import SwiftData
import SwiftUI

struct SettingsView: View {
    // 截图辅助：-settingsTab <0-4> 指定初始标签页
    @State private var selectedTab: Int = {
        let args = ProcessInfo.processInfo.arguments
        if let flagIndex = args.firstIndex(of: "-settingsTab"),
           args.indices.contains(flagIndex + 1),
           let tab = Int(args[flagIndex + 1]), (0...4).contains(tab) {
            return tab
        }
        return 0
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(0)
            HistorySettingsView()
                .tabItem { Label("Clipboard", systemImage: "clock.arrow.circlepath") }
                .tag(1)
            SyncSettingsView()
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath.icloud") }
                .tag(2)
            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                .tag(3)
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(4)
        }
        .frame(width: 540, height: 400)
    }
}

// MARK: - 通用

struct GeneralSettingsView: View {
    @AppStorage("plainTextPaste") private var plainTextPaste = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            Section {
                Toggle("Always copy as plain text", isOn: $plainTextPaste)
            } footer: {
                Text("Applies when you press Return. ⌥↩ always copies as plain text.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - 历史

struct HistorySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("historyLimit") private var historyLimit = 500
    @AppStorage("ignoredApps") private var ignoredApps = ""
    @State private var showClearConfirm = false

    var body: some View {
        Form {
            Section {
                Picker("History Limit", selection: $historyLimit) {
                    Text("100 items").tag(100)
                    Text("300 items").tag(300)
                    Text("500 items").tag(500)
                    Text("1000 items").tag(1000)
                    Text("Unlimited").tag(0)
                }
            } footer: {
                Text("When the limit is exceeded, the oldest unpinned entries are removed automatically. Anything pinned to a Pinboard is unaffected.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Section("Ignored Apps") {
                TextEditor(text: $ignoredApps)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 80)
                Text("One bundle ID per line (for example com.1password.1password). Copies made in these apps are never recorded. Content that password managers mark as concealed is always skipped.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Clear History…", role: .destructive) {
                    showClearConfirm = true
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Clear History?", isPresented: $showClearConfirm) {
            Button("Clear", role: .destructive) { clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes every clipboard entry that isn’t pinned to a Pinboard. This action cannot be undone.")
        }
    }

    private func clearHistory() {
        let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.pinboard == nil })
        guard let items = try? modelContext.fetch(descriptor) else { return }
        for item in items {
            modelContext.delete(item)
        }
        try? modelContext.save()
        ThumbnailCache.removeAll()
    }
}

// MARK: - 同步

/// 同步方式三选一。「文件夹」是快照同步，不传播删除；「iCloud」把数据库直接
/// 镜像到 CloudKit 私有数据库，删除会在所有设备生效。两种方式共用同一个数据库文件，
/// 但容器是启动时按方式建好的，所以改了方式要重启才换得过来。
struct SyncSettingsView: View {
    @AppStorage(SyncMode.defaultsKey) private var syncModeRaw = SyncMode.off.rawValue

    private var mode: SyncMode { SyncMode(rawValue: syncModeRaw) ?? .off }

    var body: some View {
        Form {
            Section {
                Picker("Sync Method", selection: $syncModeRaw) {
                    Text("Off").tag(SyncMode.off.rawValue)
                    Text("Shared Folder").tag(SyncMode.folder.rawValue)
                    Text(verbatim: "iCloud").tag(SyncMode.icloud.rawValue)
                }
                .onChange(of: syncModeRaw) { _, _ in
                    // 文件夹同步的计时器立刻跟着起停；iCloud 那一路要等重启才换容器
                    AppDelegate.shared?.syncService.updateActivation()
                }
            } footer: {
                Text(modeDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            switch mode {
            case .off:
                EmptyView()
            case .folder:
                FolderSyncSections()
            case .icloud:
                CloudKitSyncSections()
            }

            if needsRestart {
                Section {
                    HStack {
                        Text("Changing the sync method takes effect after you restart Paster.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart Paster") { PasteService.relaunch() }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// 容器是启动时按当时的方式建好的，CloudKit 镜像开不开只能靠重启换。
    /// 从 iCloud 切走时尤其要提示：不重启的话这次会话仍然在往 iCloud 上传。
    private var needsRestart: Bool {
        (mode == .icloud) != (AppDelegate.shared?.cloudKitActive ?? false)
    }

    private var modeDescription: LocalizedStringKey {
        switch mode {
        case .off:
            "Your clipboard history stays on this Mac only."
        case .folder:
            "Snapshot sync through a folder every device can reach. Deletions are not propagated: an entry you delete on one Mac stays on the others."
        case .icloud:
            "Sync through your iCloud account. Every Mac signed in to the same Apple Account sees the same history, and deleting an entry removes it everywhere."
        }
    }
}

// MARK: - iCloud 同步

/// iCloud 同步没有可调的参数，这一页只回答用户唯一关心的问题：现在到底同不同步。
/// 建容器和注册推送都发生在启动时，失败又完全静默，不显式说出来用户根本无从判断。
private struct CloudKitSyncSections: View {
    @AppStorage(CloudSyncStatus.containerErrorKey) private var containerError = ""
    @AppStorage(CloudSyncStatus.pushErrorKey) private var pushError = ""
    @State private var accountStatus: CKAccountStatus?

    var body: some View {
        Section("iCloud Account") {
            if CloudSyncStatus.hasCloudKitEntitlement {
                HStack(spacing: 6) {
                    Image(systemName: accountSymbol)
                        .foregroundStyle(accountTint)
                    Text(accountDescription)
                    Spacer()
                    if accountStatus == .noAccount {
                        Button("Open System Settings") { openAppleAccountSettings() }
                    }
                }
                .font(.system(size: 12))
                .task { accountStatus = await CloudSyncStatus.accountStatus() }
                // 用户很可能是看到提示后切出去登录 iCloud 再切回来的，回前台重查一次
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { accountStatus = await CloudSyncStatus.accountStatus() }
                }
            } else if containerError.isEmpty {
                // 这份构建没有 iCloud entitlement：账号状态查不得（查了会直接终止进程），
                // 启动时也没走 iCloud 那条路，所以在这里直接把原因说出来
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("This copy of Paster is not signed for iCloud sync.")
                }
                .font(.system(size: 12))
            }
            if !containerError.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("iCloud sync could not start: \(containerError)")
                }
                .font(.system(size: 12))
                Text("Paster is using the local database only, so nothing was lost. Fix the problem above and restart Paster.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else if !pushError.isEmpty {
                Text("Push notifications are unavailable on this Mac, so changes made on your other devices only arrive when Paster starts.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 查询结果还没回来时用中性图标，别一进页面就先亮一个橙色警告吓人
    private var accountSymbol: String {
        switch accountStatus {
        case .available: "checkmark.circle.fill"
        case nil: "ellipsis.circle"
        default: "exclamationmark.triangle.fill"
        }
    }

    private var accountTint: Color {
        switch accountStatus {
        case .available: .green
        case nil: .secondary
        default: .orange
        }
    }

    private var accountDescription: LocalizedStringKey {
        switch accountStatus {
        case .available:
            "Signed in to iCloud"
        case .noAccount:
            "No iCloud account is signed in on this Mac"
        case .restricted:
            "iCloud is restricted on this Mac"
        case .temporarilyUnavailable:
            "iCloud is temporarily unavailable"
        case nil:
            "Checking iCloud status…"
        default:
            "Could not determine the iCloud status"
        }
    }

    private func openAppleAccountSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - 文件夹同步

#if APPSTORE

/// App Store 版本跑在沙盒里，手输的路径一律无权访问：同步目录必须由用户
/// 在 NSOpenPanel 里亲自选中，再把安全作用域书签存下来长期复用。
private struct FolderSyncSections: View {
    @AppStorage(SyncService.lastSyncedAtKey) private var lastSyncedAt = 0.0
    @AppStorage(SyncService.lastErrorKey) private var lastError = ""
    // 解析书签会读文件系统并可能回写 UserDefaults，绝不能放在 @State 的初值里：
    // SwiftUI 每次重算父视图 body 都会重建这个 struct，副作用会跟着反复触发。
    @State private var folderPath: String?

    private var lostAccess: Bool { lastError == SyncService.SyncFailure.noAccess.rawValue }

    var body: some View {
        Section {
            if folderPath != nil {
                Button("Sync Now") {
                    AppDelegate.shared?.syncService.syncNow()
                    refreshFolderPath()
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if folderPath == nil {
                    if lostAccess {
                        Text("Paster lost access to the sync folder. Choose it again below to resume syncing.")
                    } else {
                        Text("Choose a sync folder below to turn on syncing.")
                    }
                } else {
                    Text("Your clipboard history and Pinboards sync between your Macs through the folder you chose. The data only ever passes through your own storage — Paster never touches a third-party server. Deletions are not propagated across devices.")
                    statusLine
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Section("Sync Folder") {
            HStack {
                Text(folderPath ?? String(localized: "No folder selected"))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(folderPath == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer()
                Button("Choose Sync Folder…") {
                    chooseFolder()
                }
            }
            Text("Any folder all of your devices share works — for example a folder inside iCloud Drive, or a company drive. Paster keeps its files in a Paster subfolder and can only reach the folder you pick here.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .task { refreshFolderPath() }
                // 同步目录可能在应用不活跃时被删除/卸载，回到前台时重新确认一次，
                // 否则这一页会一直显示早已失效的旧路径。
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    refreshFolderPath()
                }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if lostAccess {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Paster lost access to the sync folder. Choose it again below to resume syncing.")
            }
        } else if lastSyncedAt > 0 {
            Text("Last synced \(Date(timeIntervalSince1970: lastSyncedAt).formatted(date: .abbreviated, time: .shortened))")
        }
    }

    private func refreshFolderPath() {
        folderPath = SyncService.syncRoot?.path
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Choose")
        panel.message = String(localized: "Choose a folder that all of your Macs can read and write.")
        guard panel.runModal() == .OK, let url = panel.url,
              let bookmark = try? url.bookmarkData(options: .withSecurityScope,
                                                   includingResourceValuesForKeys: nil,
                                                   relativeTo: nil) else { return }
        UserDefaults.standard.set(bookmark, forKey: SyncService.bookmarkKey)
        // 重选文件夹就是「失去访问权」的解法，旧的错误状态到此为止
        UserDefaults.standard.set("", forKey: SyncService.lastErrorKey)
        folderPath = url.path
        AppDelegate.shared?.syncService.updateActivation()
    }
}

#else

private struct FolderSyncSections: View {
    @AppStorage("syncFolderOverride") private var syncFolderOverride = ""

    var body: some View {
        Section {
            if SyncService.isAvailable {
                Button("Sync Now") {
                    AppDelegate.shared?.syncService.syncNow()
                }
            }
        } footer: {
            Group {
                if SyncService.isAvailable {
                    Text("By default your clipboard history and Pinboards sync between your Macs through iCloud Drive (iCloud Drive/Paster/). The data only ever passes through your own iCloud — Paster never touches a third-party server. Deletions are not propagated across devices.")
                } else if syncFolderOverride.isEmpty {
                    Text("iCloud Drive is not enabled on this Mac. Turn it on in System Settings → click your name → iCloud, or point Paster at a custom sync folder below.")
                } else {
                    Text("The parent directory of the custom sync folder does not exist. Please check the path.")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        Section("Custom Sync Folder (Optional)") {
            TextField("Leave empty to use iCloud Drive, e.g. ~/Shared/Paster", text: $syncFolderOverride)
                .font(.system(size: 12, design: .monospaced))
                .onSubmit {
                    AppDelegate.shared?.syncService.updateActivation()
                }
            Text("Enter any directory all of your devices can read and write (a company NAS, another cloud-sync folder, and so on) to use it instead of iCloud Drive.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

#endif

// MARK: - 快捷键

struct ShortcutsSettingsView: View {
    @State private var hotkeyDisplay = HotkeyConfig.load().displayString
    @State private var isRecording = false
    @State private var recordingMonitor: Any?

    private let fixedShortcuts: [(String, String)] = [
        (String(localized: "Move between cards"), "← →"),
        (String(localized: "Copy selected item"), "↩"),
        (String(localized: "Copy selected item as plain text"), "⌥↩"),
        (String(localized: "Preview selected item (when search is empty)"), String(localized: "Space")),
        (String(localized: "Search"), String(localized: "Just type")),
        (String(localized: "Delete selected item"), "⌘⌫"),
        (String(localized: "Clear search / Close panel"), "Esc"),
    ]

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Open / Close panel")
                    Spacer()
                    Button {
                        isRecording ? cancelRecording() : startRecording()
                    } label: {
                        Text(isRecording ? String(localized: "Press the new shortcut…") : hotkeyDisplay)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(minWidth: 90)
                    }
                    if HotkeyConfig.load() != .default {
                        Button("Reset") {
                            cancelRecording()
                            HotkeyConfig.resetToDefault()
                            AppDelegate.shared?.reloadHotkey()
                            hotkeyDisplay = HotkeyConfig.load().displayString
                        }
                    }
                }
            } footer: {
                Text(isRecording
                     ? "The combination must include at least one of ⌘, ⌥ or ⌃. Press Esc to cancel."
                     : "Click the shortcut to customize it. The default is ⇧⌘V.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Section {
                ForEach(fixedShortcuts, id: \.0) { name, keys in
                    HStack {
                        Text(name)
                        Spacer()
                        Text(keys)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear { cancelRecording() }
    }

    private func startRecording() {
        isRecording = true
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) && event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                cancelRecording()
                return nil
            }
            let carbon = HotkeyConfig.carbonFlags(from: event.modifierFlags)
            // 必须带 ⌘/⌥/⌃ 至少一个，避免把普通输入键劫持为全局快捷键
            guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty == false else {
                NSSound.beep()
                return nil
            }
            let config = HotkeyConfig(keyCode: UInt32(event.keyCode), carbonModifiers: carbon)
            config.save()
            AppDelegate.shared?.reloadHotkey()
            hotkeyDisplay = config.displayString
            cancelRecording()
            return nil
        }
    }

    private func cancelRecording() {
        if let monitor = recordingMonitor {
            NSEvent.removeMonitor(monitor)
            recordingMonitor = nil
        }
        isRecording = false
    }
}

// MARK: - 关于

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text(verbatim: "Paster")
                .font(.system(size: 22, weight: .bold))
            Text("Version \(version)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("An open-source clipboard manager for macOS.\nAll data stays on this Mac and is never sent to a third-party server.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
