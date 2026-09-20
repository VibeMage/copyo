import Foundation
import CopyoCore

/// 主应用与两个扩展共享容器的标识符，以及三个进程都要读写的那几个设置。
///
/// 真值在 CopyoCore 里，这里只是三个进程共用的简称，避免各处硬编码字符串。
/// 主应用侧的读取端是 `IOSSettings`（用 `@AppStorage` 订阅同一个 suite），
/// **键名必须与 `IOSSettings.Key` 逐字一致**——写错一个字母的表现是「扩展写了、主应用读不到」，
/// 不报错也不崩溃，只是功能静默失效，所以这里刻意把键名重新声明一遍并加注释，而不是靠记忆。
public enum CopyoAppGroup {
    public static let identifier = CopyoStore.appGroupIdentifier

    /// 三个进程共用的 UserDefaults suite。取不到 suite（App Group capability 没配好）时退回 standard：
    /// 至少本进程内部读写自洽，不会因为一个 nil 让整个扩展跑不起来。
    public static let defaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard

    public enum Key {
        /// 未固定条目的上限，0 = 不限（与 Mac 端口径一致）
        public static let historyLimit = "historyLimit"
        /// 一键保存请求的时间戳（timeIntervalSince1970），由控件 / 操作按钮写入，主应用激活时消费
        public static let pendingQuickSaveAt = "pendingQuickSaveAt"
        /// 右滑固定与「保存到默认 Pinboard」的目标板名（PersistentIdentifier 不能进 UserDefaults）
        public static let defaultPinboardName = "defaultPinboardName"
        /// Core Spotlight 索引开关。**默认关**，理由见 `SpotlightIndexer`
        public static let spotlightIndexing = "spotlightIndexing"
        /// 小组件「点按复制」要复制的那一条，存编码后的 `PersistentIdentifier`，见 `CopyClipIntent`
        public static let pendingCopyClipID = "pendingCopyClipID"
        /// 上一行那次按下的时刻（timeIntervalSince1970）。与一键保存同理要有效期，见 `QuickSaveCoordinator`
        public static let pendingCopyAt = "pendingCopyAt"
        /// 主应用抄给小组件的 iCloud 同步状态（`WidgetSyncState.rawValue`）
        public static let widgetSyncState = "widgetSyncState"
        /// 上一行那份快照写下的时刻（timeIntervalSince1970），过期就当作未知
        public static let widgetSyncStateAt = "widgetSyncStateAt"
    }

    /// 小组件「点按复制」留下的那条请求
    public struct CopyRequest: Sendable {
        /// 编码后的 `PersistentIdentifier`，用 `SpotlightIndexer.modelID(from:)` 解回来
        public let clipID: String
        public let requestedAt: Date
    }

    /// 主应用在首启动时 register 了默认值 500；扩展进程有自己的一份 registration domain，
    /// 拿不到那份默认值，所以这里显式回落到同一个 500，避免扩展保存时按「不限」处理。
    public static var historyLimit: Int {
        defaults.object(forKey: Key.historyLimit) as? Int ?? 500
    }

    public static var defaultPinboardName: String? {
        let name = defaults.string(forKey: Key.defaultPinboardName)
        return (name?.isEmpty ?? true) ? nil : name
    }

    /// 与 `historyLimit` 同理：扩展进程有自己的 registration domain，拿不到主应用注册的默认值，
    /// 所以这里显式重述一遍 false。**方向不能搞反**——读错的表现是扩展在用户压根没开开关的
    /// 情况下，把验证码和密码写进系统搜索索引，而且没有任何报错。
    public static var spotlightIndexingEnabled: Bool {
        defaults.object(forKey: Key.spotlightIndexing) as? Bool ?? false
    }

    /// 通道 C：控件 / 操作按钮 / 锁屏按下时留一个时间戳。
    /// 扩展进程读不到剪贴板，真正的读取由主应用回到前台后完成。
    public static func markQuickSaveRequested(at date: Date = Date()) {
        defaults.set(date.timeIntervalSince1970, forKey: Key.pendingQuickSaveAt)
    }

    // MARK: - 小组件点按复制

