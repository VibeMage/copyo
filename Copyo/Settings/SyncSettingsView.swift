import AppKit
import CloudKit
import CopyoCore
import SwiftUI

// MARK: - 同步

/// 同步方式三选一。「文件夹」是快照同步，不传播删除；「iCloud」把数据库直接
/// 镜像到 CloudKit 私有数据库，删除会在所有设备生效。两种方式共用同一个数据库文件，
/// 但容器是启动时按方式建好的，所以改了方式要重启才换得过来。
///
/// 视觉照 v2 `Settings-sync.dc.html`：方式一行（图标砖 + 弹出菜单）+ 脚注，下面按方式接
/// 「同步文件夹」或「状态」一组。行为一条不改，只换壳。
struct SyncSettingsView: View {
    @AppStorage(SyncMode.defaultsKey) private var syncModeRaw = SyncMode.off.rawValue
    @AppStorage(CloudSyncStatus.containerErrorKey) private var containerError = ""
    @AppStorage(DataEraser.cloudWipePendingKey) private var cloudWipePending = false
    @AppStorage(DataEraser.icloudCopyMayRemainKey) private var icloudCopyMayRemain = false

    private var mode: SyncMode { SyncMode(rawValue: syncModeRaw) ?? .off }
    private var cloudKitActive: Bool { AppDelegate.shared?.cloudKitActive ?? false }

    var body: some View {
        SettingsPage {
            SettingsGroup {
                SettingsRow(title: Text("Sync Method"),
                            lead: { modeTile },
                            trailing: { modePicker })
            }
            SettingsFooter(modeDescription)

            switch mode {
            case .off:
                EmptyView()
            case .folder:
                FolderSyncSections()
            case .icloud:
                CloudKitSyncSections(needsRestartToStart: needsRestartToStart)
            }

            if cloudWipePending || icloudCopyMayRemain {
                erasureGroup
            }
        }
    }

    /// 砖形随方式变（与面板顶栏同步格同一套形状：iCloud 云 / 文件夹 folder，第八节第 13/14 条）；
    /// 关闭时用灰砖，免得一个蓝砖暗示「正在同步」
    @ViewBuilder
    private var modeTile: some View {
        switch mode {
        case .off: SettingsTile(hex: "#8E8E93", symbol: "arrow.triangle.2.circlepath")
        case .folder: SettingsTile(color: CopyoTheme.accent, symbol: "folder")
        case .icloud: SettingsTile(color: CopyoTheme.accent, symbol: "icloud")
        }
    }

    private var modePicker: some View {
        Picker(selection: $syncModeRaw) {
            Text("Off").tag(SyncMode.off.rawValue)
            Text("Shared Folder").tag(SyncMode.folder.rawValue)
            Text(verbatim: "iCloud").tag(SyncMode.icloud.rawValue)
        } label: {
            Text("Sync Method")
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 132)
        .onChange(of: syncModeRaw) { oldValue, newValue in
            // 文件夹同步的计时器立刻跟着起停；iCloud 那一路要等重启才换容器
            AppDelegate.shared?.syncService.updateActivation()
            // 从 iCloud 切走是唯一一个「界面已经改了、字节还在往外走」的方向。
            // 挂一行灰字等于默许它继续传，所以当场拦下：要么重启（真的停了），
            // 要么把选择器退回去（界面重新说真话）。绝不能停在
            // 「显示关闭 / 共享文件夹，而 CloudKit 还在上传」这个状态上。
            //
            // 切到共享文件夹也必须拦：SyncService 的注释明令两套同步不能同时跑，
            // 否则快照导入会把 iCloud 刚删掉的条目又写回来。
            guard oldValue == SyncMode.icloud.rawValue,
                  newValue != SyncMode.icloud.rawValue,
                  cloudKitActive else { return }
            // 让 SwiftUI 把这次更新走完再开模态循环
            DispatchQueue.main.async { confirmStopCloudKit() }
        }
    }

