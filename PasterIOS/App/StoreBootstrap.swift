import Foundation
import PasterCore
import SwiftData

/// 建库的结果：容器本身，加上「这次到底有没有挂上 CloudKit、没挂是因为什么」。
///
/// 后面这两项必须和容器一起产出：SwiftData 在没有 entitlement / 没登录 iCloud 时
/// 照样能把 CloudKit 容器建出来，只是一个字节都传不出去，事后再问是问不出来的。
struct StoreBootstrap {
    let container: ModelContainer
    let cloudKitActive: Bool
    let offReason: SyncOffReason?

    /// 按启动参数与用户设置建库。
    /// 顺序：内存演示库 → App Group 共享库（可能带 CloudKit）→ 同一文件的本地库 → 内存库兜底。
    /// 最后一档是为了「数据库文件损坏时应用仍能打开」，Mac 端也是同样的退化策略。
    static func make(launch: LaunchOptions = .current) -> StoreBootstrap {
        if launch.useDemoData {
            return StoreBootstrap(container: makeInMemoryContainer(),
                                  cloudKitActive: false,
                                  offReason: .localOnlyLaunch)
        }

        let wantsCloud = IOSSettings.cloudSyncEnabled && !launch.localOnly
        let hasEntitlement = CloudKitEntitlement.isPresent
        let useCloud = wantsCloud && hasEntitlement

        let deniedReason: SyncOffReason? = if launch.localOnly {
            .localOnlyLaunch
        } else if !IOSSettings.cloudSyncEnabled {
            .disabledInSettings
        } else if !hasEntitlement {
            .noEntitlement
        } else {
            nil
        }

        do {
            let url = try PasterStore.appGroupStoreURL()
            do {
                let container = try PasterStore.makeContainer(url: url, cloudKit: useCloud)
                return StoreBootstrap(container: container,
                                      cloudKitActive: useCloud,
                                      offReason: useCloud ? nil : deniedReason)
            } catch where useCloud {
                // CloudKit 镜像建不起来：退回同一个文件的本地容器，历史一条不少，
                // 只是这次启动不同步。绝不能因此崩溃，更不能落到内存库把用户数据藏起来。
                let container = try PasterStore.makeContainer(url: url, cloudKit: false)
                return StoreBootstrap(container: container,
                                      cloudKitActive: false,
                                      offReason: .failed(error.localizedDescription))
            }
        } catch {
            return StoreBootstrap(container: makeInMemoryContainer(),
                                  cloudKitActive: false,
                                  offReason: .failed(error.localizedDescription))
        }
    }

    private static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema(PasterSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // 内存容器只依赖 schema 本身，建不起来说明模型定义就有问题，早崩比带病运行好
        return try! ModelContainer(for: schema, configurations: configuration)
    }
}
