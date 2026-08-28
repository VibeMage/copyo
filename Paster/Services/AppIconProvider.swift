import AppKit
import UniformTypeIdentifiers

/// 按来源应用 bundle ID 提供图标与卡片头部主题色（取应用图标的平均色）。
@MainActor
enum AppIconProvider {
    private static var iconCache: [String: NSImage] = [:]
    private static var colorCache: [String: NSColor] = [:]

    static let fallbackColor = NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.58, alpha: 1)

    static func icon(forBundleID bundleID: String?) -> NSImage {
        let key = bundleID ?? "?"
        if let cached = iconCache[key] { return cached }
        let icon: NSImage
        if let bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSWorkspace.shared.icon(for: UTType.application)
        }
        iconCache[key] = icon
        return icon
    }

    static func headerColor(forBundleID bundleID: String?) -> NSColor {
        let key = bundleID ?? "?"
        if let cached = colorCache[key] { return cached }
        let color = dominantColor(of: icon(forBundleID: bundleID)) ?? fallbackColor
        colorCache[key] = color
        return color
    }

    /// 对图标做粗粒度像素采样求平均色，过滤透明与接近黑白的像素
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
