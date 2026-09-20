import SwiftUI
import UIKit

/// 设计稿的语义色 / 圆角 / 间距 / 字号集中在这里。
///
/// 颜色一律用 `UIColor(dynamicProvider:)` 构造，浅深两套值同时给出：
/// 这样系统外观切换时颜色自己会变，界面代码不必到处传 `ColorScheme`。
///
/// 放在 `CopyoShared/` 而不是 `CopyoIOS/UI/`：分享扩展与 Widget 编译不到主应用的 target，
/// 此前的办法是在 `CopyoShared/Share/ShareTheme.swift` 里按 design-spec 第二节重抄一份，
/// 于是改一个 token 要记得改两处——漏一处的表现是同一张设计稿在应用里和在分享面板里颜色对不上。
/// `CopyoShared` 是三个 target 的同步组，本文件在三个进程里是**同一份值**，那份手抄稿已删。
///
/// 全文件只碰 `UIColor` / `Color` / `Font` / `Animation`，不碰 `UIApplication`，
/// 因此在扩展的 `APPLICATION_EXTENSION_API_ONLY = YES` 下也能编译。
enum CopyoTheme {

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
    /// CopyoCore 有 SwiftUI `Color(hexString:)`，但淡染混色要按分量算，必须落到 UIColor。
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
    /// 卡片正文的次级色（设计 CopyoCard 的 sec2）。比 `labelSecondary` 深一档，
    /// 富文本卡片的正文用它——元信息行才用 60% 的 `labelSecondary`。
    static let cardBodySecondary = dynamic(light: rgb(0x3C3C43, 0.9), dark: rgb(0xEBEBF5, 0.85))
    static let fill = dynamic(light: rgb(0x767680, 0.12), dark: rgb(0x767680, 0.24))
    static let fill2 = dynamic(light: rgb(0x767680, 0.2), dark: rgb(0x767680, 0.32))
    static let separator = dynamic(light: rgb(0x3C3C43, 0.24), dark: rgb(0x545458, 0.6))
    static let tabOn = dynamic(light: rgb(0x000000, 0.07), dark: rgb(0xFFFFFF, 0.12))
    static let dim = dynamic(light: rgb(0x000000, 0.18), dark: rgb(0x000000, 0.5))
    static let menu = dynamic(light: rgb(0xFAFAFA, 0.86), dark: rgb(0x2C2C2E, 0.86))
    static let menuSeparator = dynamic(light: rgb(0x3C3C43, 0.12), dark: rgb(0xFFFFFF, 0.08))
    static let sheet = dynamic(light: rgb(0xF2F2F7), dark: rgb(0x1C1C1E))
    static let switchOn = dynamic(light: rgb(0x34C759), dark: rgb(0x30D158))
    /// 贴在面板 / 卡片上的**实心**行底色（分享面板的「固定到 Pinboard」那行）。
    ///
    /// 与 `menu` 的区别是这一档没有透明度：`menu` 画的是浮在内容之上的菜单，带 0.86 alpha，
    /// 套在实心行上会把面板底色透上来。也不能用 `bgCard`——深色下它与 `sheet` 同为 `#1C1C1E`，
    /// 整行在深色里会完全看不见，点不出来这是个可点的控件。
    static let rowOpaque = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x2C2C2E))
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
        static let red = Color(uiColor: CopyoTheme.rgb(0xFF2D55))
        static let blue = Color(uiColor: CopyoTheme.rgb(0x0A84FF))
        static let bone = Color(uiColor: CopyoTheme.rgb(0xF7F3EA))
        static let ink = Color(uiColor: CopyoTheme.rgb(0x16161A))
    }

    /// 本机条目的固定灰。Mac 端算不出来的来源色一律回落到它。
    static let sourceLocalUI = rgb(0x8E8E93)
    static let sourceLocal = Color(uiColor: sourceLocalUI)

    // MARK: - 键盘

    /// 键盘扩展那四档颜色（design-spec 2.2 的 `kb` / `key` / `keyDark` / `keySh`）。
    ///
    /// 与本文件其余颜色不同，这四个**按外观显式取值**，不走 `UIColor(dynamicProvider:)`——
    /// 键盘的深浅不由系统外观决定，而由宿主输入框的 `keyboardAppearance` 决定：
    /// 浅色 App 里放一个 `.dark` 的输入框，系统键盘就是深色的，我们也必须是深色的。
    /// `dynamic(light:dark:)` 只认 trait collection，在那种组合下会给出整整反过来的一套键帽色，
    /// 表现是键盘在深色输入框上白得刺眼、并且与紧挨着的系统键盘明显不是一套。
    /// 取值形状照 `ClipItem+Display.tintColor(for:)`：由调用方把 scheme 传进来。
    ///
    /// 放在这里而不是在 `CopyoKeyboard/` 下另起一份 token 表：上一次「分享面板抄一份」的代价
    /// 见本文件开头那段，这四个值同样是设计稿的一部分，不该有第二个副本。
    static func keyboardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(uiColor: rgb(0x2A2A2C)) : Color(uiColor: rgb(0xD1D3D9))
    }

    /// 字母键帽（`key`）
    static func keyCap(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(uiColor: rgb(0x6B6B6F)) : Color(uiColor: rgb(0xFFFFFF))
    }

    /// 功能键帽（`keyDark`）：地球、上档、删除、换行、面板切换
    static func keyCapFunction(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(uiColor: rgb(0x464649)) : Color(uiColor: rgb(0xABB0BA))
    }

    /// 键帽底下那 1pt 硬边（`keySh`，设计写作 `box-shadow: 0 1px 0 keySh`）
    static func keyShadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(uiColor: rgb(0x000000, 0.5)) : Color(uiColor: rgb(0x000000, 0.3))
    }

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

    /// 一律走系统文本样式，**不要**写 `.font(.system(size: 11))`。
    ///
    /// SwiftUI 里 `Font.system(size:)` 是死值，用户在「设置 → 辅助功能 → 显示与文字大小」
    /// 把字号调大时它纹丝不动。此前卡片正文用 `.subheadline` 会放大、而角标与元信息行写死 11pt，
    /// 于是放大档位下正文撑满、上面那行还是蚂蚁大小，整张卡片看着像坏了。
    ///
    /// 好在设计稿给的点数几乎都正好落在系统样式的默认值上，换过去**默认字号下逐像素不变**：
    ///
    /// | 设计点数 | 样式 | | 设计点数 | 样式 |
    /// | --- | --- | --- | --- | --- |
    /// | 11 | `caption2` | | 17 | `body` |
    /// | 12 | `caption` | | 20 | `title3` |
    /// | 13 | `footnote` | | 22 | `title2` |
    /// | 15 | `subheadline` | | 28 | `title` |
    /// | 16 | `callout` | | 34 | `largeTitle` |
    ///
    /// 落不到表上的零散点数（10 / 14 / 18 / 24 / 44…）在视图里用
    /// `@ScaledMetric(relativeTo:)` 声明，见 `KindBadge.fontSize` 的写法。
    ///
    /// 分享面板走的是同一份契约——它是宿主 App 里一闪而过的系统面板，字看不清就只能放弃这次保存，
    /// 没有第二个入口可退，所以那边尤其不能漏掉动态字体。
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
            .system(dense ? .caption2 : .footnote, design: .monospaced)
        }
        /// 「来源 · 相对时间」11
        static let meta = Font.caption2
        /// 链接域名 12
        static let linkDomain = Font.caption
    }

    /// 卡片正文的行距（设计稿给的是行高，SwiftUI 用行距表达）
    static func cardLineSpacing(dense: Bool) -> CGFloat { dense ? 4 : 5 }

    /// 轻点、插入卡片等统一动效
    static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.8)
}
