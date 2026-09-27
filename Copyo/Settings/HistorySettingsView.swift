import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 历史

/// 历史页：上限、忽略名单、危险操作三组（v2 `Settings-history.dc.html` 左窗）。
struct HistorySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("historyLimit") private var historyLimit = 500
    @State private var showClearConfirm = false

    var body: some View {
        SettingsPage {
            // 第八节第 41 条：五档保留不动
            SettingsGroup {
                SettingsRow(title: Text("Keep up to"),
                            lead: { SettingsTile(hex: "#FF9F0A", symbol: "clock") },
                            trailing: {
                                Picker(selection: $historyLimit) {
                                    Text("100 items").tag(100)
                                    Text("300 items").tag(300)
                                    Text("500 items").tag(500)
                                    Text("1000 items").tag(1000)
                                    Text("Unlimited").tag(0)
                                } label: {
                                    Text("Keep up to")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .fixedSize()
                            })
            }
            SettingsFooter("When the limit is exceeded, the oldest unpinned entries are removed automatically. Anything pinned to a Pinboard is unaffected.")

            SettingsHeader("Don’t Record These Apps", subtitle: "Nothing you copy in them goes into your history")
            IgnoredAppsList()

            SettingsGroup {
                dangerRow(title: Text("Clear History…"),
                          subtitle: Text("Only removes entries that aren’t pinned to a Pinboard"),
                          tile: SettingsTile(color: CopyoTheme.destructive, symbol: "trash")) {
                    showClearConfirm = true
                }
                SettingsSeparator()
                dangerRow(title: Text("Delete All Data…"),
                          subtitle: Text("Includes every Pinboard and everything pinned to it"),
                          tile: SettingsTile(hex: "#8E8E93", symbol: "trash")) {
                    // 确认和结果都交给 AppDelegate 里那套 NSAlert：菜单栏和这里必须是
                    // 同一个流程，而且擦除失败要再弹一个 alert——SwiftUI 在一个 alert 的
                    // 动作里弹第二个会被直接吞掉，那正好是「什么都没删，却什么都不显示」。
                    AppDelegate.shared?.deleteAllData()
                }
            }
        }
        // 第八节第 21 条：设置页保留原生 .confirmationDialog；删什么由 HistoryClearing 统一决定
        .confirmationDialog("Clear History?", isPresented: $showClearConfirm) {
            Button("Clear", role: .destructive) {
                HistoryClearing.clearUnpinned(in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes every clipboard entry that isn’t pinned to a Pinboard. Pinned entries and Pinboards are kept — use Delete All Data to remove those too. This action cannot be undone.")
        }
    }

    /// 危险操作行：整行是按钮，主文用 `destructive` 色（设计稿 `label_color=DESTRUCT_L`）
    private func dangerRow(title: Text, subtitle: Text, tile: SettingsTile,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SettingsRow(title: title, subtitle: subtitle, titleColor: CopyoTheme.destructive) { tile }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 忽略名单

/// 「不记录这些 App」：App 列表 + 底部 `+` / `−`（第八节第 10 条，替掉原来的 bundle ID 文本框）。
///
/// 存储仍是原来那个 `ignoredApps` 字符串（换行分隔的 bundle ID）：ClipboardMonitor 按它过滤，
/// 老用户手填的名单原样显示，一个字都不用迁移。
private struct IgnoredAppsList: View {
    @AppStorage("ignoredApps") private var ignoredApps = ""
    @State private var apps: [IgnoredApp] = []
    @State private var selection: String?

    var body: some View {
        SettingsGroup {
            if apps.isEmpty {
                Text("No apps added")
                    .font(.system(size: 12))
                    .foregroundStyle(CopyoTheme.labelMeta)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    .padding(.horizontal, 12)
            } else {
                ForEach(apps) { app in
                    row(app)
                    if app.id != apps.last?.id {
                        SettingsSeparator()
                    }
                }
            }
            SettingsSeparator()
            plusMinusBar
        }
        .task(id: ignoredApps) {
            // NSWorkspace 查 App 位置与图标都碰文件系统，不放进 body（7.5.5 同一条规矩）；
            // 名单变了才重算
            apps = Self.parse(ignoredApps).map(IgnoredApp.init(bundleID:))
            if let selection, !apps.contains(where: { $0.id == selection }) {
                self.selection = nil
            }
        }
    }

    /// 一行：24pt 图标 + 13pt 名称 + 10pt 等宽 bundle ID（`labelTertiary`），高 36
    private func row(_ app: IgnoredApp) -> some View {
        let isSelected = selection == app.id
        return HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            Text(verbatim: app.name)
                .font(.system(size: 13))
                .foregroundStyle(CopyoTheme.label)
                .lineLimit(1)
            if app.name != app.id {
                Text(verbatim: app.id)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CopyoTheme.labelTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(isSelected ? CopyoTheme.tintBlue : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selection = isSelected ? nil : app.id }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    /// 底部 24pt 高的 `+` / `−` 条，两枚 28pt 宽的按钮，右侧各一条竖分隔
    private var plusMinusBar: some View {
        HStack(spacing: 0) {
            barButton(symbol: "plus", label: Text("Add App"), action: addApp)
            barButton(symbol: "minus", label: Text("Remove Selected App"), action: removeSelected)
                .disabled(selection == nil)
            Spacer(minLength: 0)
        }
        .frame(height: 24)
    }

    private func barButton(symbol: String, label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(CopyoTheme.label)
        .overlay(alignment: .trailing) {
            Rectangle().fill(CopyoTheme.separator).frame(width: 0.5)
        }
        .accessibilityLabel(label)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = String(localized: "Add")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        var ids = Self.parse(ignoredApps)
        for url in panel.urls {
            guard let bundleID = Bundle(url: url)?.bundleIdentifier, !ids.contains(bundleID) else { continue }
            ids.append(bundleID)
        }
        ignoredApps = ids.joined(separator: "\n")
    }

    private func removeSelected() {
        guard let selection else { return }
        ignoredApps = Self.parse(ignoredApps).filter { $0 != selection }.joined(separator: "\n")
        self.selection = nil
    }

    /// 与 `ClipboardMonitor.ignoredBundleIDs` 同一套切法（换行或逗号、去空白），
    /// 手填过逗号分隔的老名单也能原样列出来；这里额外按首次出现去重、保序
    static func parse(_ raw: String) -> [String] {
        var seen = Set<String>()
        return raw
            .split(whereSeparator: { $0.isNewline || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

/// 名单里的一项。找得到 App 就给图标和显示名；卸载了的只剩 bundle ID，用通用 App 图标
private struct IgnoredApp: Identifiable {
    let id: String
    let name: String
    let icon: NSImage

    init(bundleID: String) {
        id = bundleID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            name = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "", options: [.anchored, .backwards])
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            name = bundleID
            icon = NSWorkspace.shared.icon(for: .applicationBundle)
        }
    }
}
