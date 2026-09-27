import AppKit
import CopyoCore
import SwiftData
import UniformTypeIdentifiers

/// 把旧版本烤进库里的「回退来源色」改写为 nil（design-spec 第八节第 30 条、7.4.7 (a)）。
///
/// 1.2 之前 `AppIconProvider.headerColor` 取不到来源色时也会写一个具体 hex，来源有两个：
/// - 板岩灰 `fallbackColor = NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.58)`——Generic RGB，
///   转 sRGB 后是 `#7E8EA5`，不是分量直接 ×255 的 `#6B7A94`（design-spec 2.5 末尾的实测）；
/// - 没有 bundle ID / 找不到 App 时拿**通用 App 图标**采出来的主色。
///
/// 两个值都在运行时现算、不写死（第 30 条拍板「迁移时现算」）：前者是色彩空间换算，写死等于再抄一遍实测；
/// 后者取决于这台机器上系统自带的通用图标，换个系统版本就不是同一个值。
/// 按**精确值**匹配：只认这两个串，一个真实 App 的偏灰身份色哪怕很接近也不动。
@MainActor
enum SourceColorMigration {
    /// 迁移完成的标记。只在保存成功后才写，失败了下次启动再来一遍（改写是幂等的）
    private static let doneKey = "sourceColorNilMigrationDone"

    /// 启动时调用一次（AppDelegate，`-demoData` 下跳过）
    static func runIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }
        // 取不到 / 存不进去都不标记完成，下次启动再来一遍（改写是幂等的）
        guard rewriteLegacyRows(in: context) else { return }
        UserDefaults.standard.set(true, forKey: doneKey)
    }

    /// 不看 done 标记、直接按值改写一遍，返回是否成功（没有要改的行也算成功）。
    ///
    /// 给 iCloud（CloudKit 镜像）模式用：启动迁移只管得了当时库里已有的行，之后异步导入进来的——
    /// 新加入的 Mac 迟到的历史、还在跑旧版本的设备继续写出的行——都不会再经过 `runIfNeeded`，
    /// 镜像路径也没有逐条导入的钩子可以挂 `normalized(_:)`。收到远端变更通知时调这个兜底；
    /// 两次按值谓词的 fetch，没有命中时几乎不花钱。
    @discardableResult
    static func rewriteLegacyRows(in context: ModelContext) -> Bool {
        var changed = 0
        for hex in legacyHexes {
            // 逐个值走谓词，而不是全表取出来在内存里筛：历史可以是「无限制」，
            // 全表 fetch 会把每一行都实例化出来
            let target: String? = hex
            let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.sourceColorHex == target })
            guard let rows = try? context.fetch(descriptor) else { return false }
            for row in rows {
                row.sourceColorHex = nil
            }
            changed += rows.count
        }
        guard changed > 0 else { return true }
        do {
            try context.save()
            return true
        } catch {
            // 存不进去就整批撤回，保持库与「未迁移」标记一致
            context.rollback()
            return false
        }
    }

    /// 导入路径用：把旧版本 Mac 写出的回退色映射成 nil，其余原样返回。
    /// 迁移只管得了本机库里已有的行；还在跑旧版本的另一台 Mac 会继续产出这两个值，从同步进来的那一刻就要拦下。
    static func normalized(_ hex: String?) -> String? {
        guard let hex, legacyHexes.contains(hex) else { return hex }
        return nil
    }

    /// 旧版本可能写进库的两个回退值（算不出来的那个就不在集合里）
    private static let legacyHexes: Set<String> = {
        var hexes: Set<String> = []
        if let slate = NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.58, alpha: 1).srgbHexString {
            hexes.insert(slate) // 实测 #7E8EA5
        }
        let genericIcon = NSWorkspace.shared.icon(for: UTType.application)
        if let generic = legacyDominantColor(of: genericIcon)?.srgbHexString {
            hexes.insert(generic)
        }
        return hexes
    }()

    /// 1.2 之前 `AppIconProvider.dominantColor(of:)` 的**冻结副本**，逐行照抄，不许改。
    /// 这里要还原的是旧版本当年算出的值；`AppIconProvider` 以后调算法（第 30 条之后它可能还会动），
    /// 迁移不能跟着变，否则就认不出存量行了。
    private static func legacyDominantColor(of image: NSImage) -> NSColor? {
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
                if brightness > 0.92 || brightness < 0.08 { continue }
                red += r; green += g; blue += b; count += 1
            }
        }
        guard count > 0 else { return nil }
        let averaged = NSColor(srgbRed: red / count, green: green / count, blue: blue / count, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        averaged.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return NSColor(hue: hue,
                       saturation: min(1, saturation * 1.25 + 0.08),
                       brightness: min(0.75, max(0.35, brightness * 0.85)),
                       alpha: 1)
    }
}
