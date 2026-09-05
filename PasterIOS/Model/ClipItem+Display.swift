import PasterCore
import SwiftData
import SwiftUI
import UIKit

/// 卡片、详情、分享预览共用的展示派生值（**iOS 侧**，带本地化）。
/// PasterCore 里同名文件只放不需要本地化的部分（displayTitle / linkDomain / isCodeLike）。
extension ClipItem {

    // MARK: - 来源

    /// 来源 App 名。iOS 本机采集的条目没有来源，显示「本机」。
    var sourceDisplayName: String {
        let name = sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? String(localized: "This iPhone") : name
    }

    /// 来源色。Mac 端算好同步过来；没有就用本机灰 #8E8E93（存量条目也走这里）。
    var sourceUIColor: UIColor {
        PasterTheme.uiColor(hexString: sourceColorHex) ?? PasterTheme.sourceLocalUI
    }

    var sourceColor: Color { Color(uiColor: sourceUIColor) }

    /// 整卡淡染色（浅 12% 混白 / 深 20% 混 #1C1C1E），随系统外观自动切换
    var tintColor: Color { Color(uiColor: PasterTheme.tintUIColor(source: sourceUIColor)) }

    /// 需要按指定外观取值时用这个（截图、小组件预览等场景拿不到 trait）
    func tintColor(for scheme: ColorScheme) -> Color {
        let base = scheme == .dark ? PasterTheme.rgb(0x1C1C1E) : PasterTheme.rgb(0xFFFFFF)
        let fraction: CGFloat = scheme == .dark ? 0.20 : 0.12
        return Color(uiColor: PasterTheme.mix(sourceUIColor, into: base, fraction: fraction))
    }

    /// 角标文字色：亮度 > 0.62 用 78% 黑，否则白
    var badgeForeground: Color {
        Color(uiColor: PasterTheme.onBandUIColor(source: sourceUIColor))
    }

    // MARK: - 时间

    /// 「刚刚 / 3 分钟前 / 昨天 18:42 / 9月2日 14:05」
    func relativeTime(reference: Date = Date()) -> String {
        let interval = reference.timeIntervalSince(createdAt)
        if interval < 60 { return String(localized: "Just now") }
        let calendar = Calendar.current
        if calendar.isDate(createdAt, inSameDayAs: reference) {
            return createdAt.formatted(.relative(presentation: .numeric, unitsStyle: .wide))
        }
        // 昨天及更早给「日期 + 时刻」：设计稿的 `昨天 18:42` 就是系统相对日期格式化的结果
        return Self.dateTimeFormatter.string(from: createdAt)
    }

    var relativeTime: String { relativeTime() }

    /// 详情页的绝对时间：`今天 14:32`
    var absoluteTime: String { Self.dateTimeFormatter.string(from: createdAt) }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        // 「今天 / 昨天」由系统按当前语言给，自己拼会在英文下变成错误的语序
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    // MARK: - 正文

    /// 正文像代码或命令，卡片与详情改用等宽字体
    var isMono: Bool { isCodeLike }

