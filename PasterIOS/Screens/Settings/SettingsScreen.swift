import PasterCore
import SwiftData
import SwiftUI

/// 设置总览（设计 04）。
///
/// 三个二级页与「关于」都走 `navigationDestination(item:)` 而不是 `NavigationLink(value:)`：
/// `-demoScreen settings-quicksave` 这类截图参数要在没有用户点击的情况下把页面推出来，
/// 值绑定是唯一不用碰 RootView 里那个 NavigationStack 就能做到的办法。
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model

    @AppStorage(IOSSettings.Key.cloudSyncEnabled, store: IOSSettings.defaults)
    private var cloudSyncEnabled = true
    @AppStorage(IOSSettings.Key.autoReadOnForeground, store: IOSSettings.defaults)
    private var autoReadOnForeground = true
    @AppStorage(IOSSettings.Key.historyLimit, store: IOSSettings.defaults)
    private var historyLimit = 500

    @State private var route: SettingsRoute?
    @State private var showsClearConfirm = false
    /// 截图参数只在第一次出现时生效，从二级页返回后不能再自动推一次
    @State private var didApplyDemoRoute = false

    enum SettingsRoute: Hashable {
        case quickSave
        case howToSave
        case allowPaste
        case about
    }

    var body: some View {
        List {
            syncSection
            clipboardSection
            clearSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(PasterTheme.bgGrouped)
        .navigationTitle(String(localized: "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .quickSave: QuickSaveGuideScreen()
            case .howToSave: HowToSaveScreen()
            case .allowPaste: AllowPasteGuideScreen()
            case .about: AboutScreen()
            }
        }
        .onAppear(perform: applyDemoRouteOnce)
    }

    // MARK: - 同步

    private var syncSection: some View {
        Section {
            Toggle(isOn: $cloudSyncEnabled) {
                HStack(spacing: 12) {
                    SettingsIconTile(symbol: "icloud.fill", color: SettingsTint.cloud)
                    Text(String(localized: "iCloud Sync"))
                        .font(.system(size: 17))
                        .foregroundStyle(PasterTheme.label)
                }
                .frame(height: 52)
            }
            .tint(PasterTheme.switchOn)
            .settingsRow()
            // 容器是在 App 启动时按这个开关建的，运行中改不了，只能提示重开
            .onChange(of: cloudSyncEnabled) { _, _ in
                model.toast.show(String(localized: "Takes effect after you reopen Paster"),
                                 symbol: "arrow.clockwise")
            }

            HStack(spacing: 8) {
                Text(String(localized: "Status"))
                    .font(.system(size: 15))
                    .foregroundStyle(PasterTheme.label)
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    Image(systemName: syncSymbol)
                        .font(.system(size: 15))
                    Text(syncStatusText)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
                .foregroundStyle(PasterTheme.labelSecondary)
            }
            .frame(minHeight: 44)
            // 设计 3.8：子行左内距 58，正好让文字与上一行的标题对齐
            .settingsRow(leading: 58)
        } header: {
            Text(String(localized: "Sync"))
        } footer: {
            Text(String(localized: "Sign in to the same Apple Account on your Mac and iPhone. Your clips travel through iCloud only, never through a third-party server."))
        }
    }

    private var syncSymbol: String {
        switch model.syncStatus.status {
        case .synced: "checkmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .off: "icloud.slash"
        }
    }

    private var syncStatusText: String {
        switch model.syncStatus.status {
        case .synced(let date):
            guard let date else { return String(localized: "Synced") }
            return String(format: String(localized: "Synced · %@"), Self.relativeTime(date))
        case .syncing:
            return String(localized: "Syncing…")
        case .off(let reason):
            // 用户自己关掉时说「未开启」就够了；没签名、没账号这类原因必须说清楚，否则用户无从下手
            if case .disabledInSettings = reason { return String(localized: "Off") }
            return reason.message
        }
    }

    /// 「刚刚 / 5 分钟前」。一分钟内的都算刚刚，否则相对时间会跳成「0 分钟前」。
    private static func relativeTime(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return String(localized: "Just now") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - 剪贴板

    private var clipboardSection: some View {
        Section {
            Button {
                route = .howToSave
            } label: {
                SettingsRowLabel(symbol: "questionmark.circle.fill",
                                 color: SettingsTint.question,
                                 title: String(localized: "How Paster Saves Clips"),
                                 showsDisclosure: true)
            }
            .settingsRow()

            Button {
                route = .quickSave
            } label: {
                SettingsRowLabel(symbol: "bolt.fill",
                                 color: SettingsTint.bolt,
                                 title: String(localized: "Quick Save"),
                                 detail: String(localized: "Action Button"),
                                 showsDisclosure: true)
            }
            .settingsRow()

            Button {
                route = .allowPaste
            } label: {
                // 设计 04 这一格的右值是橙色的「询问」。系统不提供读取「从其他 App 粘贴」
                // 当前值的 API（任何探测都会弹窗），所以不能照抄那个值——那是在假装知道状态。
                // 折中：文案改成「去系统设置里定」，但保住设计的橙色语义（这一项需要用户处理）。
                SettingsRowLabel(symbol: "doc.on.clipboard.fill",
                                 color: SettingsTint.clipboard,
                                 title: String(localized: "Allow Paste from Other Apps"),
                                 detail: String(localized: "In iOS Settings"),
                                 detailColor: PasterTheme.warning,
                                 showsDisclosure: true)
            }
            .settingsRow()

            Toggle(isOn: $autoReadOnForeground) {
                HStack(spacing: 12) {
                    SettingsIconTile(symbol: "arrow.clockwise", color: SettingsTint.autoRead)
                    Text(String(localized: "Read Clipboard Automatically"))
                        .font(.system(size: 17))
                        .foregroundStyle(PasterTheme.label)
                }
                .frame(height: 52)
            }
            .tint(PasterTheme.switchOn)
            .settingsRow()

            Picker(selection: $historyLimit) {
                ForEach(IOSSettings.historyLimitOptions, id: \.self) { limit in
                    if limit == 0 {
                        Text(String(localized: "Unlimited")).tag(limit)
                    } else {
                        Text("\(limit) items").tag(limit)
                    }
                }
            } label: {
                SettingsRowLabel(symbol: "clock.fill",
                                 color: SettingsTint.clock,
                                 title: String(localized: "History Limit"))
            }
            .pickerStyle(.navigationLink)
            .settingsRow()
            // 调小上限要立刻裁掉多余的旧条目，不然用户看不出这次改动有没有生效
            .onChange(of: historyLimit) { _, limit in
                model.applyHistoryLimit(limit)
            }
        } header: {
            Text(String(localized: "Clipboard"))
        } footer: {
            Text(String(localized: "With this off, Paster won't read the clipboard when it opens — use the banner at the top of History to paste and save by hand."))
        }
    }

    // MARK: - 清空历史

    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                showsClearConfirm = true
            } label: {
                Text(String(localized: "Clear History"))
                    .font(.system(size: 17))
                    .foregroundStyle(PasterTheme.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 52)
            }
            .settingsRow()
            // 确认框挂在这一行上：iOS 26 会把它从触发的视图弹出，挂在 List 上锚点会飘
            .confirmationDialog(String(localized: "Clear History?"),
                                isPresented: $showsClearConfirm,
                                titleVisibility: .visible) {
                Button(String(localized: "Clear"), role: .destructive) { clearHistory() }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "This deletes every clip that isn't pinned to a Pinboard. It can't be undone."))
            }
        }
    }

    /// 只删没固定进 Pinboard 的条目，与 Mac 端「清空历史」的口径一致
    private func clearHistory() {
        let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.pinboard == nil })
        guard let items = try? model.modelContext.fetch(descriptor) else { return }
        for item in items {
            ImageMetadataCache.shared.invalidate(item)
            model.modelContext.delete(item)
        }
        try? model.modelContext.save()
        model.toast.show(String(localized: "History cleared"), symbol: "trash.fill")
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section {
            Link(destination: SettingsLinks.repository) {
                HStack(spacing: 12) {
                    SettingsIconTile(symbol: "chevron.left.forwardslash.chevron.right",
                                     color: SettingsTint.code)
                    Text(String(localized: "Open Source · GitHub"))
                        .font(.system(size: 17))
                        .foregroundStyle(PasterTheme.label)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 15))
                        .foregroundStyle(PasterTheme.labelTertiary)
                }
                .frame(height: 52)
            }
            .settingsRow()

            Link(destination: SettingsLinks.privacyPolicy) {
                HStack(spacing: 12) {
                    SettingsIconTile(symbol: "hand.raised.fill", color: SettingsTint.hand)
                    Text(String(localized: "Privacy"))
                        .font(.system(size: 17))
                        .foregroundStyle(PasterTheme.label)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 15))
                        .foregroundStyle(PasterTheme.labelTertiary)
                }
                .frame(height: 52)
            }
            .settingsRow()

            Button {
                route = .about
            } label: {
                SettingsRowLabel(symbol: "info.circle.fill",
                                 color: SettingsTint.info,
                                 title: String(localized: "About"),
                                 detail: AppInfo.versionDisplay,
                                 showsDisclosure: true)
            }
            .settingsRow()
        }
    }

    // MARK: - 截图参数

    private func applyDemoRouteOnce() {
        guard !didApplyDemoRoute else { return }
        didApplyDemoRoute = true
        switch model.demoRoute {
        case .settingsQuickSave: route = .quickSave
        case .settingsHowTo: route = .howToSave
        case .settingsPaste: route = .allowPaste
        default: break
        }
    }
}
