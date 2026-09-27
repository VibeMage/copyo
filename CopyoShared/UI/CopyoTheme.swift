import SwiftUI
#if canImport(UIKit)
import UIKit
/// 平台色：iOS 与扩展是 `UIColor`，Mac 是 `NSColor`。API 名沿用 `…UI` / `uiColor` 的旧写法，
/// iOS 侧调用点一个字都不用改。
typealias PlatformColor = UIColor
#else
import AppKit
typealias PlatformColor = NSColor
#endif

extension Color {
    init(platformColor: PlatformColor) {
#if canImport(UIKit)
        self.init(uiColor: platformColor)
#else
        self.init(nsColor: platformColor)
#endif
    }
}

/// 设计稿的语义色 / 圆角 / 间距 / 字号集中在这里。
///
/// 颜色一律用动态色构造（iOS `UIColor(dynamicProvider:)`、Mac `NSColor(name:dynamicProvider:)`），
/// 浅深两套值同时给出：系统外观切换时颜色自己会变，界面代码不必到处传 `ColorScheme`。
///
/// 2026-09-27 起 Mac target 也编译本文件（design-spec 7.5.18：`CopyoShared` 进 Mac 的同步组，
/// 只排除 UIKit 专用的文件）。色与圆角两端共用；字号按平台分叉——Mac 是 dense 档的死点数，
/// 不跟随系统文字大小（第八节第 34 条），见文末 `Dense`。
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

    /// sRGB 分量 → 平台色。Mac 上必须显式走 sRGB：`NSColor(red:…)` 给的是 calibrated（通用 RGB），
    /// 同一组数在 Mac 和 iPhone 上会差出肉眼可见的一截。
    static func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> PlatformColor {
#if canImport(UIKit)
        UIColor(red: r, green: g, blue: b, alpha: a)
#else
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
#endif
    }

    /// 0xRRGGBB + 透明度 → 平台色（设计稿里的 `rgba(...)` 直接照抄成 alpha）
    static func rgb(_ value: UInt32, _ alpha: CGFloat = 1) -> PlatformColor {
        srgb(CGFloat((value >> 16) & 0xFF) / 255,
             CGFloat((value >> 8) & 0xFF) / 255,
             CGFloat(value & 0xFF) / 255,
             alpha)
    }

    static func dynamic(light: PlatformColor, dark: PlatformColor) -> Color {
        Color(platformColor: dynamicUIColor(light: light, dark: dark))
    }

    static func dynamicUIColor(light: PlatformColor, dark: PlatformColor) -> PlatformColor {
#if canImport(UIKit)
        UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
#else
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
#endif
    }

    /// 解析 "#RRGGBB" / "#RRGGBBAA"，失败返回 nil。
    /// CopyoCore 有 SwiftUI `Color(hexString:)`，但淡染混色要按分量算，必须落到平台色。
    static func uiColor(hexString: String?) -> PlatformColor? {
        guard let raw = hexString?.trimmingCharacters(in: .whitespacesAndNewlines),
              raw.hasPrefix("#") else { return nil }
        let hex = String(raw.dropFirst())
        guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else { return nil }
        if hex.count == 6 {
            return srgb(CGFloat((value >> 16) & 0xFF) / 255,
                        CGFloat((value >> 8) & 0xFF) / 255,
                        CGFloat(value & 0xFF) / 255,
                        1)
        }
        return srgb(CGFloat((value >> 24) & 0xFF) / 255,
                    CGFloat((value >> 16) & 0xFF) / 255,
                    CGFloat((value >> 8) & 0xFF) / 255,
                    CGFloat(value & 0xFF) / 255)
    }

    /// 取 sRGB 分量。Mac 的 `NSColor.getRed` 在非 RGB 色彩空间会直接 trap，动态色又根本转不了
    /// 色彩空间（design-spec 7.3 障碍 2），所以只收具体色、先转 sRGB；转不了按黑处理而不是崩。
    static func components(_ color: PlatformColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
#if canImport(UIKit)
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
#else
        guard let srgb = color.usingColorSpace(.sRGB) else { return (0, 0, 0, 1) }
        srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
#endif
        return (r, g, b, a)
    }

    // MARK: - 语义色

    static let accent = Color(platformColor: accentUI)
    static let accentUI = rgb(0x0A84FF)

    static let destructive = dynamic(light: rgb(0xFF3B30), dark: rgb(0xFF453A))
    static let success = dynamic(light: rgb(0x34C759), dark: rgb(0x30D158))
    /// 深色基色整体抬离纯黑（design-spec 7.4.1）：纯黑在 Mac 窗口里是一个洞，
    /// 卡片底从 #1C1C1E 抬到 #2C2C2E 后 20% 淡染在深色下才分得出来。
    static let bgGrouped = dynamic(light: rgb(0xF2F2F7), dark: rgb(0x1C1C1E))
    static let bgCardDarkUI = rgb(0x2C2C2E)
    static let bgCard = dynamic(light: rgb(0xFFFFFF), dark: bgCardDarkUI)
    static let label = dynamic(light: rgb(0x000000), dark: rgb(0xFFFFFF))
    static let labelSecondary = dynamic(light: rgb(0x3C3C43, 0.6), dark: rgb(0xEBEBF5, 0.6))