    /// 卡片正文。图片没有正文，颜色给 hex，文件给文件名。
    var displayBody: String {
        switch kind {
        case .image: return ""
        case .color: return (plainText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        case .file: return displayTitle
        default: return plainText ?? ""
        }
    }

    /// 图片条目的占位文案（PasterCore 的 displayTitle 对图片返回空串，本地化由这里补）
    var displayTitleLocalized: String {
        let title = displayTitle
        return title.isEmpty ? KindPresentation.label(kind) : title
    }

    /// 富文本渲染。RTF 解码要走 NSAttributedString，失败时回落到纯文本。
    var richTextAttributed: AttributedString? {
        guard kind == .richText, let data = rtfData else { return nil }
        guard let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else { return nil }
        return try? AttributedString(attributed, including: \.uiKit)
    }

    /// 富文本的首行（设计稿里首行加粗当标题用）
    var richTextTitleLine: String {
        (plainText ?? "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    /// 富文本去掉首行之后的正文
    var richTextRemainder: String {
        let lines = (plainText ?? "").split(separator: "\n", omittingEmptySubsequences: false)
        guard let index = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return "" }
        return lines[(index + 1)...].joined(separator: "\n")
    }

    // MARK: - 颜色条目

    var colorValue: Color? {
        guard kind == .color else { return nil }
        return Color(hexString: (plainText ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var colorComponents: (r: CGFloat, g: CGFloat, b: CGFloat)? {
        guard kind == .color,
              let ui = PasterTheme.uiColor(hexString: (plainText ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    /// `rgb(255,159,10)`
    var colorRGBString: String? {
        guard let c = colorComponents else { return nil }
        return "rgb(\(Int((c.r * 255).rounded())),\(Int((c.g * 255).rounded())),\(Int((c.b * 255).rounded())))"
    }

    /// `hsl(36 100% 52%)`
    var colorHSLString: String? {
        guard let c = colorComponents else { return nil }
        let maxV = max(c.r, c.g, c.b), minV = min(c.r, c.g, c.b)
        let delta = maxV - minV
        var hue: CGFloat = 0
        if delta > 0 {
            switch maxV {
            case c.r: hue = (c.g - c.b) / delta + (c.g < c.b ? 6 : 0)
            case c.g: hue = (c.b - c.r) / delta + 2
            default: hue = (c.r - c.g) / delta + 4
            }
            hue *= 60
        }
        let lightness = (maxV + minV) / 2
        let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
        return "hsl(\(Int(hue.rounded())) \(Int((saturation * 100).rounded()))% \(Int((lightness * 100).rounded()))%)"
    }

    // MARK: - 图片

    /// 缩略图。解码后按条目缓存，避免瀑布流滚动时反复解 externalStorage 里的整张图。
    var thumbnail: UIImage? { ImageMetadataCache.shared.image(for: self) }

    /// `1284 × 2778 · PNG`
    var imageMetadata: String? {
        guard let info = ImageMetadataCache.shared.metadata(for: self) else { return nil }
        return "\(Int(info.size.width)) × \(Int(info.size.height)) · \(info.format)"
    }
}

/// 图片解码的结果缓存。SwiftData 的 externalStorage 每次访问 imageData 都会读盘，
/// 双列瀑布流一屏能有十几张图，不缓存会在滚动时明显掉帧。
/// 用 NSCache 而不是字典：它自己线程安全，且内存吃紧时系统会主动清空。
final class ImageMetadataCache {
    static let shared = ImageMetadataCache()

    struct Info {
        var size: CGSize
        var format: String
    }

    /// NSCache 的值必须是类
    private final class Entry {
        let image: UIImage
        let info: Info
        init(image: UIImage, info: Info) {
            self.image = image
            self.info = info
        }
    }

    private let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        // 一张 iPhone 截图解出来十几 MB，不封顶会在长时间滚动后被系统杀掉
        cache.countLimit = 40
        return cache
    }()

    func image(for item: ClipItem) -> UIImage? { entry(for: item)?.image }

    func metadata(for item: ClipItem) -> Info? { entry(for: item)?.info }

    func invalidate(_ item: ClipItem) {
        cache.removeObject(forKey: Self.key(for: item))
    }

    private func entry(for item: ClipItem) -> Entry? {
        guard item.kind == .image else { return nil }
        let key = Self.key(for: item)
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = item.imageData, let image = UIImage(data: data) else { return nil }
        let entry = Entry(image: image, info: Info(size: image.size, format: Self.format(of: data)))
        cache.setObject(entry, forKey: key)
        return entry
    }

    /// 图片内容的哈希在采集时就算好了；没有哈希的老条目退回 objectID 描述
    private static func key(for item: ClipItem) -> NSString {
        if let hash = item.imageHash, !hash.isEmpty { return hash as NSString }
        return String(describing: item.persistentModelID) as NSString
    }

    /// 只看文件头：采集路径统一转 PNG，但 CloudKit 上还有 Mac 早期版本存的 JPEG / TIFF
    private static func format(of data: Data) -> String {
        let prefix = [UInt8](data.prefix(4))
        if prefix.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "PNG" }
        if prefix.starts(with: [0xFF, 0xD8]) { return "JPEG" }
        if prefix.starts(with: [0x47, 0x49, 0x46]) { return "GIF" }
        if prefix.starts(with: [0x49, 0x49]) || prefix.starts(with: [0x4D, 0x4D]) { return "TIFF" }
        return "PNG"
    }
}
