import AppKit
import UniformTypeIdentifiers

/// 文件卡的类型图标：只按扩展名取 `NSWorkspace.shared.icon(for: UTType)`，**从不读文件**（第八节第 44 条）。
///
/// 旧卡片在 view body 里 `icon(forFile:)`，每次重绘都同步碰一次磁盘；沙盒下别的 App 的路径又常常读不到，
/// 读不到时拿回的是通用图标、还白白付了一次 I/O（7.5.5）。按扩展名取图标只查 LaunchServices 的类型表，
/// 与文件是否存在、是否可读无关，同一扩展名只查一次。
@MainActor
enum FileTypeIconCache {
    private static var cache: [String: NSImage] = [:]

    static func icon(forPath path: String?) -> NSImage {
        let ext = ((path ?? "") as NSString).pathExtension.lowercased()
        if let cached = cache[ext] { return cached }
        let type = ext.isEmpty ? nil : UTType(filenameExtension: ext)
        let icon = NSWorkspace.shared.icon(for: type ?? .data)
        cache[ext] = icon
        return icon
    }
}
