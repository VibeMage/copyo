import CloudKit
import CoreData
import Foundation
import Observation
import PasterCore

/// 右上角胶囊的三态。`synced` 带上次成功同步的时间（拿不到就是 nil）。
enum SyncStatus: Equatable {
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
    /// 设备没登录 iCloud，或账号受限
    case noAccount
    /// 本次启动带了 -localOnly
    case localOnlyLaunch
    /// 容器建起来了但同步报错
    case failed(String)

    var message: String {
        switch self {
        case .disabledInSettings: String(localized: "iCloud sync is turned off")
        case .noEntitlement: String(localized: "This build is not signed for iCloud sync")
        case .noAccount: String(localized: "Sign in to iCloud to sync with your Mac")
        case .localOnlyLaunch: String(localized: "Running in local-only mode")
        case .failed(let detail): detail
        }
    }
}

/// iCloud 同步状态的唯一来源。
///
/// 数据有三处：建容器时是否真的挂上了 CloudKit（启动时就定了）、CKContainer 的账号状态、
/// 以及 NSPersistentCloudKitContainer 广播的导入 / 导出事件。三者缺一都会让胶囊显示错。
@MainActor
@Observable
final class SyncStatusMonitor {

    private(set) var status: SyncStatus

    /// 本次启动的容器是不是真挂了 CloudKit 镜像。为假时任何事件都不该把状态改成「同步中」。
    let cloudKitActive: Bool

    @ObservationIgnored private var eventObserver: NSObjectProtocol?
    @ObservationIgnored private var lastSyncedAt: Date?
    /// 账号状态第一次查回来之前不能说「已同步」，见 init 的注释
    @ObservationIgnored private var didResolveAccount = false

    init(cloudKitActive: Bool, offReason: SyncOffReason? = nil) {
        self.cloudKitActive = cloudKitActive
        if let offReason {
            status = .off(offReason)
        } else if cloudKitActive {
            // 容器挂上镜像 ≠ 真的能同步：设备没登录 iCloud 时也照样挂得上。
            // 账号查询是异步的（`start()` 里那次），在它回来之前先说「同步中」——
            // 直接给「已同步」会在冷启动的几百毫秒到几秒里显示一个假状态。
            status = .syncing
        } else {
            status = .off(.disabledInSettings)
        }
    }

    deinit {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
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
        Task { await refreshAccountStatus() }
    }

    /// 账号状态是静默失败的重灾区：没登录 iCloud 时容器照建、事件照发，就是一个字节都传不出去
    func refreshAccountStatus() async {
        guard cloudKitActive, CloudKitEntitlement.isPresent else { return }
        let accountStatus = await CloudKitEntitlement.accountStatus()
        switch accountStatus {
        case .available:
            if !didResolveAccount {
                // 第一次落到真实状态：把 init 里的「同步中」换成「已同步」
                didResolveAccount = true
                status = .synced(lastSyncedAt)
            } else if case .off(.noAccount) = status {
                status = .synced(lastSyncedAt)
            }
        default:
            didResolveAccount = true
            status = .off(.noAccount)
        }
    }

    private func handle(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
        // setup 事件只说明容器起来了，不代表有数据在动，不改胶囊
        guard event.type == .import || event.type == .export else { return }

        if event.endDate == nil {
            status = .syncing
            return
        }
        if event.succeeded {
            lastSyncedAt = event.endDate
            status = .synced(event.endDate)
        } else {
            status = .off(.failed(event.error?.localizedDescription
                                  ?? String(localized: "iCloud sync failed")))
        }
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
    /// Mac 端 `CloudSyncStatus` 用的是 `SecTaskCopyValueForEntitlement`，**iOS SDK 没有这套 API**，
    /// 所以这里改成读描述文件：签名过的 App（开发、TestFlight、App Store）都带 embedded.mobileprovision，
    /// 未签名的模拟器构建没有——判成「没有 entitlement」正好是我们要的保守结果。
    static let isPresent: Bool = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let entitlements = profileEntitlements(from: data),
              let identifiers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String]
        else { return false }
        return identifiers.contains(PasterStore.cloudKitContainerIdentifier)
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
            CKContainer(identifier: PasterStore.cloudKitContainerIdentifier).accountStatus { status, _ in
                continuation.resume(returning: status)
            }
        }
    }
}
