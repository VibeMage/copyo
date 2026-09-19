import Foundation
import SwiftData

/// 统一的存储位置与容器工厂：各平台都从这里取 ModelContainer，
/// 保证同一份数据库文件在「本地 / 文件夹同步 / iCloud 同步」之间切换时不会换位置、不丢数据。
public enum CopyoStore {
    /// CloudKit 私有数据库的容器标识
    public static let cloudKitContainerIdentifier = "iCloud.dev.vibemage.Copyo"

    /// iOS 主应用与各扩展共享容器的 App Group 标识
    public static let appGroupIdentifier = "group.dev.vibemage.Copyo"

    public enum StoreError: LocalizedError {
        /// 取不到 App Group 容器：capability 没开，或几个 target 里的标识写得不一样
        case appGroupUnavailable(String)

        public var errorDescription: String? {
            switch self {
            case .appGroupUnavailable(let identifier):
                return "App Group container \(identifier) is unavailable. Enable the App Groups capability and use the same identifier in the app and every extension."
            }
        }
    }

    /// 默认数据库位置：~/Library/Application Support/Copyo/Copyo.store
    /// 顺带创建所在目录，调用方拿到的路径一定可写。
    public static func defaultStoreURL() throws -> URL {
        let appSupport = try FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true)
        return try storeURL(in: appSupport)
    }

    /// 在给定的容器目录里解析数据库位置，顺手把 Paster 时代的旧库搬过来。
    /// 搬不动时返回旧路径继续用——目录名难看好过让用户的历史消失。
    public static func storeURL(in container: URL,
                               fileManager: FileManager = .default) throws -> URL {
        if case .failed(let legacyStoreURL) = LegacyStoreMigration.migrateIfNeeded(in: container,
                                                                                  fileManager: fileManager) {
            return legacyStoreURL
        }
        let directory = container.appendingPathComponent(LegacyStoreMigration.directoryName,
                                                        isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(LegacyStoreMigration.storeName)
    }

    /// App Group 容器内的数据库位置：<group container>/Copyo/Copyo.store
    /// iOS 主应用、分享扩展、Intent 都要打开同一份库，只能放在共享容器里；
    /// 沙盒里的 Application Support 是每个进程各自一份，扩展写进去主应用看不到。
    ///
    /// 这里不做旧库搬迁：App Group 标识本身从 `group.dev.vibemage.Paster` 换成了
    /// `group.dev.vibemage.Copyo`，容器是全新的，而没有旧 entitlement 也读不到旧容器。
    /// iOS 版从未发布，历史只存在于开发机上。
    public static func appGroupStoreURL(groupIdentifier: String = appGroupIdentifier) throws -> URL {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else {
            throw StoreError.appGroupUnavailable(groupIdentifier)
        }
        let directory = container.appendingPathComponent(LegacyStoreMigration.directoryName,
                                                        isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(LegacyStoreMigration.storeName)
    }

    /// 建立容器。`cloudKit` 为 true 时把这份存储镜像到 CloudKit 私有数据库；
    /// 存储 URL 两种情况完全一致，因此切换同步方式只是换一层镜像，本地数据原样保留。
    public static func makeContainer(url: URL, cloudKit: Bool) throws -> ModelContainer {
        let schema = Schema(CopyoSchema.models)
        let configuration = cloudKit
            ? ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .private(cloudKitContainerIdentifier))
            : ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
