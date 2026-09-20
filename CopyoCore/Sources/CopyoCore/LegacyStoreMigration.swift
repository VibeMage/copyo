import Foundation

/// 把 Paster 时代的数据库搬到改名后的位置。
///
/// 1.0 上架时应用叫 Paster，数据库是 `<容器>/Paster/Paster.store`。改名成 Copyo 之后
/// 目录名与文件名都跟着换，老用户升级时必须把旧库搬过来——不搬就等于一升级历史全空。
///
/// 搬迁要连 `.Paster_SUPPORT` 一起改名：SwiftData（Core Data）把 `externalStorage`
/// 的图片放在 store 同级的 `.<store 主文件名>_SUPPORT/` 里，这个目录名是从 store 文件名
/// 推导出来的。只改 store 文件名不改它，等于把所有图片藏起来。
public enum LegacyStoreMigration {
    public static let legacyDirectoryName = "Paster"
    public static let legacyStoreName = "Paster.store"
    public static let directoryName = "Copyo"
    public static let storeName = "Copyo.store"

    public enum Outcome: Equatable {
        /// 没有旧库，全新安装
        case nothingToDo
        /// 新位置已经有库了，之前搬过
        case alreadyMigrated
        /// 这次搬成功了
        case migrated
        /// 搬不动。调用方必须继续用返回的旧路径打开数据库：
        /// 目录名难看好过让用户的历史消失。
        case failed(legacyStoreURL: URL)
    }

    /// 旧目录里某个条目搬过去之后该叫什么。
    ///
    /// 只认两种名字：store 三件套（`Paster.store` / `-wal` / `-shm`）与外部数据目录
    /// `.Paster_SUPPORT`。用户自己丢进去的文件原名搬过去，不猜。
    public static func migratedName(for legacyName: String) -> String {
        if legacyName == ".\(legacyStoreBaseName)_SUPPORT" {
            return ".\(storeBaseName)_SUPPORT"
        }
        if legacyName.hasPrefix(legacyStoreName) {
            return storeName + legacyName.dropFirst(legacyStoreName.count)
        }
        return legacyName
    }

    /// `container` 是存放这两个目录的父目录：macOS 上是 Application Support。
    @discardableResult
    public static func migrateIfNeeded(in container: URL,
                                       fileManager: FileManager = .default) -> Outcome {
        let directory = container.appendingPathComponent(directoryName, isDirectory: true)
        let legacyDirectory = container.appendingPathComponent(legacyDirectoryName, isDirectory: true)
        let storeURL = directory.appendingPathComponent(storeName)
        let legacyStoreURL = legacyDirectory.appendingPathComponent(legacyStoreName)

        if fileManager.fileExists(atPath: storeURL.path) { return .alreadyMigrated }
        guard fileManager.fileExists(atPath: legacyStoreURL.path) else { return .nothingToDo }

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let entries = try fileManager.contentsOfDirectory(atPath: legacyDirectory.path)
            for entry in entries {
                let destination = directory.appendingPathComponent(migratedName(for: entry))
                // 目标已存在说明新库已经被写过一轮，这时候覆盖等于用旧数据盖掉新数据。
                guard !fileManager.fileExists(atPath: destination.path) else { continue }
                try fileManager.moveItem(at: legacyDirectory.appendingPathComponent(entry),
                                         to: destination)
            }
            guard fileManager.fileExists(atPath: storeURL.path) else {
                return .failed(legacyStoreURL: legacyStoreURL)
            }
            // 旧目录空了才删：还剩东西说明上面跳过了条目，留着让人能自己看一眼
            if let leftovers = try? fileManager.contentsOfDirectory(atPath: legacyDirectory.path),
               leftovers.isEmpty {
                try? fileManager.removeItem(at: legacyDirectory)
            }
            return .migrated
        } catch {
            return .failed(legacyStoreURL: legacyStoreURL)
        }
    }

    private static var storeBaseName: String {
        (storeName as NSString).deletingPathExtension
    }

    private static var legacyStoreBaseName: String {
        (legacyStoreName as NSString).deletingPathExtension
    }
}