    /// 小组件按下某一条时留下请求。与 `markQuickSaveRequested` 同一条路子：扩展进程干不了那件事，
    /// 真正的复制交给回到前台的主应用。决定性的理由是主应用那条路会顺手 `markSeen()` ——
    /// 少了它，这条内容每被复制一次就在历史里往上跳一格，完整推演见 `CopyClipIntent`。
    public static func markCopyRequested(clipID: String, at date: Date = Date()) {
        defaults.set(clipID, forKey: Key.pendingCopyClipID)
        defaults.set(date.timeIntervalSince1970, forKey: Key.pendingCopyAt)
    }

    /// 待办的复制请求。**读到之后要自己 `clearPendingCopyRequest()`**，
    /// 有效期判断在应用侧的 `QuickSaveCoordinator`，与一键保存共用同一个窗口。
    ///
    /// 这里不走 `IOSSettings`（一键保存那条路的读取端）是因为 `-demoData` 下
    /// `IOSSettings.defaults` 被换成了一次性的演示 suite，而小组件进程写的始终是真实 suite，
    /// 两边根本不是同一份值。演示模式下这条请求一律不消费，由 `AppModel` 那道 `useDemoData` 挡住。
    public static var pendingCopyRequest: CopyRequest? {
        guard let clipID = defaults.string(forKey: Key.pendingCopyClipID), !clipID.isEmpty else { return nil }
        let timestamp = defaults.double(forKey: Key.pendingCopyAt)
        guard timestamp > 0 else { return nil }
        return CopyRequest(clipID: clipID, requestedAt: Date(timeIntervalSince1970: timestamp))
    }

    public static func clearPendingCopyRequest() {
        defaults.removeObject(forKey: Key.pendingCopyClipID)
        defaults.removeObject(forKey: Key.pendingCopyAt)
    }

    // MARK: - 给小组件看的同步状态

    /// 小组件进程**问不出** iCloud 同步状态：`CopyoWidgets.entitlements` 里只有 App Group，
    /// 没有 iCloud 容器也没有 `aps-environment`，`CKContainer` 在那边一句都问不了。
    /// 所以由主应用把自己那枚同步胶囊的状态抄进来，小组件直接读。
    ///
    /// **带有效期**：分享扩展与 `SaveContentIntent` 写库时主应用没有运行，只刷新时间线、抄不了状态，
    /// 小组件那时读到的是上一次主应用留下的快照。超过 `syncStateValidity` 就返回 nil，
    /// 视图据此干脆不显示胶囊——宁可不说，也不要把一个几天前的「已同步」摆在用户眼前。
    public static var widgetSyncState: WidgetSyncState? {
        get {
            let timestamp = defaults.double(forKey: Key.widgetSyncStateAt)
            guard timestamp > 0,
                  Date().timeIntervalSince(Date(timeIntervalSince1970: timestamp)) < syncStateValidity,
                  let raw = defaults.string(forKey: Key.widgetSyncState) else { return nil }
            return WidgetSyncState(rawValue: raw)
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: Key.widgetSyncState)
                defaults.removeObject(forKey: Key.widgetSyncStateAt)
                return
            }
            defaults.set(newValue.rawValue, forKey: Key.widgetSyncState)
            defaults.set(Date().timeIntervalSince1970, forKey: Key.widgetSyncStateAt)
        }
    }

    /// 24 小时。这不是「多久会变」而是「多久之后不再敢替主应用说话」：
    /// 用户可能好几天不打开主应用（小组件存在的意义就在于此），期间退出 iCloud、
    /// 关掉同步开关这一侧都看不见。超过一天就空着那一格，比摆一句可能已经不成立的「已同步」诚实。
    private static let syncStateValidity: TimeInterval = 24 * 60 * 60
}

/// 小组件能显示的同步状态，三态与主应用右上角那枚胶囊一一对应。
///
/// 单独声明一个值类型而不是复用 `SyncStatus`：那个带着 `SyncOffReason` 和上次同步时刻，
/// 定义在 `CopyoIOS/Services/SyncStatusMonitor.swift` 里，小组件 target 编译不到；
/// 而小组件那一行只有一个词的位置，三态之外的细节本来也摆不下。
public enum WidgetSyncState: String, Sendable {
    case synced
    case syncing
    case off
}