    /// 擦除相关的两条告警与方式无关：不管当前选的是什么都得看得到
    private var erasureGroup: some View {
        SettingsGroup {
            if cloudWipePending {
                // 唯一一种「删除真的会到 iCloud」的情况，也是唯一一种没法观测进度的情况。
                // 不挂这一行的话，确认框里那句「保持打开」用户根本没法照着做。
                SettingsRow(title: Text("Copyo is sending the deletion to your iCloud private database. Keep Copyo open and signed in to iCloud. Copyo cannot tell you when this has finished."),
                            lead: { SettingsStatusIcon(symbol: "arrow.triangle.2.circlepath.icloud", color: CopyoTheme.warning) },
                            trailing: { Button("Finish Erasing This Mac") { AppDelegate.shared?.finishErasing() } })
            }
            if cloudWipePending && icloudCopyMayRemain {
                SettingsSeparator()
            }
            if icloudCopyMayRemain {
                // 在 iCloud 同步关着的时候擦过一次：云端那份没动。用户一旦把 iCloud
                // 打开，整份历史有可能被导回来——这句话必须在选 iCloud 之前就看得到。
                SettingsRow(title: Text("Copyo erased this Mac while iCloud sync was off, so the iCloud copy was never removed. Turning iCloud sync on can bring those entries back.")) {
                    SettingsStatusIcon(symbol: "exclamationmark.triangle.fill", color: CopyoTheme.warning)
                }
            }
        }
    }

    /// 从 iCloud 切走时当场拦一下。用 NSAlert 而不是 SwiftUI 的 .alert：这里要在
    /// 动作里再弹第二个 alert（重启失败），SwiftUI 会把第二个吞掉，结果就是
    /// 「界面说关了、CloudKit 还在传、一个字都不说」——正是这次要修掉的那一格。
    private func confirmStopCloudKit() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Restart Copyo to stop iCloud sync?")
        alert.informativeText = cloudWipePending
            // 刚用「删除所有数据」擦过、删除还在往 iCloud 推：这一重启就等于把没推完的
            // 那部分永远留在云端。绝不能拿「什么都不会丢」糊过去——恰恰是删除会丢。
            ? String(localized: "Until Copyo restarts, this Mac keeps sending your clipboard history to your iCloud private database. Copyo is also still sending the entries you deleted; whatever has not been sent when Copyo restarts stays in iCloud.")
            : String(localized: "Until Copyo restarts, this Mac keeps sending your clipboard history to your iCloud private database. If you don’t restart now, Copyo keeps using iCloud sync for the rest of this session.")
        alert.addButton(withTitle: String(localized: "Restart Copyo"))
        alert.addButton(withTitle: String(localized: "Not Now"))
        // 关掉对话框不该顺手把应用退掉：Return 给「稍后」
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"
        NSApp.activate(ignoringOtherApps: true)
        let wantsRestart = alert.runModal() == .alertFirstButtonReturn
        if wantsRestart, AppDelegate.shared?.restartForSyncChange() == true { return }
        // 「稍后」，或者重启没派出去：把选择器退回 iCloud。界面上绝不允许出现
        // 「显示关闭，而 CloudKit 还在上传」。回退会再触发一次 onChange，
        // 但那一次的 oldValue 不是 icloud，拦截条件不成立，不会循环弹框。
        syncModeRaw = SyncMode.icloud.rawValue
        AppDelegate.shared?.syncService.updateActivation()
    }

    /// 容器是启动时按当时的方式建好的，CloudKit 镜像开不开只能靠重启换。
    ///
    /// 只在「选了 iCloud、这次会话还没挂上」这一个方向提示：一个字节都还没传出去，
    /// 等重启就行。反方向已经在 onChange 里当场拦下并回退，不存在需要挂提示的残留状态。
    ///
    /// 两个闸门：
    /// - 没签 entitlement 的构建重启多少次也挂不上（AppDelegate.swift:41），
    ///   那条说明归 CloudKitSyncSections，这里别再挂一行自相矛盾的；
    /// - 这次启动建容器失败时，CloudKitSyncSections 已经在说「修好上面的问题再重启
    ///   Copyo」，重启按钮跟着那句话走，这里不重复。
    private var needsRestartToStart: Bool {
        mode == .icloud
            && !cloudKitActive
            && CloudSyncStatus.hasCloudKitEntitlement
            && containerError.isEmpty
    }

    /// 方式说明。文件夹 / iCloud 两段按 v2 画板的文案；关闭沿用原句
    private var modeDescription: LocalizedStringKey {
        switch mode {
        case .off:
            "Your clipboard history stays on this Mac only."
        case .folder:
            "Saves your history as snapshots in a folder — iCloud Drive or any shared folder works. Deletions don’t sync to your other devices."
        case .icloud:
            "Mirrors your history straight to your iCloud. Deleting an entry removes it on every device."
        }
    }
}

