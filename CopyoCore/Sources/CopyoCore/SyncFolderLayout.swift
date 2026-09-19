import Foundation

/// 文件夹同步在共享目录里占的那一层子目录。
///
/// 1.0 时代叫 `Paster/`，改名后写进 `Copyo/`。同步目录是多台设备共用的，
/// 所以改名分两步走：本机把旧目录整体改名过来；同时仍然存在的 `Paster/`
/// 继续只读合并——没升级的那台 Mac 会把它重新建起来，那段窗口期里它写的快照不能丢。
public enum SyncFolderLayout {
    public static let directoryName = "Copyo"
    public static let legacyDirectoryName = "Paster"

    /// 纯计算：同步目录该在哪。没有任何副作用，设置页显示路径用这个。
    public static func root(in container: URL) -> URL {
        container.appendingPathComponent(directoryName, isDirectory: true)
    }

    /// 真要开始同步时调用：只有旧目录时把它整体改名过来，然后确保目录存在。
    /// 改名失败（云盘正在上传、目录被占用）就退回旧目录继续同步，
    /// 一次改名失败不该让同步链路断掉。
    @discardableResult
    public static func prepareRoot(in container: URL,
                                   fileManager: FileManager = .default) -> URL {
        let root = root(in: container)
        let legacy = container.appendingPathComponent(legacyDirectoryName, isDirectory: true)

        if !fileManager.fileExists(atPath: root.path),
           isDirectory(legacy, fileManager: fileManager) {
            do {
                try fileManager.moveItem(at: legacy, to: root)
            } catch {
                return legacy
            }
        }
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// 改名之后仍然存在的旧目录，只用来读。
    public static func legacyRoot(in container: URL,
                                  fileManager: FileManager = .default) -> URL? {
        let legacy = container.appendingPathComponent(legacyDirectoryName, isDirectory: true)
        guard isDirectory(legacy, fileManager: fileManager),
              legacy != root(in: container) else { return nil }
        return legacy
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
        return isDirectory.boolValue
    }
}
