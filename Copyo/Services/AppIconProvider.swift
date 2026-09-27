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

    /// 卡片底行的图标走后台查（7.5.5）：同一 bundle ID 去重、并发有上限、卡片离屏时排队中的撤掉
    private static let iconLoads = BackgroundLoadQueue<String, IconLookup>(maxConcurrent: 3)
    /// 是否已经向 `IconPrerender.onNewScales` 登记了 `rescale`
    private static var observesNewScales = false
    /// 接上像素密度不同的屏之后重取的轮次：接连换屏时只认最后一轮
    private static var rescaleRound = 0

    /// 后台查询的结果。`queried` 为 false 表示负缓存期内没去查 LaunchServices，回来时不刷新 missingSince
    private struct IconLookup: Sendable {
        let icon: TransferredImage
        let found: Bool
        let queried: Bool
    }

    /// 只查内存。view body 里只许调这个（design-spec 7.5.5：LaunchServices 查询与 `NSWorkspace.icon` 移出 body）；
    /// 未命中返回 nil，由调用方先空着图标位，同时 `await icon(forBundleID:)`
    static func cachedIcon(forBundleID bundleID: String) -> NSImage? {
        iconCache[bundleID]
    }

    /// 后台查 LaunchServices、取图标，结果进 iconCache。同一 bundle ID 的并发请求只查一次。
    /// 找不到 App 时给通用 App 图标并记进 genericIconKeys——与 headerColor 共用同一套语义：
    /// 卡片可以显示这个替身，headerColor 绝不拿它采样
    static func icon(forBundleID bundleID: String) async -> NSImage? {
        if let cached = iconCache[bundleID] { return cached }
        if !observesNewScales {
            observesNewScales = true
            IconPrerender.onNewScales { rescale(to: $0) }
        }
        // 负缓存要在主线程上判：missingSince 只在主线程上读写。屏幕像素密度同理，在主线程上读好带过去
        let skipLookup = isKnownMissing(bundleID)
        let scales = IconPrerender.currentScales()
        let lookup = await iconLoads.load(bundleID) {
            lookUpIcon(bundleID: bundleID, skipLookup: skipLookup, scales: scales)
        } commit: { lookup in
            commit(lookup, for: bundleID)
        }
        return iconCache[bundleID] ?? lookup?.icon.image
    }

    /// 预热用：结果留在 iconCache 里，调用方不要图
    static func warm(bundleID: String) async {
        _ = await icon(forBundleID: bundleID)
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
        if isKnownMissing(bundleID) { return nil }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            missingSince[bundleID] = Date()
            return nil
        }
        missingSince[bundleID] = nil
        return url
    }

    private static func isKnownMissing(_ bundleID: String) -> Bool {
        guard let since = missingSince[bundleID] else { return false }
        return Date().timeIntervalSince(since) < missingTTL
    }

    /// 后台线程上跑：LaunchServices 找 App、IconServices 取图标，再按卡片底行的 20pt 先栅格化一次
    /// （见 `IconPrerender`：不然这一步会留到主线程第一次画它时才做）。只碰 Sendable 的入参，
    /// 取到的 NSImage 整体移交给主线程，这一侧不再留引用
    nonisolated private static func lookUpIcon(bundleID: String, skipLookup: Bool, scales: [CGFloat]) -> IconLookup {
        let found: Bool
        let icon: NSImage
        if !skipLookup, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            found = true
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            found = false
            icon = NSWorkspace.shared.icon(for: UTType.application)
        }
        IconPrerender.warm(icon, pointSizes: [ClipCardMetrics.sourceIconSize], scales: scales)
        return IconLookup(icon: TransferredImage(image: icon), found: found, queried: !skipLookup)
    }

    /// 接上像素密度不同的屏之后（`IconPrerender.onNewScales`），把缓存里的图标在后台按新的一组重取一份。
    /// 取的是新实例：已经交给主线程的那张，后台不能再碰（见 `TransferredImage`）。一轮是一段串行的后台活，
    /// 回来后只做同类替换——真图标换真图标、通用替身换替身：这期间替身已被真图标顶掉的不动，
    /// 这次找不到 App 的也不拿替身去顶真图标。卡片 body 里是 `cachedIcon` 优先，下一次重算就用上新的这张
    private static func rescale(to scales: [CGFloat]) {
        rescaleRound &+= 1
        let round = rescaleRound
        let entries = iconCache.keys.map { (bundleID: $0, generic: genericIconKeys.contains($0)) }
        guard !entries.isEmpty else { return }
        Task {
            let lookups = await BackgroundWork.run {
                entries.map { entry in
                    (entry.bundleID, lookUpIcon(bundleID: entry.bundleID, skipLookup: entry.generic, scales: scales))
                }
            }
            guard round == rescaleRound else { return }
            for (bundleID, lookup) in lookups
            where iconCache[bundleID] != nil && genericIconKeys.contains(bundleID) != lookup.found {
                iconCache[bundleID] = lookup.icon.image
            }
        }
    }

    /// 回到主线程写缓存，与 headerColor 的语义对齐：真图标总是压过通用替身，通用替身绝不压过真图标。
    /// 在途期间采集那边的 headerColor 可能已经按运行中 App 的位置放进了真图标——那时这边找不到也不能覆盖它
    private static func commit(_ lookup: IconLookup, for bundleID: String) {
        if lookup.found {
            missingSince[bundleID] = nil
            if iconCache[bundleID] == nil || genericIconKeys.contains(bundleID) {
                iconCache[bundleID] = lookup.icon.image
                genericIconKeys.remove(bundleID)
            }
        } else {
            let hasRealIcon = iconCache[bundleID] != nil && !genericIconKeys.contains(bundleID)
            // 在途期间已经有了真图标：这边的「找不到」已经过时，既不动图标，也不记负缓存
            guard !hasRealIcon else { return }
            if lookup.queried { missingSince[bundleID] = Date() }
            if iconCache[bundleID] == nil {
                iconCache[bundleID] = lookup.icon.image
                genericIconKeys.insert(bundleID)
            }
        }
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
