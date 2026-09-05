import SwiftUI
import UIKit

/// 设计稿的语义色 / 圆角 / 间距 / 字号集中在这里。
///
/// 颜色一律用 `UIColor(dynamicProvider:)` 构造，浅深两套值同时给出：
/// 这样系统外观切换时颜色自己会变，界面代码不必到处传 `ColorScheme`。
enum PasterTheme {

    // MARK: - 构造工具

    /// 0xRRGGBB + 透明度 → UIColor（设计稿里的 `rgba(...)` 直接照抄成 alpha）
    static func rgb(_ value: UInt32, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: alpha)
    }

    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: dynamicUIColor(light: light, dark: dark))
    }

    static func dynamicUIColor(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
    }

    /// 解析 "#RRGGBB" / "#RRGGBBAA"，失败返回 nil。
    /// PasterCore 有 SwiftUI `Color(hexString:)`，但淡染混色要按分量算，必须落到 UIColor。
    static func uiColor(hexString: String?) -> UIColor? {
        guard let raw = hexString?.trimmingCharacters(in: .whitespacesAndNewlines),
              raw.hasPrefix("#") else { return nil }
        let hex = String(raw.dropFirst())
        guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else { return nil }
        if hex.count == 6 {
            return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                           green: CGFloat((value >> 8) & 0xFF) / 255,
                           blue: CGFloat(value & 0xFF) / 255,
                           alpha: 1)
        }
        return UIColor(red: CGFloat((value >> 24) & 0xFF) / 255,
                       green: CGFloat((value >> 16) & 0xFF) / 255,
                       blue: CGFloat((value >> 8) & 0xFF) / 255,
                       alpha: CGFloat(value & 0xFF) / 255)
    }

    // MARK: - 语义色

    static let accent = Color(uiColor: accentUI)
    static let accentUI = rgb(0x0A84FF)

    static let destructive = dynamic(light: rgb(0xFF3B30), dark: rgb(0xFF453A))
    static let success = dynamic(light: rgb(0x34C759), dark: rgb(0x30D158))
    static let bgGrouped = dynamic(light: rgb(0xF2F2F7), dark: rgb(0x000000))
    static let bgCard = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x1C1C1E))
    static let label = dynamic(light: rgb(0x000000), dark: rgb(0xFFFFFF))
    static let labelSecondary = dynamic(light: rgb(0x3C3C43, 0.6), dark: rgb(0xEBEBF5, 0.6))
    static let labelTertiary = dynamic(light: rgb(0x3C3C43, 0.3), dark: rgb(0xEBEBF5, 0.3))
    static let fill = dynamic(light: rgb(0x767680, 0.12), dark: rgb(0x767680, 0.24))
    static let fill2 = dynamic(light: rgb(0x767680, 0.2), dark: rgb(0x767680, 0.32))
    static let separator = dynamic(light: rgb(0x3C3C43, 0.24), dark: rgb(0x545458, 0.6))
    static let tabOn = dynamic(light: rgb(0x000000, 0.07), dark: rgb(0xFFFFFF, 0.12))
    static let dim = dynamic(light: rgb(0x000000, 0.18), dark: rgb(0x000000, 0.5))
    static let menu = dynamic(light: rgb(0xFAFAFA, 0.86), dark: rgb(0x2C2C2E, 0.86))
    static let menuSeparator = dynamic(light: rgb(0x3C3C43, 0.12), dark: rgb(0xFFFFFF, 0.08))
    static let sheet = dynamic(light: rgb(0xF2F2F7), dark: rgb(0x1C1C1E))
    static let switchOn = dynamic(light: rgb(0x34C759), dark: rgb(0x30D158))
    static let sidebarBg = dynamic(light: rgb(0xEBEBF0), dark: rgb(0x141416))
    static let lockFill = dynamic(light: rgb(0x000000, 0.08), dark: rgb(0xFFFFFF, 0.18))
    static let tintBlue = dynamic(light: rgb(0x0A84FF, 0.12), dark: rgb(0x0A84FF, 0.22))
    static let tintRed = dynamic(light: rgb(0xFF2D55, 0.12), dark: rgb(0xFF2D55, 0.22))
    static let warning = Color(uiColor: rgb(0xFF9F0A))

    /// 玻璃描边（glassRing）与阴影（glassSh）的手工回退值
    static let glassStroke = dynamic(light: rgb(0x000000, 0.06), dark: rgb(0xFFFFFF, 0.15))
    static let glassShadow = dynamic(light: rgb(0x000000, 0.08), dark: rgb(0x000000, 0.3))

    /// 品牌色：按规格只用于图标、空态与引导，正文界面不出现
    enum Brand {
        static let red = Color(uiColor: PasterTheme.rgb(0xFF2D55))
        static let blue = Color(uiColor: PasterTheme.rgb(0x0A84FF))
        static let bone = Color(uiColor: PasterTheme.rgb(0xF7F3EA))
        static let ink = Color(uiColor: PasterTheme.rgb(0x16161A))
    }

    /// 本机条目的固定灰。Mac 端算不出来的来源色一律回落到它。
    static let sourceLocalUI = rgb(0x8E8E93)
    static let sourceLocal = Color(uiColor: sourceLocalUI)

    // MARK: - 来源淡染

    /// 卡片底色：浅色把来源色按 12% 混进白，深色按 20% 混进 #1C1C1E。
    /// iOS 18 没有 `Color.mix(with:by:)`，按 sRGB 分量线性插值。
    static func tintUIColor(source: UIColor) -> UIColor {
        dynamicUIColor(light: mix(source, into: rgb(0xFFFFFF), fraction: 0.12),
                       dark: mix(source, into: rgb(0x1C1C1E), fraction: 0.20))
    }

    static func tint(sourceHex: String?) -> Color {
        Color(uiColor: tintUIColor(source: uiColor(hexString: sourceHex) ?? sourceLocalUI))
    }

    /// `fraction` 份 source + 其余 base
    static func mix(_ source: UIColor, into base: UIColor, fraction: CGFloat) -> UIColor {
        var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0, sa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        source.getRed(&sr, green: &sg, blue: &sb, alpha: &sa)
        base.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let f = min(max(fraction, 0), 1)
        return UIColor(red: sr * f + br * (1 - f),
                       green: sg * f + bg * (1 - f),
                       blue: sb * f + bb * (1 - f),
                       alpha: 1)
    }

    /// 角标文字色：来源色亮度 > 0.62 用 78% 黑，否则纯白（设计稿的 onBand 规则）
    static func onBandUIColor(source: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        source.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.62 ? UIColor(white: 0, alpha: 0.78) : .white
    }

    static func onBand(sourceHex: String?) -> Color {
        Color(uiColor: onBandUIColor(source: uiColor(hexString: sourceHex) ?? sourceLocalUI))
    }

    // MARK: - 圆角

    enum Radius {
        static let card: CGFloat = 12
        static let inner: CGFloat = 8
        static let badge: CGFloat = 10
        static let group: CGFloat = 12
        static let sheet: CGFloat = 38
        static let banner: CGFloat = 14
        static let tabBar: CGFloat = 32
        static let button: CGFloat = 20
        static let toast: CGFloat = 20
    }

    // MARK: - 间距与尺寸

    enum Metrics {
        static let pageInset: CGFloat = 20
        static let pageInsetPad: CGFloat = 24
        static let gridGap: CGFloat = 12
        static let cardPad: CGFloat = 12
        static let cardPadDense: CGFloat = 10
        static let tabBarHeight: CGFloat = 64
        static let tabBarBottomInset: CGFloat = 26
        static let hitMin: CGFloat = 44
        static let toastHeight: CGFloat = 40
        static let toastTopInset: CGFloat = 6
        static let syncPillHeight: CGFloat = 40
        static let colorSwatch: CGFloat = 80
        static let colorSwatchDense: CGFloat = 40
        static let thumbnail: CGFloat = 160
        static let thumbnailDense: CGFloat = 70
        /// 宽度小于它就切回 iPhone 布局（Slide Over / 1/3 分屏）
        static let compactWidthThreshold: CGFloat = 600
    }

    // MARK: - 字号

    enum Fonts {
        static let largeTitle = Font.largeTitle.bold()
        static let title1 = Font.title.bold()
        static let title2 = Font.title2.bold()
        static let headline = Font.headline
        static let body = Font.body
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption2

        /// 卡片正文 15/20（dense 13/17）
        static func cardBody(dense: Bool) -> Font { dense ? .footnote : .subheadline }
        /// 卡片等宽 13/18（dense 11/15）
        static func cardMono(dense: Bool) -> Font {
            .system(size: dense ? 11 : 13, weight: .regular, design: .monospaced)
        }
        /// 角标 11 Semibold
        static let badge = Font.system(size: 11, weight: .semibold)
        /// 「来源 · 相对时间」11
        static let meta = Font.system(size: 11)
        /// 链接域名 12
        static let linkDomain = Font.system(size: 12)
        static let tabLabel = Font.system(size: 10, weight: .semibold)
    }

    /// 卡片正文的行距（设计稿给的是行高，SwiftUI 用行距表达）
    static func cardLineSpacing(dense: Bool) -> CGFloat { dense ? 4 : 5 }

    /// 轻点、插入卡片等统一动效
    static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.8)
}
