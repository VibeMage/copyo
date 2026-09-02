import Foundation
import SwiftData

/// 统一的存储位置与容器工厂：各平台都从这里取 ModelContainer，
/// 保证同一份数据库文件在「本地 / 文件夹同步 / iCloud 同步」之间切换时不会换位置、不丢数据。
public enum PasterStore {
    /// CloudKit 私有数据库的容器标识
    public static let cloudKitContainerIdentifier = "iCloud.dev.vibemage.Paster"

    /// 默认数据库位置：~/Library/Application Support/Paster/Paster.store
    /// 顺带创建所在目录，调用方拿到的路径一定可写。
    public static func defaultStoreURL() throws -> URL {
        let appSupport = try FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true)
        let directory = appSupport.appendingPathComponent("Paster", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Paster.store")
    }

    /// 建立容器。`cloudKit` 为 true 时把这份存储镜像到 CloudKit 私有数据库；
    /// 存储 URL 两种情况完全一致，因此切换同步方式只是换一层镜像，本地数据原样保留。
    public static func makeContainer(url: URL, cloudKit: Bool) throws -> ModelContainer {
        let schema = Schema(PasterSchema.models)
        let configuration = cloudKit
            ? ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .private(cloudKitContainerIdentifier))
            : ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