#if os(macOS)
    /// Mac 取 .34（第八节第 32(a) 条）：桌面上字号更小，需要更高的对比度；iOS 保持 .3
    static let labelTertiary = dynamic(light: rgb(0x3C3C43, 0.34), dark: rgb(0xEBEBF5, 0.34))
#else
    static let labelTertiary = dynamic(light: rgb(0x3C3C43, 0.3), dark: rgb(0xEBEBF5, 0.3))
#endif
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
    /// 与 `menu` 的区别是这一档没有透明度：`menu` 带 0.86 alpha，套在实心行上会把面板底色透上来。
    /// 它原本和 `bgCard` 分开，是因为深色下 `bgCard` 与 `sheet` 同为 #1C1C1E 会撞色；
    /// 7.4.1 把 `bgCard` 抬到 #2C2C2E 之后撞色前提消失，两者取值完全相同，这里只留别名（第 33 条）。
    static let rowOpaque = bgCard
    static let sidebarBg = dynamic(light: rgb(0xEBEBF0), dark: rgb(0x141416))
    static let lockFill = dynamic(light: rgb(0x000000, 0.08), dark: rgb(0xFFFFFF, 0.18))
    static let tintBlue = dynamic(light: rgb(0x0A84FF, 0.12), dark: rgb(0x0A84FF, 0.22))
    static let tintRed = dynamic(light: rgb(0xFF2D55, 0.12), dark: rgb(0xFF2D55, 0.22))
    static let warning = Color(platformColor: rgb(0xFF9F0A))

    /// 玻璃描边（glassRing）与阴影（glassSh）的手工回退值
    static let glassStroke = dynamic(light: rgb(0x000000, 0.06), dark: rgb(0xFFFFFF, 0.15))
    static let glassShadow = dynamic(light: rgb(0x000000, 0.08), dark: rgb(0x000000, 0.3))

    /// 品牌色：按规格只用于图标、空态与引导，正文界面不出现
    enum Brand {
        static let red = Color(platformColor: CopyoTheme.rgb(0xFF2D55))
        static let blue = Color(platformColor: CopyoTheme.rgb(0x0A84FF))
        static let bone = Color(platformColor: CopyoTheme.rgb(0xF7F3EA))
        static let ink = Color(platformColor: CopyoTheme.rgb(0x16161A))
    }

    /// 来源色为 nil 时的固定灰（第八节第 30 条：Mac 取不到来源色也写 nil，两端在显示层回退到这里）
    static let sourceLocalUI = rgb(0x8E8E93)
    static let sourceLocal = Color(platformColor: sourceLocalUI)

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
        scheme == .dark ? Color(platformColor: rgb(0x2A2A2C)) : Color(platformColor: rgb(0xD1D3D9))
    }

    /// 字母键帽（`key`）
    static func keyCap(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(platformColor: rgb(0x6B6B6F)) : Color(platformColor: rgb(0xFFFFFF))
    }

    /// 功能键帽（`keyDark`）：地球、上档、删除、换行、面板切换
    static func keyCapFunction(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(platformColor: rgb(0x464649)) : Color(platformColor: rgb(0xABB0BA))
    }

    /// 键帽底下那 1pt 硬边（`keySh`，设计写作 `box-shadow: 0 1px 0 keySh`）
    static func keyShadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(platformColor: rgb(0x000000, 0.5)) : Color(platformColor: rgb(0x000000, 0.3))
    }

    // MARK: - 来源淡染

    /// 卡片底色：浅色把来源色按 12% 混进白，深色按 20% 混进 `bgCard` 的深色值 #2C2C2E。
    /// 悬停（仅 Mac）加深到 16% / 26%（第八节第 7 条）。
    /// 按 sRGB 分量线性插值、**不量化**（第 29 条：公式为准，两端同一个 `mix`）。
    static func tintUIColor(source: PlatformColor, hover: Bool = false) -> PlatformColor {
        dynamicUIColor(light: tintUIColor(source: source, dark: false, hover: hover),
                       dark: tintUIColor(source: source, dark: true, hover: hover))
    }

    /// 按指定外观取值（截图、小组件预览、键盘这种拿不到 trait 的场景）
    static func tintUIColor(source: PlatformColor, dark: Bool, hover: Bool = false) -> PlatformColor {
        dark
            ? mix(source, into: bgCardDarkUI, fraction: hover ? 0.26 : 0.20)
            : mix(source, into: rgb(0xFFFFFF), fraction: hover ? 0.16 : 0.12)
    }

    static func tint(sourceHex: String?, hover: Bool = false) -> Color {
        Color(platformColor: tintUIColor(source: uiColor(hexString: sourceHex) ?? sourceLocalUI, hover: hover))
    }

    /// `fraction` 份 source + 其余 base。两个参数都必须是具体色（不能是动态色）。
    static func mix(_ source: PlatformColor, into base: PlatformColor, fraction: CGFloat) -> PlatformColor {
        let s = components(source)
        let b = components(base)
        let f = min(max(fraction, 0), 1)
        return srgb(s.r * f + b.r * (1 - f),
                    s.g * f + b.g * (1 - f),
                    s.b * f + b.b * (1 - f),
                    1)
    }

    /// 角标文字色：来源色亮度 > 0.62 用 78% 黑，否则纯白（设计稿的 onBand 规则；第 32(b) 条两端统一）
    static func onBandUIColor(source: PlatformColor) -> PlatformColor {
        let c = components(source)
        let luminance = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
        return luminance > 0.62 ? srgb(0, 0, 0, 0.78) : srgb(1, 1, 1, 1)
    }

    static func onBand(sourceHex: String?) -> Color {
        Color(platformColor: onBandUIColor(source: uiColor(hexString: sourceHex) ?? sourceLocalUI))
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
        /// 「来源 · 相对时间」11。整张网格只有这一个字号——宽度不够时截断来源名，不缩字
        static let meta = Font.caption2
        /// 链接域名 12
        static let linkDomain = Font.caption
    }

    /// 卡片正文的行距。设计稿给的是**行高**（15/20、dense 13/17），SwiftUI 的 `lineSpacing`
    /// 却是叠在字体自然行高**之上**的额外间距——两者不是一个量，不能把差值之外的数填进来。
    /// subheadline 自然行高约 18，footnote 约 15.5，所以这里只补 2 / 1.5。
    /// 原来的 5 / 4 叠出来是 23pt 行距，每张卡都比设计高一截，同屏少看一两张。
    static func cardLineSpacing(dense: Bool) -> CGFloat { dense ? 1.5 : 2 }

    /// 等宽正文的行距：13/18（dense 11/15）。mono footnote 自然行高约 15.5、caption2 约 13
    static func cardMonoLineSpacing(dense: Bool) -> CGFloat { dense ? 2 : 2.5 }

    /// 富文本正文 14pt 的行距。设计里要点行与标题同为 20pt 一行，14pt 自然行高约 16.7
    static func cardRichLineSpacing(dense: Bool) -> CGFloat { dense ? 2 : 3 }

    /// 轻点、插入卡片等统一动效
    static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.8)

