import CloudKit
import CoreData
import Foundation
import Observation
import CopyoCore

/// 右上角胶囊的状态。`synced` 带上次成功同步的时间（拿不到就是 nil）。
///
/// `idle` 是「iCloud 开着，但这次启动还没见到一次成功的导入 / 导出」：原来这一段直接说「已同步」——
/// 只要账号查询回来是可用就算——可那时一个字节都还没传过（Codex 复盘 A）。维护者选了中性的「iCloud」，
/// 第一次真正成功之后才换成「已同步」，冷启动通常几秒内就会换。
enum SyncStatus: Equatable {
    case idle
    case synced(Date?)
    case syncing
    case off(SyncOffReason)

    var isOff: Bool { if case .off = self { return true }; return false }
}

enum SyncOffReason: Equatable {
    /// 用户在设置里关了 iCloud 同步
    case disabledInSettings
    /// 这份构建没有 iCloud 容器 entitlement（未签名的本地构建、描述文件没授权）
    case noEntitlement
    /// 设备没登录 iCloud
    case noAccount
    /// 账号受限（家长控制、MDM）
    case accountRestricted
    /// iCloud 暂时不可用或查不出来（服务端、网络、刚改过账号）。**不是**让用户去登录——
    /// 原来所有非「可用」一律并成「请登录 iCloud」，临时故障恢复之后还一直这么说（Codex 复盘第二轮 #3）
    case accountTemporarilyUnavailable
    /// 本次启动带了 -localOnly
    case localOnlyLaunch
    /// 容器建起来了但同步报错
    case failed(String)

    var message: String {
        switch self {
        case .disabledInSettings: String(localized: "iCloud sync is turned off")
        case .noEntitlement: String(localized: "This build is not signed for iCloud sync")
        case .noAccount: String(localized: "Sign in to iCloud to sync with your Mac")
        case .accountRestricted: String(localized: "iCloud is restricted on this device")
        case .accountTemporarilyUnavailable: String(localized: "iCloud is temporarily unavailable. Copyo will try again.")
        case .localOnlyLaunch: String(localized: "Running in local-only mode")
        case .failed(let detail): detail
        }
    }
}

/// iCloud 同步状态的唯一来源。
///
/// 数据有三处：建容器时是否真的挂上了 CloudKit（启动时就定了）、CKContainer 的账号状态、
/// 以及 NSPersistentCloudKitContainer 广播的 setup / 导入 / 导出事件。
///
/// **所有回调只改「事实」，胶囊状态一律由 `recompute()` 按优先级推出来**——原来是每个回调各自
/// 直接写 `status`，于是（TestFlight 真机 + Codex 复盘，2026-09-27）：
/// - 账号查询回来是可用就写「已同步」，一次都没同步过也这么说；晚回来的查询还能盖掉真实结果
/// - 只有一个「待亮同步中」的任务：A 开始、B 开始、A 结束 → 显示已同步，而 B 还在传
/// - setup 失败被整个跳过；账号不可用之后，延迟亮起的「同步中」还能把它盖掉
/// - 本地保存之后 CloudKit 通常很快安排一次导出（时机由系统定），胶囊跟着「同步中 → 已同步」硬切一轮
@MainActor
@Observable
final class SyncStatusMonitor {

    private(set) var status: SyncStatus

    /// 本次启动的容器是不是真挂了 CloudKit 镜像。为假时任何事件都不该把状态改成「同步中」。
    let cloudKitActive: Bool

    // MARK: 事实

    private enum Account: Equatable { case unknown, available, unavailable(SyncOffReason) }

    @ObservationIgnored private let offReason: SyncOffReason?
    @ObservationIgnored private var account: Account = .unknown
    /// 进行中的导入 / 导出（键：store + 事件标识）。空 ≠ 云端没有排队的工作，只是「此刻没看到在传」
    @ObservationIgnored private var activeEvents: Set<String> = []
    /// 按「store + 类型」记最近一次失败：导出成功不该抹掉一个还没恢复的导入故障；
    /// setup 成功清掉 setup 的失败（原来 setup 失败之后没有任何清除路径，重试成功了胶囊还一直报错）
    @ObservationIgnored private var failures: [String: String] = [:]
    @ObservationIgnored private var lastSyncedAt: Date?
    /// 一段传输已经持续够久、**值得**显示同步中（不等于胶囊此刻真的在显示：账号或失败可能压着它）
    @ObservationIgnored private var busyWanted = false
    /// 胶囊**真正**进入「同步中」的时刻。最短展示从这里算，而不是从「想显示」那一刻——
    /// 被账号故障压着的那段不算数（Codex 复盘第二轮 #2）。单调时钟，改系统时间不影响
    @ObservationIgnored private var busyVisibleSince: ContinuousClock.Instant?
    @ObservationIgnored private var busyTask: Task<Void, Never>?
    /// 账号查询的代次：前台频繁激活会并发发出好几次，只认最后发出的那一次
    @ObservationIgnored private var accountQueryGeneration = 0
    @ObservationIgnored private var eventObserver: NSObjectProtocol?
    @ObservationIgnored private var accountObserver: NSObjectProtocol?

