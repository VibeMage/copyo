import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftData
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            HistorySettingsView()
                .tabItem { Label("Clipboard", systemImage: "clock.arrow.circlepath") }
            SyncSettingsView()
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath.icloud") }
            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 400)
    }
}

// MARK: - 通用

struct GeneralSettingsView: View {
    @AppStorage("autoPaste") private var autoPaste = true
    @AppStorage("plainTextPaste") private var plainTextPaste = false
    @AppStorage("pasteSound") private var pasteSound = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessibilityTrusted = PasteService.isAccessibilityTrusted

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
                Toggle("Paste into the previous app on selection", isOn: $autoPaste)
                Toggle("Always paste as plain text", isOn: $plainTextPaste)
                Toggle("Paste sound", isOn: $pasteSound)
            } footer: {
                if autoPaste && !accessibilityTrusted {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Auto-paste requires Accessibility permission")
                        Button("Open System Settings") {
                            openAccessibilitySettings()
                        }
                    }
                    .font(.system(size: 12))
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityTrusted = PasteService.isAccessibilityTrusted
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
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

#if APPSTORE

/// App Store 版本跑在沙盒里，手输的路径一律无权访问：同步目录必须由用户
/// 在 NSOpenPanel 里亲自选中，再把安全作用域书签存下来长期复用。
struct SyncSettingsView: View {
    @AppStorage("icloudSync") private var icloudSync = false
    @AppStorage(SyncService.lastSyncedAtKey) private var lastSyncedAt = 0.0
    @AppStorage(SyncService.lastErrorKey) private var lastError = ""
    // 解析书签会读文件系统并可能回写 UserDefaults，绝不能放在 @State 的初值里：
    // SwiftUI 每次重算父视图 body 都会重建这个 struct，副作用会跟着反复触发。
    @State private var folderPath: String?

    private var lostAccess: Bool { lastError == SyncService.SyncFailure.noAccess.rawValue }

    var body: some View {
        Form {
            Section {
                Toggle("Sync clipboard history", isOn: $icloudSync)
                    .disabled(folderPath == nil)
                    .onChange(of: icloudSync) { _, _ in
                        AppDelegate.shared?.syncService.updateActivation()
                    }
                if icloudSync && folderPath != nil {
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
                        if icloudSync {
                            statusLine
                        }
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
            }
        }
        .formStyle(.grouped)
        .task { refreshFolderPath() }
        // 同步目录可能在应用不活跃时被删除/卸载，回到前台时重新确认一次，
        // 否则这一页会一直显示早已失效的旧路径。
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshFolderPath()
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

struct SyncSettingsView: View {
    @AppStorage("icloudSync") private var icloudSync = false
    @AppStorage("syncFolderOverride") private var syncFolderOverride = ""

    var body: some View {
        Form {
            Section {
                Toggle("Sync clipboard history", isOn: $icloudSync)
                    .disabled(!SyncService.isAvailable)
                    .onChange(of: icloudSync) { _, _ in
                        AppDelegate.shared?.syncService.updateActivation()
                    }
                if icloudSync && SyncService.isAvailable {
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
        .formStyle(.grouped)
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
        (String(localized: "Paste selected item"), "↩"),
        (String(localized: "Paste selected item as plain text"), "⌥↩"),
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
