import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftData
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }
            HistorySettingsView()
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
            SyncSettingsView()
                .tabItem { Label("同步", systemImage: "arrow.triangle.2.circlepath.icloud") }
            ShortcutsSettingsView()
                .tabItem { Label("快捷键", systemImage: "keyboard") }
            AboutView()
                .tabItem { Label("关于", systemImage: "info.circle") }
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
                Toggle("开机时自动启动", isOn: $launchAtLogin)
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
                Toggle("选中后自动粘贴到当前应用", isOn: $autoPaste)
                Toggle("始终以纯文本粘贴", isOn: $plainTextPaste)
                Toggle("粘贴音效", isOn: $pasteSound)
            } footer: {
                if autoPaste && !accessibilityTrusted {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("自动粘贴需要「辅助功能」权限")
                        Button("打开系统设置") {
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
                Picker("历史记录上限", selection: $historyLimit) {
                    Text("100 条").tag(100)
                    Text("300 条").tag(300)
                    Text("500 条").tag(500)
                    Text("1000 条").tag(1000)
                    Text("无限制").tag(0)
                }
            } footer: {
                Text("超出上限时最旧的未固定记录会被自动清理，固定到 Pinboard 的内容不受影响。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Section("忽略的应用") {
                TextEditor(text: $ignoredApps)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 80)
                Text("每行一个 Bundle ID（如 com.1password.1password），来自这些应用的复制不会被记录。密码管理器标记为隐藏的内容始终自动跳过。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("清空历史记录…", role: .destructive) {
                    showClearConfirm = true
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("确定要清空所有未固定的历史记录吗？", isPresented: $showClearConfirm) {
            Button("清空", role: .destructive) { clearHistory() }
            Button("取消", role: .cancel) {}
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

struct SyncSettingsView: View {
    @AppStorage("icloudSync") private var icloudSync = false
    @AppStorage("syncFolderOverride") private var syncFolderOverride = ""

    var body: some View {
        Form {
            Section {
                Toggle("同步历史记录", isOn: $icloudSync)
                    .disabled(!SyncService.isAvailable)
                    .onChange(of: icloudSync) { _, _ in
                        AppDelegate.shared?.syncService.updateActivation()
                    }
                if icloudSync && SyncService.isAvailable {
                    Button("立即同步") {
                        AppDelegate.shared?.syncService.syncNow()
                    }
                }
            } footer: {
                Group {
                    if SyncService.isAvailable {
                        Text("默认经由 iCloud Drive（iCloud Drive/Paster/）在你的多台 Mac 之间同步剪贴板历史与 Pinboard。数据只经过你自己的 iCloud，Paster 不接触任何第三方服务器。删除操作不跨设备传播。")
                    } else if syncFolderOverride.isEmpty {
                        Text("此 Mac 未启用 iCloud Drive。可在 系统设置 → Apple ID → iCloud 中打开 iCloud Drive，或在下方指定一个自定义同步文件夹。")
                    } else {
                        Text("自定义同步文件夹的上级目录不存在，请检查路径。")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            Section("自定义同步文件夹（可选）") {
                TextField("留空使用 iCloud Drive，如 ~/Shared/Paster", text: $syncFolderOverride)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit {
                        AppDelegate.shared?.syncService.updateActivation()
                    }
                Text("填入任意多台设备都能读写的目录（公司 NAS、网盘同步文件夹等）即可代替 iCloud Drive。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 快捷键

struct ShortcutsSettingsView: View {
    @State private var hotkeyDisplay = HotkeyConfig.load().displayString
    @State private var isRecording = false
    @State private var recordingMonitor: Any?

    private let fixedShortcuts: [(String, String)] = [
        ("在卡片间导航", "← →"),
        ("粘贴选中内容", "↩"),
        ("以纯文本粘贴", "⌥↩"),
        ("预览选中内容（搜索框为空时）", "空格"),
        ("搜索", "直接输入"),
        ("删除选中内容", "⌘⌫"),
        ("清除搜索 / 关闭面板", "Esc"),
    ]

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("打开 / 关闭面板")
                    Spacer()
                    Button {
                        isRecording ? cancelRecording() : startRecording()
                    } label: {
                        Text(isRecording ? "请按下新快捷键…" : hotkeyDisplay)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(minWidth: 90)
                    }
                    if HotkeyConfig.load() != .default {
                        Button("重置") {
                            cancelRecording()
                            HotkeyConfig.resetToDefault()
                            AppDelegate.shared?.reloadHotkey()
                            hotkeyDisplay = HotkeyConfig.load().displayString
                        }
                    }
                }
            } footer: {
                Text(isRecording
                     ? "组合键需要至少包含 ⌘、⌥ 或 ⌃ 其中之一，按 Esc 取消。"
                     : "点击快捷键可以自定义，默认 ⇧⌘V。")
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
            Text("Paster")
                .font(.system(size: 22, weight: .bold))
            Text("版本 \(version)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("开源的 macOS 剪贴板管理工具。\n所有数据仅保存在本机，不进行任何网络传输。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