// MARK: - iCloud 同步

/// iCloud 同步没有可调的参数，这一组只回答用户唯一关心的问题：现在到底同不同步。
/// 建容器和注册推送都发生在启动时，失败又完全静默，不显式说出来用户根本无从判断。
private struct CloudKitSyncSections: View {
    var needsRestartToStart: Bool
    @AppStorage(CloudSyncStatus.containerErrorKey) private var containerError = ""
    @AppStorage(CloudSyncStatus.pushErrorKey) private var pushError = ""
    @State private var accountStatus: CKAccountStatus?

    var body: some View {
        SettingsHeader("Status")
        SettingsGroup {
            if CloudSyncStatus.hasCloudKitEntitlement {
                SettingsRow(title: Text("iCloud Account"),
                            lead: { SettingsStatusIcon(symbol: accountSymbol, color: accountTint) },
                            trailing: {
                                HStack(spacing: 8) {
                                    SettingsValue(accountDescription)
                                    if accountStatus == .noAccount {
                                        Button("Open System Settings") { openAppleAccountSettings() }
                                    }
                                }
                            })
                    .task { accountStatus = await CloudSyncStatus.accountStatus() }
                    // 用户很可能是看到提示后切出去登录 iCloud 再切回来的，回前台重查一次
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                        Task { accountStatus = await CloudSyncStatus.accountStatus() }
                    }
            } else if containerError.isEmpty {
                // 这份构建没有 iCloud entitlement：账号状态查不得（查了会直接终止进程），
                // 启动时也没走 iCloud 那条路，所以在这里直接把原因说出来
                SettingsRow(title: Text("This copy of Copyo is not signed for iCloud sync.")) {
                    SettingsStatusIcon(symbol: "exclamationmark.icloud", color: CopyoTheme.warning)
                }
            }
            if !containerError.isEmpty {
                if CloudSyncStatus.hasCloudKitEntitlement {
                    SettingsSeparator()
                }
                // 这句话让用户重启，就得给他一个按得到的按钮。新建的 CloudKit 容器
                // 首次连接被拒是已知坑，重启一次就恢复。
                SettingsRow(title: Text("iCloud sync could not start: \(containerError)"),
                            subtitle: Text("Copyo is using the local database only, so nothing was lost. Fix the problem above and restart Copyo."),
                            lead: { SettingsStatusIcon(symbol: "exclamationmark.icloud", color: CopyoTheme.warning) },
                            trailing: { Button("Restart Copyo") { AppDelegate.shared?.restartForSyncChange() } })
            }
            if needsRestartToStart {
                SettingsSeparator()
                // 画板：「改了同步方式，重启后生效」+「重启 Copyo」，只在切换方式后出现
                SettingsRow(title: Text("Sync method changed — restart to apply"),
                            lead: { SettingsStatusIcon(symbol: "exclamationmark.icloud", color: CopyoTheme.warning) },
                            trailing: { Button("Restart Copyo") { AppDelegate.shared?.restartForSyncChange() } })
            }
        }
        if containerError.isEmpty && !pushError.isEmpty {
            SettingsFooter("Push notifications are unavailable on this Mac, so changes made on your other devices only arrive when Copyo starts.")
        }
    }

    /// 查询结果还没回来时用中性图标，别一进页面就先亮一个橙色警告吓人
    private var accountSymbol: String {
        switch accountStatus {
        case .available: "checkmark.icloud"
        case nil: "icloud"
        default: "exclamationmark.icloud"
        }
    }

    private var accountTint: Color {
        switch accountStatus {
        case .available: CopyoTheme.success
        case nil: CopyoTheme.labelSecondary
        default: CopyoTheme.warning
        }
    }

    /// 行右侧的短状态（画板「iCloud 账户 · 可用」）
    private var accountDescription: LocalizedStringKey {
        switch accountStatus {
        case .available: "Available"
        case .noAccount: "Not Signed In"
        case .restricted: "Restricted"
        case .temporarilyUnavailable: "Temporarily Unavailable"
        case nil: "Checking…"
        default: "Unknown"
        }
    }

    private func openAppleAccountSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - 文件夹同步 · 共用行

