import CopyoCore
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
    @AppStorage(IOSSettings.Key.spotlightIndexing, store: IOSSettings.defaults)
    private var spotlightIndexing = false

    @State private var route: SettingsRoute?
    @State private var showsClearConfirm = false
    /// 截图参数只在第一次出现时生效，从二级页返回后不能再自动推一次
    @State private var didApplyDemoRoute = false

    /// 设计 3.8 的 52 行高与同步子行的 44 都不在样式表上，按各自行内文字的样式缩：
    /// 主行是 17pt（`.body`），同步子行是 15pt（`.subheadline`）。
    /// 这里跟 `SettingsRowLabel` 一样要用 `minHeight`——写死高度会把折行的标题切掉。
    /// 开关那两行的标题要跟开关抢宽度，**默认字号就会折**：英文
    /// 「Read Clipboard Automatically」折两行，这一行是 56 而不是 52，属实，别按截图改回去。
    @ScaledMetric(relativeTo: .body) private var rowMinHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .subheadline) private var statusRowMinHeight: CGFloat = 44

    enum SettingsRoute: Hashable {
        case quickSave
        case howToSave
        case allowPaste
        case keyboard
        case about
    }

    var body: some View {
        List {
            syncSection
            clipboardSection
            searchSection
            clearSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CopyoTheme.bgGrouped)
        .navigationTitle(String(localized: "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .quickSave: QuickSaveGuideScreen()
            case .howToSave: HowToSaveScreen()
            case .allowPaste: AllowPasteGuideScreen()
            case .keyboard: KeyboardGuideScreen()
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
                        .font(.body)
                        .foregroundStyle(CopyoTheme.label)
                }
                .padding(.vertical, 8)
                .frame(minHeight: rowMinHeight)
            }
            .tint(CopyoTheme.switchOn)
            .settingsRow()
            // 容器是在 App 启动时按这个开关建的，运行中改不了，只能提示重开
            .onChange(of: cloudSyncEnabled) { _, _ in
                model.toast.show(String(localized: "Takes effect after you reopen Copyo"),
                                 symbol: "arrow.clockwise")
            }

            HStack(spacing: 8) {
                Text(String(localized: "Status"))
                    .font(.subheadline)
                    .foregroundStyle(CopyoTheme.label)
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    Image(systemName: syncSymbol)
                        .font(.subheadline)
                        // 图标与右边的文字说的是同一件事，读屏再念一遍符号名是纯噪音
                        .accessibilityHidden(true)
                    Text(syncStatusText)
                        .font(.subheadline)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        // 「未登录 iCloud」这类原因本来就顶着两行的上限，放大后必然溢出；
                        // 缩到 0.8 仍读得出问题出在哪，截断了就等于没提示
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(CopyoTheme.labelSecondary)
            }
            // 本来就是 minHeight，文字折行时自己长高；只把 44 换成跟着字号缩的值
            .frame(minHeight: statusRowMinHeight)
            // 这一行不在 Button 里，系统不会替它合并：不合的话读屏要停三次才说完
            // 「状态」「同步图标」「已同步 · 5 分钟前」
            .accessibilityElement(children: .combine)
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
                                 title: String(localized: "How Copyo Saves Clips"),
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
                                 detailColor: CopyoTheme.warning,
                                 showsDisclosure: true)
            }
            .settingsRow()

            Toggle(isOn: $autoReadOnForeground) {
                HStack(spacing: 12) {
                    SettingsIconTile(symbol: "arrow.clockwise", color: SettingsTint.autoRead)
                    Text(String(localized: "Read Clipboard Automatically"))
                        .font(.body)
                        .foregroundStyle(CopyoTheme.label)
                }
                .padding(.vertical, 8)
                .frame(minHeight: rowMinHeight)
            }
            .tint(CopyoTheme.switchOn)
            .settingsRow()

            // 只有包里真的带着键盘扩展时才出现这一行。iOS 首个版本（1.1.0）不随包发布键盘
            // （见 docs/ios-plan.md 3.6），那一版的包里没有 `CopyoKeyboard.appex`，
            // 而这一行会一步步教用户去「添加新键盘」里找一个根本不存在的东西。
            //
            // 判据取的是**包里到底有没有**，不是一个手动开关：开关要靠人记得翻，
            // 而忘了翻的两种表现都很难被发现——发键盘时忘了打开，用户找不到入口；
            // 不发时忘了关掉，设置里多一行教人做不到的事。按 appex 判断则是自洽的，
            // 哪天把 embed 挂回去，这一行自己就回来了。
            if KeyboardExtension.isBundled {
                Button {
                    route = .keyboard
                } label: {
                // 设计 04 这一格的右值是「未启用」。iOS 既不提供读取「键盘是否已添加」的 API，
                // 也不提供读取「允许完全访问」的 API（键盘进程自己只能靠 `hasFullAccess`
                // 反推，主应用连那个都拿不到），所以「未启用」在这里只能是编的——
                // 已经启用的用户每次进设置都会看见一句假的。
                // 与上面「允许从其他 App 粘贴」同一条先例：右值改成说「这事在系统设置里」。
                // 那一格是橙色因为它确实还需要用户去处理；这一格读不出状态，
                // 橙色就成了对所有人不分青红皂白的催促，所以走默认的次级色。
                SettingsRowLabel(symbol: "keyboard.fill",
                                 color: SettingsTint.keyboard,
                                 title: String(localized: "Copyo Keyboard"),
                                 detail: String(localized: "In iOS Settings"),
                                 showsDisclosure: true)
                }
                .settingsRow()
            }

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
            Text(String(localized: "With this off, Copyo won't read the clipboard when it opens — use the banner at the top of History to paste and save by hand."))
        }
    }

    // MARK: - 系统搜索

    /// 单独成一节，不并进「剪贴板」：那一节讲的是 Copyo 怎么**收内容**，这一项决定的是
    /// 内容会**出现在哪里**。混在一起的话用户会当成又一个采集选项顺手打开，不会停下来读说明。
    ///
    /// 说明文案必须把验证码和密码点名说出来——这是整条功能里唯一能让用户判断要不要开的信息，
    /// 写成「在系统搜索中显示条目以便更快找到内容」就是在回避它。
    private var searchSection: some View {
        Section {
            Toggle(isOn: $spotlightIndexing) {
                HStack(spacing: 12) {
                    SettingsIconTile(symbol: "magnifyingglass", color: SettingsTint.spotlight)
                    Text(String(localized: "Show Clips in System Search"))
                        .font(.body)
                        .foregroundStyle(CopyoTheme.label)
                }
                .padding(.vertical, 8)
                .frame(minHeight: rowMinHeight)
            }
            .tint(CopyoTheme.switchOn)
            .settingsRow()
            .onChange(of: spotlightIndexing) { _, enabled in
                model.applySpotlightIndexing(enabled)
            }
        } header: {
            Text(String(localized: "System Search"))
        } footer: {
            Text(String(localized: "Off by default. Turn it on and your clips become searchable from the Home Screen, the Lock Screen and Siri Suggestions — including the verification codes, passwords and private messages that end up in a clipboard history. Turning it off deletes everything Copyo put in the index."))
        }
    }

    // MARK: - 清空历史

    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                showsClearConfirm = true
            } label: {
                Text(String(localized: "Clear History"))
                    .font(.body)
                    .foregroundStyle(CopyoTheme.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // 默认档 20 的行高 + 28 内距 = 48 < 52，这一行仍是 52
                    .padding(.vertical, 14)
                    .frame(minHeight: rowMinHeight)
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
        // 标识符要在 delete 之前收好：save 之后 `persistentModelID` 取不回来，
        // 系统索引里这一整批就成了点不开的孤儿，要等 30 天的过期兜底才消失
        let indexed = items.map(\.persistentModelID)
        for item in items {
            ImageMetadataCache.shared.invalidate(item)
            model.modelContext.delete(item)
        }
        try? model.modelContext.save()
        SpotlightIndexer.remove(indexed)
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
                        .font(.body)
                        .foregroundStyle(CopyoTheme.label)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.subheadline)
                        .foregroundStyle(CopyoTheme.labelTertiary)
                        // 「会跳出去」这件事由 Link 自带的 link 特征说，读屏不必再念符号名
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 8)
                .frame(minHeight: rowMinHeight)
                .accessibilityElement(children: .combine)
            }
            .settingsRow()

            Link(destination: SettingsLinks.privacyPolicy) {
                HStack(spacing: 12) {
                    SettingsIconTile(symbol: "hand.raised.fill", color: SettingsTint.hand)
                    Text(String(localized: "Privacy"))
                        .font(.body)
                        .foregroundStyle(CopyoTheme.label)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.subheadline)
                        .foregroundStyle(CopyoTheme.labelTertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 8)
                .frame(minHeight: rowMinHeight)
                .accessibilityElement(children: .combine)
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
        case .settingsKeyboard: route = .keyboard
        default: break
        }
    }
}