    /// 一段传输持续超过它才亮「同步中」：CloudKit 启动后、本地保存之后常有一闪而过的导入导出，
    /// 每次都亮就是胶囊来回跳。从**一段忙碌的开始**算，不因为中途又来了新事件而一直往后推
    private static let busyDelay: Duration = .milliseconds(1500)
    /// 亮起之后至少停留这么久再回到空闲，免得刚亮就灭
    private static let busyMinimum: Duration = .milliseconds(800)

    init(cloudKitActive: Bool, offReason: SyncOffReason? = nil) {
        self.cloudKitActive = cloudKitActive
        self.offReason = offReason ?? (cloudKitActive ? nil : .disabledInSettings)
        status = .idle
        recompute()
    }

    /// 截图 / 演示用：固定显示设计稿上的那一态，不查账号、不听事件（`cloudKitActive` 为假，
    /// `start()` 与 `refreshAccountStatus()` 都会直接返回）。模拟器没登录 iCloud，
    /// 不钉住的话每张截图右上角都是「未同步」，与设计 01 的「已同步」对不上
    init(demoStatus: SyncStatus) {
        cloudKitActive = false
        offReason = nil
        status = demoStatus
    }

    deinit {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
        }
        if let accountObserver {
            NotificationCenter.default.removeObserver(accountObserver)
        }
    }

    func start() {
        guard cloudKitActive, eventObserver == nil else { return }
        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // 通知本身在主队列上派发，闭包里再跳一次 MainActor 会让状态慢一帧
            MainActor.assumeIsolated {
                self?.handle(notification)
            }
        }
        // 账号变化（登录、登出、临时故障恢复）时系统会发这个通知，Apple 对 temporarilyUnavailable
        // 的建议就是等它再查——只靠启动与回前台查，用户停在页面上时临时故障会一直挂着
        accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.refreshAccountStatus() }
            }
        }
        Task { await refreshAccountStatus() }
    }

    /// 账号状态是静默失败的重灾区：没登录 iCloud 时容器照建、事件照发，就是一个字节都传不出去
    func refreshAccountStatus() async {
        guard cloudKitActive, CloudKitEntitlement.isPresent else { return }
        accountQueryGeneration += 1
        let generation = accountQueryGeneration
        let accountStatus = await CloudKitEntitlement.accountStatus()
        // 晚回来的旧查询不能盖掉新查询的结果
        guard generation == accountQueryGeneration else { return }
        account = switch accountStatus {
        case .available: .available
        case .noAccount: .unavailable(.noAccount)
        case .restricted: .unavailable(.accountRestricted)
        case .temporarilyUnavailable: .unavailable(.accountTemporarilyUnavailable)
        // 查询本身失败（`accountStatus` 出错时回的就是它）：什么也没学到。**保留已知的结论**——
        // 已经确认没登录的，不能因为这次没查成就退回到旧的「已同步」（Codex 复盘第三轮 #1）
        default: account
        }
        recompute()
    }

    private func handle(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
        let key = "\(event.storeIdentifier)|\(event.identifier.uuidString)"

        let failureKey = "\(event.storeIdentifier)|\(event.type.rawValue)"
        if event.type == .setup {
            // setup 成功只说明容器起来了，不算「已同步」；但它要清掉之前那次 setup 失败。
            // 失败必须显示出来（原来整个跳过）
            guard event.endDate != nil else { return }
            failures[failureKey] = event.succeeded ? nil : failureMessage(event)
            recompute()
            return
        }
        guard event.type == .import || event.type == .export else { return }

        if event.endDate == nil {
            let wasIdle = activeEvents.isEmpty
            activeEvents.insert(key)
            if wasIdle { scheduleBusy() }
            return
        }
        activeEvents.remove(key)
        if event.succeeded {
            failures[failureKey] = nil
            lastSyncedAt = event.endDate
            // 传输成功了，账号却还记着临时不可用：说明早就恢复了，重新问一次
            if account == .unavailable(.accountTemporarilyUnavailable) {
                Task { await refreshAccountStatus() }
            }
        } else {
            failures[failureKey] = failureMessage(event)
        }
        if activeEvents.isEmpty { settleBusy() } else { recompute() }
    }

    // MARK: 「同步中」的亮与灭

    private func scheduleBusy() {
        busyTask?.cancel()
        busyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.busyDelay)
            guard !Task.isCancelled, let self, !self.activeEvents.isEmpty else { return }
            self.busyWanted = true
            self.recompute()
        }
    }

    /// 这一段忙碌结束：还没真正亮过就直接落定；亮过了就停够最短时间再灭。
    /// **只有要回到「已同步 / iCloud」时才等**——结束于失败时 `recompute()` 按优先级立刻显示失败，
    /// 不能让「最短展示」把错误拖后（Codex 复盘第二轮 #2）
    private func settleBusy() {
        busyTask?.cancel()
        busyWanted = false
        guard let since = busyVisibleSince, failures.isEmpty else {
            recompute()
            return
        }
        let remaining = Self.busyMinimum - (ContinuousClock.now - since)
        guard remaining > .zero else {
            recompute()
            return
        }
        // 最短展示期间胶囊保持「同步中」：暂时把「想显示」留着，到点再撤
        busyWanted = true
        busyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: remaining)
            guard !Task.isCancelled, let self, self.activeEvents.isEmpty else { return }
            self.busyWanted = false
            self.recompute()
        }
    }

    // MARK: 推导

    /// 优先级：本次启动就定了的关闭原因 > 账号 > 失败 > 同步中 > 已同步 > iCloud（中性）
    private func recompute() {
        // 故障抢占且已经没有传输在跑：那段为「最短展示」留着的同步中作废。不作废的话故障一恢复，
        // 残留的 `busyWanted` 会让胶囊重新亮起一个早已结束的同步中，闪一下再灭（Codex 复盘第三轮 #3）
        let faulted = offReason != nil || failures.isEmpty == false
            || { if case .unavailable = account { true } else { false } }()
        if faulted, activeEvents.isEmpty, busyWanted {
            busyWanted = false
            busyTask?.cancel()
            busyTask = nil
        }
        let next: SyncStatus
        if let offReason {
            next = .off(offReason)
        } else if case .unavailable(let reason) = account {
            next = .off(reason)
        } else if let failure = failures.sorted(by: { $0.key < $1.key }).first?.value {
            next = .off(.failed(failure))
        } else if busyWanted {
            next = .syncing
        } else if let lastSyncedAt {
            next = .synced(lastSyncedAt)
        } else {
            next = .idle
        }
        // 记下「真正显示同步中」的起点，最短展示从这里算
        if case .syncing = next {
            if busyVisibleSince == nil { busyVisibleSince = .now }
        } else {
            busyVisibleSince = nil
        }
        if next != status { status = next }
        onStatusChange?(status)
    }

    /// 推导出来的状态每变一次回调一次（去重由接收方做）。AppModel 用它把结果抄给小组件——
    /// 「iCloud → 已同步」发生在任意时刻，不一定碰上回前台或本机保存（Codex 复盘第二轮 #7）
    @ObservationIgnored var onStatusChange: ((SyncStatus) -> Void)?

    private func failureMessage(_ event: NSPersistentCloudKitContainer.Event) -> String {
        event.error?.localizedDescription ?? String(localized: "iCloud sync failed")
    }

}