/// 「已同步 · 3 分钟前」+「立即同步」。相对时间每 30 秒重算一次，与同步周期对齐——
/// 否则这一行停在打开页面那一刻（7.5.4 同一个坑）。
private struct FolderSyncedRow: View {
    var lastSyncedAt: Double
    var syncNow: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            SettingsRow(title: lastSyncedAt > 0 ? Text("Synced") : Text("Not synced yet"),
                        // 图标形状跟同步方式走（第八节第 13/14 条，与面板顶栏同步格同一个 folder）；
                        // 成功绿只属于「已同步 · 时间」，一次都没同步过时用中性灰，别提前报喜
                        lead: { SettingsStatusIcon(symbol: "folder",
                                                   color: lastSyncedAt > 0 ? CopyoTheme.success : CopyoTheme.labelSecondary) },
                        trailing: {
                            HStack(spacing: 8) {
                                if lastSyncedAt > 0 {
                                    // 第八节第 39 条：相对时间四端共用 RelativeTime
                                    SettingsValue(verbatim: RelativeTime.string(for: Date(timeIntervalSince1970: lastSyncedAt),
                                                                                reference: context.date))
                                }
                                Button("Sync Now", action: syncNow)
                            }
                        })
        }
    }
}

/// 同步目录够不着时替换上一行（第八节第 16 条：「目录不存在」与「书签失效」共用这一行）
private struct FolderUnreachableRow: View {
    var reason: Text
    var chooseAgain: () -> Void

    var body: some View {
        SettingsRow(title: Text("Can’t access this folder"),
                    subtitle: reason,
                    // 画板 FOLDER_WARN_I：文件夹 + 感叹号，与面板顶栏 folderNeedsAttention 同一个画法
                    lead: {
                        SettingsStatusIcon(symbol: "folder", color: CopyoTheme.warning)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(CopyoTheme.warning)
                                    // 描一圈卡片底色，把角标从文件夹轮廓里抠出来
                                    .background(Circle().fill(CopyoTheme.bgCard).padding(1))
                                    .offset(x: -1, y: -3)
                                    .accessibilityHidden(true)
                            }
                    },
                    trailing: { Button("Choose Again…", action: chooseAgain) })
    }
}

/// 路径一行：等宽 11pt、`labelMeta`、单行截断（画板 `path_row`）
private struct FolderPathRow<Trailing: View>: View {
    var path: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let path {
                    Text(verbatim: path)
                } else {
                    Text("No folder selected")
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(path == nil ? CopyoTheme.labelTertiary : CopyoTheme.labelMeta)
            .lineLimit(1)
            // 路径头部最没信息量：截掉开头，保住末尾的文件夹名
            .truncationMode(.head)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(minHeight: 40)
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
        if folderPath == nil && !lostAccess {
            SettingsFooter("Choose a sync folder below to turn on syncing.")
        }
        SettingsHeader("Sync Folder")
        SettingsGroup {
            FolderPathRow(path: folderPath) {
                Button("Choose Folder…") { chooseFolder() }
            }
            if lostAccess {
                SettingsSeparator()
                FolderUnreachableRow(reason: Text("The folder was moved or renamed, or Copyo lost permission to it.")) {
                    chooseFolder()
                }
            } else if folderPath != nil {
                SettingsSeparator()
                FolderSyncedRow(lastSyncedAt: lastSyncedAt) {
                    AppDelegate.shared?.syncService.syncNow()
                    refreshFolderPath()
                }
            }
        }
        SettingsFooter("Any folder all of your devices share works — for example a folder inside iCloud Drive, or a company drive. Copyo keeps its files in its own subfolder and can only reach the folder you pick here.")
            .task { refreshFolderPath() }
            // 同步目录可能在应用不活跃时被删除/卸载，回到前台时重新确认一次，
            // 否则这一页会一直显示早已失效的旧路径。
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                refreshFolderPath()
            }
    }

    private func refreshFolderPath() {
        folderPath = SyncService.syncRoot.map { ($0.path as NSString).abbreviatingWithTildeInPath }
        // 记着「没权限」但书签又解析得通了（外置卷 / 网络盘重新挂上）：当场重试一轮。
        // 成功时 recordSuccess() 会清掉错误，这一行自己变回「已同步」；失败就维持原样，
        // 用户仍可「重新选择…」。只在失联状态下重试，稳态不会因为切回前台多同步一轮。
        if lostAccess, folderPath != nil {
            AppDelegate.shared?.syncService.syncNow()
        }
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
        folderPath = (url.path as NSString).abbreviatingWithTildeInPath
        AppDelegate.shared?.syncService.updateActivation()
    }
}

