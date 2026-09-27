import CopyoCore
import SwiftData
import SwiftUI
import UIKit

/// 卡片、详情、分享预览共用的展示派生值（**iOS 侧**，带本地化）。
/// CopyoCore 里同名文件只放不需要本地化的部分（displayTitle / linkDomain / isCodeLike）。
extension ClipItem {

    // MARK: - 来源

    /// 来源 App 名。iOS 本机采集的条目没有来源，显示「本机」。
    ///
    /// 键名还叫 "This iPhone"，但英文 / 法语译文是设备中性的「This Device / Cet appareil」：
    /// 同一个应用也跑在 iPad 上，iPad 存的条目来源同样为空，同步到 iPhone 后也走这里——
    /// 写死「iPhone」在 iPad 上是错的，同步过去以后在两边都是错的。
    /// 键名不改是为了让键盘、小组件与分享扩展里同一个键跟着译文一起变，不必四处各改一次代码。
    var sourceDisplayName: String {
        let name = sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? String(localized: "This iPhone") : name
    }

    /// 卡片的渲染色：颜色条目取内容本身的颜色，其余取来源色（Mac 端算好同步过来）；
    /// 都没有就用本机灰 #8E8E93。见 CopyoCore `renderColorHex`（design-spec 7.4.2）。
    var sourceUIColor: UIColor {
        CopyoTheme.uiColor(hexString: renderColorHex) ?? CopyoTheme.sourceLocalUI
    }

    var sourceColor: Color { Color(uiColor: sourceUIColor) }

    /// 整卡淡染色（浅 12% 混白 / 深 20% 混 #2C2C2E），随系统外观自动切换
    var tintColor: Color {
        // 两态先算好再进闭包：动态色的闭包会被系统长期持有，捕获 `self`（一个 `@Model`）就等于把它钉住
        let light = cardFillUIColor(dark: false)
        let dark = cardFillUIColor(dark: true)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// 需要按指定外观取值时用这个（截图、小组件预览等场景拿不到 trait）
    func tintColor(for scheme: ColorScheme) -> Color {
        Color(uiColor: cardFillUIColor(dark: scheme == .dark))
    }

    /// 没有渲染色的条目（本机采集的文本、图片）在浅色下用**白卡**，不按公式淡染。
    ///
    /// 公式给出的本机灰 `mix(#8E8E93 12%, #FFF)` = (240,240,241)，页面底 `#F2F2F7` = (242,242,247)，
    /// 两者只差两三个色阶——设计画布上勉强分得开，真机屏幕加上色彩管理就完全融进背景，
    /// 维护者第一次 TestFlight 就指出「文本卡片和背景融到一起了」。白卡压灰底是 iOS 分组列表的
    /// 标准对比。深色下本机灰淡染是 (54,54,56) 对纯黑，对比足够，照公式走。
    /// 只改 iOS：`CopyoTheme.tintUIColor` 是 Mac 面板也在用的共享公式，Mac 的底色不同，不跟着变。
    private func cardFillUIColor(dark: Bool) -> UIColor {
        if !dark, CopyoTheme.uiColor(hexString: renderColorHex) == nil {
            return .white
        }
        return CopyoTheme.tintUIColor(source: sourceUIColor, dark: dark)
    }

    /// 角标文字色：亮度 > 0.62 用 78% 黑，否则白
    var badgeForeground: Color {
        Color(uiColor: CopyoTheme.onBandUIColor(source: sourceUIColor))
    }

    // MARK: - 时间

    /// 「刚刚 / 3 分钟前 / 昨天 18:42」。口径与四端共用，见 `CopyoShared/UI/RelativeTime.swift`
    func relativeTime(reference: Date = Date()) -> String {
        RelativeTime.string(for: createdAt, reference: reference)
    }

    var relativeTime: String { relativeTime() }

    /// 卡片元信息行放不下完整时间时的短形：「昨天 15:38」→「昨天」，「Last week」→「1w」，
    /// 其余各档本来就是短的，原样返回。
    ///
    /// 英文的 `Yesterday, 15:48` 在 iPhone 双列里连 `VS Code` 都放不下，原来是整行缩到 0.8，
    /// 于是这几张卡的元信息比邻居小一号（design-spec 6.2 的英文样例也只写 `Yesterday`）。
    /// 「昨天」同样交给系统的相对日期格式化给，不进本地化目录，语序与大小写各语言自己管。
    func compactRelativeTime(reference: Date = Date()) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: createdAt),
                                           to: calendar.startOfDay(for: reference)).day ?? 0
        // 「上周」这一档的短形，写法与 `%lldd` 一致（`1w` / `1 sem.`）；只给屏幕，不进旁白
        if (7..<14).contains(days) { return String(localized: "1w") }
        if reference.timeIntervalSince(createdAt) >= 60,
           !calendar.isDate(createdAt, inSameDayAs: reference),
           calendar.isDateInYesterday(createdAt) {
            return Self.relativeDayFormatter.string(from: createdAt)
        }
        return relativeTime(reference: reference)
    }

    var compactRelativeTime: String { compactRelativeTime() }

    /// 详情页的绝对时间：`今天 14:32`
    var absoluteTime: String { RelativeTime.absolute(createdAt) }

    /// 只要「昨天」这个词，不带时刻（`compactRelativeTime` 用）
    private static let relativeDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
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

    /// 图片条目的占位文案（CopyoCore 的 displayTitle 对图片返回空串，本地化由这里补）
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
              let ui = CopyoTheme.uiColor(hexString: (plainText ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
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
        // 光限条数不够：Mac 同步过来的 5K 截图一张解出来约 59MB，40 张就是 2GB 级，
        // 前台应用会先被 jetsam 掉。按解码后的字节数再封一道 96MB 的顶。
        cache.totalCostLimit = 96 * 1024 * 1024
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
        cache.setObject(entry, forKey: key, cost: Self.decodedCost(of: image))
        return entry
    }

    /// 解码后占的字节数（宽 × 高 × scale² × 4），给 NSCache 的 totalCostLimit 用
    private static func decodedCost(of image: UIImage) -> Int {
        let pixels = image.size.width * image.scale * image.size.height * image.scale
        return Int(pixels.rounded()) * 4
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
