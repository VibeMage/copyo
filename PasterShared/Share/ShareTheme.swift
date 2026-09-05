import SwiftUI
import UIKit

/// 分享面板用到的设计 token。
///
/// 主应用的 `PasterTheme` 属于 target "Paster iOS"，分享扩展编译不到它，
/// 所以这里按 design-spec 第二节重抄一份**只含分享面板需要的那些值**（不是整套主题的副本）。
/// 改设计 token 时两处都要改：`PasterIOS/UI/Theme.swift` 与本文件。
public enum ShareTheme {

    // MARK: - 构造

    static func rgb(_ value: UInt32, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: alpha)
    }

    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// 解析 "#RRGGBB"，失败返回 nil
    static func uiColor(hexString: String?) -> UIColor? {
        guard let raw = hexString?.trimmingCharacters(in: .whitespacesAndNewlines),
              raw.hasPrefix("#") else { return nil }
        let hex = String(raw.dropFirst())
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                       green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255,
                       alpha: 1)
    }

    // MARK: - 语义色

    public static let accent = Color(uiColor: rgb(0x0A84FF))
    static let label = dynamic(light: rgb(0x000000), dark: rgb(0xFFFFFF))
    static let labelSecondary = dynamic(light: rgb(0x3C3C43, 0.6), dark: rgb(0xEBEBF5, 0.6))
    static let labelTertiary = dynamic(light: rgb(0x3C3C43, 0.3), dark: rgb(0xEBEBF5, 0.3))
    static let bgCard = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x1C1C1E))
    static let sheet = dynamic(light: rgb(0xF2F2F7), dark: rgb(0x1C1C1E))

    /// 「固定到 Pinboard」那行的底色。
    ///
    /// 设计稿这行用的是 `bg.card`，但深色下 `bg.card` 与 `sheet` 都是 `#1C1C1E`——
    /// 照抄的结果是整行在深色里完全看不见，点不出来这是个可点的控件。
    /// 深色改用 `#2C2C2E`（设计稿 `menu` token 的底色，同一套灰阶里的上一档），浅色仍是设计稿的纯白。
    static let rowBackground = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x2C2C2E))
    static let dim = dynamic(light: rgb(0x000000, 0.18), dark: rgb(0x000000, 0.5))

    /// 品牌色，只用在标题旁那枚应用标记上
    static let brandBone = Color(uiColor: rgb(0xF7F3EA))
    static let brandRed = Color(uiColor: rgb(0xFF2D55))
    static let brandBlue = Color(uiColor: rgb(0x0A84FF))

    /// 本机条目的固定灰。分享扩展存进来的条目一律没有来源色，全部走它。
    static let sourceLocalUI = rgb(0x8E8E93)

    /// 来源淡染：浅色 12% 混白、深色 20% 混 #1C1C1E（design-spec 2.1 card.tint）
    static func tint(sourceHex: String?) -> Color {
        let source = uiColor(hexString: sourceHex) ?? sourceLocalUI
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? mix(source, into: rgb(0x1C1C1E), fraction: 0.20)
                : mix(source, into: rgb(0xFFFFFF), fraction: 0.12)
        })
    }

    /// 角标文字色：来源色亮度 > 0.62 用 78% 黑，否则纯白
    static func onBand(sourceHex: String?) -> Color {
        let source = uiColor(hexString: sourceHex) ?? sourceLocalUI
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        source.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.62 ? Color(uiColor: UIColor(white: 0, alpha: 0.78)) : .white
    }

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

    // MARK: - 尺寸（design-spec 3.10）

    enum Metrics {
        static let sheetRadius: CGFloat = 38
        static let cardRadius: CGFloat = 12
        static let innerRadius: CGFloat = 8
        static let badgeRadius: CGFloat = 10
        static let pageInset: CGFloat = 20
        static let cardPad: CGFloat = 12
        static let rowHeight: CGFloat = 48
        static let saveButtonHeight: CGFloat = 52
        static let headerSideWidth: CGFloat = 60
        static let appMark: CGFloat = 26
        static let sheetBottomPad: CGFloat = 44
        static let gap: CGFloat = 16
    }
}

/// 标题旁那枚 26pt 应用标记。
///
/// 设计稿这里画的是 App 图标，但扩展 bundle 里没有图标资源（图标只在主应用的 Assets 里），
/// 跨进程取自己的图标也没有公开 API，所以按品牌语言（骨白卡片 + 红蓝错位套印）现画一枚，
/// 与空态插画同源。
struct PasterMark: View {
    var size: CGFloat = ShareTheme.Metrics.appMark

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(ShareTheme.brandBone)
            Capsule()
                .fill(ShareTheme.brandRed.opacity(0.9))
                .frame(width: size * 0.54, height: size * 0.13)
                .offset(x: -size * 0.06, y: -size * 0.07)
            Capsule()
                .fill(ShareTheme.brandBlue.opacity(0.85))
                .frame(width: size * 0.54, height: size * 0.13)
                .offset(x: size * 0.06, y: size * 0.07)
                .blendMode(.multiply)
        }
        .frame(width: size, height: size)
        .compositingGroup()
    }
}