#else

/// 直接分发版：第八节第 16 条 (b) 收敛成与商店版同一套——只读路径 +「选择文件夹…」+「恢复默认位置」，
/// 不再给自由文本框（手输的路径打错一个字就静默失败，这一页从来说不清）。
///
/// 存储仍是 `syncFolderOverride`：空串 = 默认 iCloud Drive/Copyo；非空 = 那个目录本身就是同步目录
/// （语义见 `SyncService.syncRoot`，这里不改，老用户手填的路径照旧生效）。
/// 选择器存的是「所选目录/Copyo」而不是所选目录本身：与商店版 `prepareRoot(in: picked)` 同一种布局，
/// 两种构建选同一个共享目录才看得见彼此的快照，也不会把 device-*.json 摊进别人的目录。
private struct FolderSyncSections: View {
    @AppStorage("syncFolderOverride") private var syncFolderOverride = ""
    @AppStorage(SyncService.lastSyncedAtKey) private var lastSyncedAt = 0.0
    /// 目录够不够得着要碰文件系统，不在 body 里算；进页面、回前台、换目录时各查一次
    @State private var available = false

    var body: some View {
        SettingsHeader("Sync Folder")
        SettingsGroup {
            FolderPathRow(path: displayPath) {
                Button("Choose Folder…") { chooseFolder() }
            }
            SettingsSeparator()
            if available {
                FolderSyncedRow(lastSyncedAt: lastSyncedAt) {
                    AppDelegate.shared?.syncService.syncNow()
                    refreshAvailability()
                }
            } else {
                FolderUnreachableRow(reason: unreachableReason) {
                    chooseFolder()
                }
            }
        }
        HStack {
            Spacer()
            Button("Restore Default Location") {
                syncFolderOverride = ""
                applyFolderChange()
            }
            .disabled(syncFolderOverride.isEmpty)
        }
        .task { refreshAvailability() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAvailability()
        }
    }

    /// 自定义目录显示它本身；默认位置即使 iCloud Drive 没开也照样显示那条路径，
    /// 让用户知道「默认」指的是哪里
    private var displayPath: String {
        let url: URL
        if syncFolderOverride.isEmpty {
            let icloudDrive = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
            url = SyncFolderLayout.root(in: icloudDrive)
        } else {
            url = URL(fileURLWithPath: (syncFolderOverride as NSString).expandingTildeInPath, isDirectory: true)
        }
        return (url.path as NSString).abbreviatingWithTildeInPath
    }

    private var unreachableReason: Text {
        syncFolderOverride.isEmpty
            ? Text("iCloud Drive is turned off on this Mac. Turn it on in System Settings, or choose another folder.")
            : Text("The folder was moved or renamed, or Copyo lost permission to it.")
    }

    private func refreshAvailability() {
        available = SyncService.isAvailable
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Choose")
        panel.message = String(localized: "Choose a folder that all of your Macs can read and write.")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        syncFolderOverride = SyncFolderLayout.root(in: url).path
        applyFolderChange()
    }

    /// 换了目录：计时器跟着起停，并立刻同步一轮——否则「已同步 · 3 分钟前」说的还是旧目录。
    ///
    /// 计时器原本没跑时 `updateActivation()` → `start()` 已经同步过一轮，再补一轮就是在主线程上
    /// 连着导出导入两遍；计时器原本在跑时 `start()` 直接返回，才需要这里补。`lastSyncedAt`
    /// 变没变就是「刚才同步过没有」，不用去碰 SyncService 的私有计时器。
    private func applyFolderChange() {
        let service = AppDelegate.shared?.syncService
        let before = UserDefaults.standard.double(forKey: SyncService.lastSyncedAtKey)
        service?.updateActivation()
        if UserDefaults.standard.double(forKey: SyncService.lastSyncedAtKey) == before {
            service?.syncNow()
        }
        refreshAvailability()
    }
}

#endif
