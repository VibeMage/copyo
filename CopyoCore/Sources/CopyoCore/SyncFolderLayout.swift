import Foundation

/// 文件夹同步在共享目录里占的那一层子目录。
///
/// 用户可能选的是 iCloud Drive 根目录或公司共享盘，所以快照和 assets/ 统一收在
/// 这一层子目录里，不直接摊在用户选的目录上。
public enum SyncFolderLayout {
    public static let directoryName = "Copyo"

    /// 纯计算：同步目录该在哪。没有任何副作用，设置页显示路径用这个。
    public static func root(in container: URL) -> URL {
        container.appendingPathComponent(directoryName, isDirectory: true)
    }

    /// 真要开始同步时调用：确保目录存在。
    @discardableResult
    public static func prepareRoot(in container: URL,
                                   fileManager: FileManager = .default) -> URL {
        let root = root(in: container)
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