#if os(macOS)
    // MARK: - macOS dense 档

    /// Mac 专属：卡片 meta 行（10pt 在淡染上要 4.5:1，比 `labelSecondary` 的 .6 深一档；第 32(e) 条，iOS 不抬）
    static let labelMeta = dynamic(light: rgb(0x3C3C43, 0.78), dark: rgb(0xEBEBF5, 0.72))
    /// 卡片 0.5pt 描边与色块描边（第 32(d) 条：Mac 桌面背景变化大，卡片需要边缘；iOS 保持无边框）
    static let cardRing = dynamic(light: rgb(0x000000, 0.05), dark: rgb(0xFFFFFF, 0.06))
    static let swatchRing = dynamic(light: rgb(0x000000, 0.08), dark: rgb(0xFFFFFF, 0.10))
    /// 玻璃外壳的描边（面板、动作簇、轻提示、预览窗）
    static let glassRing = dynamic(light: rgb(0x000000, 0.06), dark: rgb(0xFFFFFF, 0.15))
    /// 减弱透明度时玻璃统一降级成的实色（第 24 条）
    static let glassSolid = bgGrouped

    /// 面板、卡片、提示条的尺寸与字号，数值取自 `art/macos-design/2026-09-27/gen_v2.py`。
    /// Mac 不响应系统文字大小（第 34 条），这里全是死点数。
    enum Dense {
        static let panelWidth: CGFloat = 1280
        static let panelHeight: CGFloat = 332
        static let panelRadius: CGFloat = 26
        static let panelPadding: CGFloat = 16
        /// 面板底边离 Dock 顶（`visibleFrame.minY`）的距离；左右各留的最小边距
        static let panelBottomInset: CGFloat = 12
        static let panelSideMargin: CGFloat = 16

        static let searchHeight: CGFloat = 32
        static let chipHeight: CGFloat = 26
        static let hintHeight: CGFloat = 24

        static let cardWidth: CGFloat = 260
        static let cardHeight: CGFloat = 184
        static let cardRadius: CGFloat = 12
        static let cardPadding: CGFloat = 12
        static let cardGap: CGFloat = 12
        static let thumbRadius: CGFloat = 10
        /// 文本卡正文最多几行（第 38 条：184 高的卡正文净高 106pt，12/16 只装得下 6 行）
        static let bodyLineLimit = 6

        static let previewWidth: CGFloat = 720
        static let previewMaxHeight: CGFloat = 480
        static let previewRadius: CGFloat = 20
        static let previewGap: CGFloat = 12

        enum Font {
            static let body = SwiftUI.Font.system(size: 12)
            static let mono = SwiftUI.Font.system(size: 11, design: .monospaced)
            static let meta = SwiftUI.Font.system(size: 10)
            static let badge = SwiftUI.Font.system(size: 10, weight: .semibold)
            static let search = SwiftUI.Font.system(size: 13)
            static let chip = SwiftUI.Font.system(size: 12, weight: .medium)
            static let hint = SwiftUI.Font.system(size: 11)
            static let keycap = SwiftUI.Font.system(size: 11, weight: .medium, design: .monospaced)
            static let emptyTitle = SwiftUI.Font.system(size: 17, weight: .bold)
        }
    }
#endif
}
