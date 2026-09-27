import AppKit
import UniformTypeIdentifiers

/// 按来源应用 bundle ID 提供图标与来源色（取应用图标的主色）。
@MainActor
enum AppIconProvider {
    private static var iconCache: [String: NSImage] = [:]
    /// iconCache 里哪些键存的是「找不到 App」时的通用 App 图标。
    /// 卡片显示可以接受这个替身，但 `headerColor` 绝不能拿它采样——采出来的正是第 30 条要消灭的假色
    private static var genericIconKeys: Set<String> = []
    /// 值是 Optional：「算过了、算不出」也要缓存，不然每次复制都对同一张图标重新采样
    private static var colorCache: [String: NSColor?] = [:]
    /// 「找不到 App」的负缓存（bundle ID → 查询时刻）。不永久缓存：App 可能在同一会话里刚装上 / 刚挪了位置；
    /// 但也不能每次都查——旧卡片视图在 body 里调 headerColor，每次重绘都会做一次同步 LaunchServices 查询
    private static var missingSince: [String: Date] = [:]
    private static let missingTTL: TimeInterval = 60

    static func icon(forBundleID bundleID: String?) -> NSImage {
        let key = bundleID ?? "?"
        if let cached = iconCache[key] { return cached }
        let icon: NSImage
        if let bundleID, let url = applicationURL(forBundleID: bundleID) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
            genericIconKeys.remove(key)
        } else {
            icon = NSWorkspace.shared.icon(for: UTType.application)
            genericIconKeys.insert(key)
        }
        iconCache[key] = icon
        return icon
    }

    /// 来源 App 的主题色；**取不到时返回 nil**，由显示层统一回退 `source.local` #8E8E93
    /// （design-spec 第八节第 30 条、7.4.7 (a)）。
    ///
    /// 以前这里有三种情况会烤一个具体色进条目：没有 bundle ID、找不到 App（两者都拿通用 App 图标去采样），
    /// 以及一个有色像素都采不到（落到板岩灰 `fallbackColor`）。结果是 iOS 的回退分支对 Mac 来的行永远走不到，
    /// 改回退色也修不了已经烤进库里的行。现在这三种一律返回 nil，存量行由 `SourceColorMigration` 改写。
    ///
    /// 「算不出」与「算得出但很灰」必须分开（第 30 条）：灰色图标（如「系统设置」）照样有采样结果，
    /// 提纯后是一个偏灰的真实颜色，照常返回——那是这个 App 的身份色，不是回退。
    ///
    /// `appURL`：采集时传正在运行的来源 App 的 `bundleURL`。那一刻 App 就在前台，位置是确定的，
    /// 不必查 LaunchServices，也不受负缓存影响——否则一个刚装上的 App 若在 60 秒内被显示层查过一次「找不到」，
    /// 第一次复制就会被存成 nil，而存进库的值以后不会再改。
    static func headerColor(forBundleID bundleID: String?, appURL: URL? = nil) -> NSColor? {
        guard let bundleID else { return nil }
        if let cached = colorCache[bundleID] { return cached }
        // 找不到 App 只进带时效的负缓存（见 missingSince）；过了时效再查，刚装上的 App 就能拿到真色。
        // 也不能走 `icon(forBundleID:)`：它找不到时给的是通用 App 图标，采出来的正是要消灭的那个假色。
        guard let url = appURL ?? applicationURL(forBundleID: bundleID) else { return nil }
        missingSince[bundleID] = nil
        // iconCache 里这个键若是之前「找不到」时塞进去的通用图标，不能拿来采样：此刻已经找到 App，
        // 按真实路径重新取图标并覆盖缓存，顺带让卡片上的图标也换成真的
        let icon: NSImage
        if let cached = iconCache[bundleID], !genericIconKeys.contains(bundleID) {
            icon = cached
        } else {
            icon = NSWorkspace.shared.icon(forFile: url.path)
            iconCache[bundleID] = icon
            genericIconKeys.remove(bundleID)
        }
        let color = dominantColor(of: icon)
        colorCache[bundleID] = color
        return color
    }

    /// LaunchServices 查询 + 负缓存。找到了就清掉负缓存记录
    private static func applicationURL(forBundleID bundleID: String) -> URL? {
        if let since = missingSince[bundleID], Date().timeIntervalSince(since) < missingTTL { return nil }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            missingSince[bundleID] = Date()
            return nil
        }
        missingSince[bundleID] = nil
        return url
    }

    /// 对图标做粗粒度像素采样求平均色，过滤透明与接近黑白的像素。
    /// 采样与提纯算法**不动**（design-spec 7.1：卡片淡染与角标底色都依赖它的输出分布）；
    /// 一个有色像素都采不到时返回 nil，即「算不出」。
    /// `SourceColorMigration` 里另有一份冻结的旧算法副本，专门用来还原旧版本烤进库里的值——改这里不用动那边。
    private static func dominantColor(of image: NSImage) -> NSColor? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        guard width > 0, height > 0 else { return nil }

        var red = 0.0, green = 0.0, blue = 0.0, count = 0.0
        let stepX = max(1, width / 12)
        let stepY = max(1, height / 12)
        for x in stride(from: 0, to: width, by: stepX) {
            for y in stride(from: 0, to: height, by: stepY) {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                      color.alphaComponent > 0.5 else { continue }
                let (r, g, b) = (color.redComponent, color.greenComponent, color.blueComponent)
                let brightness = (r + g + b) / 3
                // 跳过接近纯白/纯黑的背景像素，保留有色彩信息的部分
                if brightness > 0.92 || brightness < 0.08 { continue }
                red += r; green += g; blue += b; count += 1
            }
        }
        guard count > 0 else { return nil }
        let averaged = NSColor(srgbRed: red / count, green: green / count, blue: blue / count, alpha: 1)
        // 稍微加深并提高饱和度，让白色标题文字可读
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        averaged.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return NSColor(hue: hue,
                       saturation: min(1, saturation * 1.25 + 0.08),
                       brightness: min(0.75, max(0.35, brightness * 0.85)),
                       alpha: 1)
    }
}
