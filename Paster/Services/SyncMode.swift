import CloudKit
import Foundation
import PasterCore
import Security

/// 同步方式三选一，存在 UserDefaults 的 `syncMode` 键里。
///
/// - `off`：只存本机
/// - `folder`：文件夹快照同步（iCloud Drive 或任意共享目录），不传播删除
/// - `icloud`：SwiftData 直接镜像到 CloudKit 私有数据库，删除会在所有设备生效
enum SyncMode: String, CaseIterable {
    case off
    case folder
    case icloud

    static let defaultsKey = "syncMode"

    /// 老版本只有「文件夹同步」一种，开关键是 `icloudSync`。
    /// 首次读到没有 syncMode 的配置时按老开关落位：开着的归到 folder，其余归到 off。
    /// 写回一次之后就再也不看老键，用户后续的选择不会被覆盖。
    @discardableResult
    static func migrateIfNeeded() -> SyncMode {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: defaultsKey), let mode = SyncMode(rawValue: raw) {
            return mode
        }
        let migrated: SyncMode = defaults.bool(forKey: "icloudSync") ? .folder : .off
        defaults.set(migrated.rawValue, forKey: defaultsKey)
        return migrated
    }

    /// 当前同步方式；配置缺失时先走一次迁移
    static var current: SyncMode {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
              let mode = SyncMode(rawValue: raw) else {
            return migrateIfNeeded()
        }
        return mode
    }
}

/// iCloud 同步的运行状态。建容器和注册推送都发生在启动时，
/// 设置页要在很久之后才显示，所以把结果记进 UserDefaults 传递。
enum CloudSyncStatus {
    /// 容器创建失败的原因，空串表示这次启动一切正常
    static let containerErrorKey = "cloudSyncContainerError"
    /// 远程推送注册失败的原因，空串表示注册成功或没有注册
    static let pushErrorKey = "cloudSyncPushError"

    static func record(containerError: String) {
        UserDefaults.standard.set(containerError, forKey: containerErrorKey)
    }

    static func record(pushError: String) {
        UserDefaults.standard.set(pushError, forKey: pushErrorKey)
    }

    /// 一次成功的启动要把上次的错误清干净，否则设置页会一直挂着早就修好的问题
    static func clearErrors() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: containerErrorKey)?.isEmpty == false {
            defaults.set("", forKey: containerErrorKey)
        }
        if defaults.string(forKey: pushErrorKey)?.isEmpty == false {
            defaults.set("", forKey: pushErrorKey)
        }
    }

    /// 这份构建的签名里到底有没有 iCloud 容器 entitlement。
    ///
    /// 两处都必须先问过它：
    /// - `CKContainer(identifier:)` 在没有该 entitlement 时会直接终止进程，不是抛错；
    /// - SwiftData 建 CloudKit 容器在这种情况下反而不报错，只是安静地建出一个
    ///   永远不同步的库，光靠 catch 发现不了。
    /// 未签名的本地构建、以及描述文件没授权这个容器的分发包都会落在这里。
    static var hasCloudKitEntitlement: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                  task,
                  "com.apple.developer.icloud-container-identifiers" as CFString,
                  nil
              ),
              let identifiers = value as? [String] else { return false }
        return identifiers.contains(PasterStore.cloudKitContainerIdentifier)
    }

    /// 查询 iCloud 账号状态：没登录账号时 CloudKit 一个字节都传不出去，
    /// 而这种失败是完全静默的，必须在设置页里直说。
    static func accountStatus() async -> CKAccountStatus {
        // 没有 entitlement 时建 CKContainer 会让进程直接死掉，这里是最后一道拦截
        guard hasCloudKitEntitlement else { return .couldNotDetermine }
        return await withCheckedContinuation { continuation in
            CKContainer(identifier: PasterStore.cloudKitContainerIdentifier).accountStatus { status, _ in
                continuation.resume(returning: status)
            }
        }
    }
}