/// iCloud entitlement 与账号状态的查询。**故意放在 MainActor 之外**：
/// `StoreBootstrap` 在 App.init 里就要问它，那时还没有 MainActor 上下文。
enum CloudKitEntitlement {

    /// 这份构建有没有 iCloud 容器 entitlement。
    ///
    /// 必须先问过它：没有 entitlement 时 `CKContainer(identifier:)` 会直接抛 ObjC 异常终止进程，
    /// 而 SwiftData 反而会安安静静建出一个永远不同步的容器，光靠 catch 发现不了。
    ///
    /// Mac 端 `CloudSyncStatus` 用的是 `SecTaskCopyValueForEntitlement`，**iOS SDK 没有这套 API**。
    ///
    /// **真机上一律为真，只有模拟器才读描述文件。** 原来的写法是真机也读 embedded.mobileprovision，
    /// 前提是「签名过的 App 都带着它」——这对开发包和本地导出的 .ipa 成立，但 **App Store 与
    /// TestFlight 分发前 Apple 会重签名并删掉这个文件**。于是审核员和全部用户装到的包里它恒为假，
    /// iCloud 同步永远开不起来，设置页还显示「这份构建未签名」。本地能测到的包全都带着文件，
    /// 所以这个缺陷在任何一次本地验证里都不会出现。
    ///
    /// 真机上判「有」是安全的：没签名的包装不上真机，而 iCloud 容器 entitlement 是写死在
    /// `CopyoIOS.entitlements` 里、每个签名配置都带的（`scripts/build-appstore-ios.sh` 出包时逐项核验）。
    /// 会崩的只有「未签名的模拟器构建」这一种情况，所以只在模拟器上保守地去问描述文件。
    static let isPresent: Bool = {
        #if !targetEnvironment(simulator)
        return true
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let entitlements = profileEntitlements(from: data),
              let identifiers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String]
        else { return false }
        return identifiers.contains(CopyoStore.cloudKitContainerIdentifier)
        #endif
    }()

    /// 描述文件是 CMS 签名包，里面裹着一段 XML plist。没有公开 API 能解，只能按标记切出来。
    private static func profileEntitlements(from data: Data) -> [String: Any]? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), options: .backwards)
        else { return nil }
        let plistData = data[start.lowerBound..<end.upperBound]
        guard let profile = try? PropertyListSerialization.propertyList(from: plistData,
                                                                       format: nil) as? [String: Any]
        else { return nil }
        return profile["Entitlements"] as? [String: Any]
    }

    static func accountStatus() async -> CKAccountStatus {
        guard isPresent else { return .couldNotDetermine }
        return await withCheckedContinuation { continuation in
            CKContainer(identifier: CopyoStore.cloudKitContainerIdentifier).accountStatus { status, _ in
                continuation.resume(returning: status)
            }
        }
    }
}
