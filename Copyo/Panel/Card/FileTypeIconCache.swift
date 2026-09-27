import AppKit
import UniformTypeIdentifiers

/// 文件卡的类型图标：只按扩展名取 `NSWorkspace.shared.icon(for: UTType)`，**从不读文件**（第八节第 44 条）。
///
/// 旧卡片在 view body 里 `icon(forFile:)`，每次重绘都同步碰一次磁盘；沙盒下别的 App 的路径又常常读不到，
/// 读不到时拿回的是通用图标、还白白付了一次 I/O（7.5.5）。按扩展名取图标只查 LaunchServices 的类型表，
/// 与文件是否存在、是否可读无关，同一扩展名只查一次。
///
/// 这次类型表查询也挪出了 body（7.5.18 对 7.5.5 的拍板：「`NSWorkspace.icon` 移出 view body，异步 + 缓存」）：
/// body 里只调 `cachedIcon`，未命中先空着图标位，`icon(forExtension:)` 在后台查完、按两处显示尺寸先栅格化过
/// （见 `IconPrerender`）再换上。
@MainActor
enum FileTypeIconCache {
    /// 文件卡叠放方块上的类型图标（第 44 条）
    static let cardIconSize: CGFloat = 22
    /// 预览浮层文件列表每行的类型图标（第 2 条）
    static let previewIconSize: CGFloat = 28

    private static var cache: [String: NSImage] = [:]
    private static let loads = BackgroundLoadQueue<String, TransferredImage>(maxConcurrent: 2)
    /// 是否已经向 `IconPrerender.onNewScales` 登记了 `rescale`
    private static var observesNewScales = false
    /// 接上像素密度不同的屏之后重取的轮次：接连换屏时只认最后一轮
    private static var rescaleRound = 0
    /// 同一扩展名的图标卡片与预览都要用，两档尺寸都先栅格化
    private static let pointSizes = [cardIconSize, previewIconSize]

    /// 缓存键：小写扩展名，没有扩展名的是空串
    static func extensionKey(forPath path: String?) -> String {
        ((path ?? "") as NSString).pathExtension.lowercased()
    }

    /// 只查内存，body 里用
    static func cachedIcon(forExtension ext: String) -> NSImage? {
        cache[ext]
    }

    static func icon(forExtension ext: String) async -> NSImage? {
        if let cached = cache[ext] { return cached }
        if !observesNewScales {
            observesNewScales = true
            IconPrerender.onNewScales { rescale(to: $0) }
        }
        // 尺寸与像素密度在主线程上取好带过去
        let pointSizes = pointSizes
        let scales = IconPrerender.currentScales()
        let loaded = await loads.load(ext) {
            loadIcon(forExtension: ext, pointSizes: pointSizes, scales: scales)
        } commit: { loaded in
            cache[ext] = loaded.image
        }
        return cache[ext] ?? loaded?.image
    }

    /// 接上像素密度不同的屏之后（`IconPrerender.onNewScales`），把缓存里的图标在后台按新的一组重取一份、
    /// 回主线程整批换掉。取的是新实例，已经交给主线程的那张后台不再碰（见 `TransferredImage`）
    private static func rescale(to scales: [CGFloat]) {
        rescaleRound &+= 1
        let round = rescaleRound
        let extensions = Array(cache.keys)
        guard !extensions.isEmpty else { return }
        let pointSizes = pointSizes
        Task {
            let icons = await BackgroundWork.run {
                extensions.map { ext in (ext, loadIcon(forExtension: ext, pointSizes: pointSizes, scales: scales)) }
            }
            guard round == rescaleRound else { return }
            for (ext, icon) in icons { cache[ext] = icon.image }
        }
    }

    /// 后台线程上跑：查类型表取图标，按各档尺寸与像素密度先栅格化（`IconPrerender`），整体移交给主线程
    nonisolated private static func loadIcon(forExtension ext: String,
                                             pointSizes: [CGFloat], scales: [CGFloat]) -> TransferredImage {
        let type = ext.isEmpty ? nil : UTType(filenameExtension: ext)
        let icon = NSWorkspace.shared.icon(for: type ?? .data)
        IconPrerender.warm(icon, pointSizes: pointSizes, scales: scales)
        return TransferredImage(image: icon)
    }

    /// 预热用：结果留在缓存里，调用方不要图
    static func warm(extension ext: String) async {
        _ = await icon(forExtension: ext)
    }
}
