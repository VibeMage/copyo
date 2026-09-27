import AppKit
import SwiftUI

// 设置窗口五页共用的构件：分组标题、分组容器、行、图标砖、脚注、keycap。
// 数值一律取自 art/macos-design/2026-09-27/gen_v2.py 的「设置窗口」一节（h2 / group / srow / tile / foot / keycap），
// 颜色全部走 CopyoTheme 的动态 token，深色外观不单独写一套（第八节第 46 条：深色按 token 推导）。
// 名字统一带 Settings 前缀：面板那边也会有自己的 keycap / 行构件，同一个 target 里撞名只会在合并时才发现。

/// 设置页的纵向骨架：内容区 `padding 12 16 16`、块间距 12（`win()` 的 gap）。
/// 内容放不下时滚动——窗口固定 540 × 460（第八节第 9 条），法语等长文案只能往下长。
struct SettingsPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 16, trailing: 16))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.automatic)
    }
}

/// 分组标题：11 / 600、字距 0.4、高 20、色 `labelSecondary`；副标 11 / 400 色 `labelTertiary`
struct SettingsHeader: View {
    var title: Text
    var subtitle: Text?

    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.title = Text(title)
        self.subtitle = subtitle.map { Text($0) }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            title
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(CopyoTheme.labelSecondary)
            if let subtitle {
                subtitle
                    .font(.system(size: 11))
                    .foregroundStyle(CopyoTheme.labelTertiary)
            }
        }
        .frame(minHeight: 20, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 分组容器：圆角 10、底 `bgCard`、0.5pt `cardRing` 描边（设计稿的 `box-shadow: cring`）
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(CopyoTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(CopyoTheme.cardRing, lineWidth: 0.5)
        )
    }
}

/// 行与行之间的 0.5pt 分隔线（设计稿是非末行的 `border-bottom`，通栏不缩进）。
/// 由调用方显式插在两行之间：macOS 14 没有 `Group(subviews:)`，没法在容器里自动判断「末行」。
struct SettingsSeparator: View {
    var body: some View {
        Rectangle()
            .fill(CopyoTheme.separator)
            .frame(height: 0.5)
    }
}

/// 普通行：`min-height 40`、`padding 7 12`、`gap 10`；主文 13pt `label`，副文 10 / 14 `labelMeta`
struct SettingsRow<Lead: View, Trailing: View>: View {
    var title: Text
    var subtitle: Text?
    var titleColor: Color = CopyoTheme.label
    /// 点图标砖与文字区时执行（开关行用它实现「点整行切换」）。只挂在左侧、不罩住右侧控件：
    /// 罩住的话点开关本身会被控件和手势各处理一次，等于没点
    var labelTapAction: (() -> Void)?
    @ViewBuilder var lead: Lead
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            if let labelTapAction {
                label
                    .contentShape(Rectangle())
                    .onTapGesture(perform: labelTapAction)
            } else {
                label
            }
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(minHeight: 40)
    }

    private var label: some View {
        HStack(spacing: 10) {
            lead
            VStack(alignment: .leading, spacing: 1) {
                title
                    .font(.system(size: 13))
                    .foregroundStyle(titleColor)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    subtitle
                        .font(.system(size: 10))
                        .lineSpacing(2)
                        .foregroundStyle(CopyoTheme.labelMeta)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(title: Text, subtitle: Text? = nil, titleColor: Color = CopyoTheme.label, @ViewBuilder lead: () -> Lead) {
        self.init(title: title, subtitle: subtitle, titleColor: titleColor, lead: lead, trailing: { EmptyView() })
    }
}

/// 开关行。设计稿要求点整行和点开关都能切换（design-spec §04 特有交互）；
/// 开关用系统 `Toggle(.switch)`（第八节第 8 条），它的标签留给读屏，视觉上藏起来。
struct SettingsToggleRow<Lead: View>: View {
    var title: Text
    var subtitle: Text?
    @Binding var isOn: Bool
    @ViewBuilder var lead: Lead

    var body: some View {
        SettingsRow(title: title, subtitle: subtitle, labelTapAction: { isOn.toggle() }, lead: { lead }, trailing: {
            Toggle(isOn: $isOn) { title }
                .toggleStyle(.switch)
                .labelsHidden()
        })
    }
}

/// 26 × 26、圆角 7 的彩色图标砖；符号 15pt，前景按 `onBand` 规则取黑或白（第 32(b) 条同一条规则）。
/// 砖色一律系统语义色（第八节第 12、27 条），不用品牌红蓝。
struct SettingsTile: View {
    var color: Color
    var foreground: Color
    var symbol: String

    /// 常规写法：给 hex，前景按亮度自动取
    init(hex: String, symbol: String) {
        color = Color(platformColor: CopyoTheme.uiColor(hexString: hex) ?? CopyoTheme.sourceLocalUI)
        foreground = CopyoTheme.onBand(sourceHex: hex)
        self.symbol = symbol
    }

    /// 动态色（如 `destructive` 深浅两值）走这里，前景由调用方指定
    init(color: Color, foreground: Color = .white, symbol: String) {
        self.color = color
        self.foreground = foreground
        self.symbol = symbol
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(color)
            .frame(width: 26, height: 26)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(foreground)
            )
            .accessibilityHidden(true)
    }
}

/// 状态行的前导符号：设计稿是 18pt、线宽 1.5 的描边图标、不带砖（gen_v2.py:534-535、:541-542）；
/// 1.5 → `.regular`（第八节第 25 条；5.3）。
/// 放进 26pt 宽的框里，与上下行的图标砖左缘、文字起点对齐——画板上这类行没有框、文字比图标砖行左移 8，
/// 框留不留 3.11 标为设计未定，先照旧。
struct SettingsStatusIcon: View {
    var symbol: String
    var color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(color)
            .frame(width: 26, height: 26)
            .accessibilityHidden(true)
    }
}

/// 行右侧的只读值：12pt `labelMeta`
struct SettingsValue: View {
    var text: Text

    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(verbatim: String) { text = Text(verbatim: verbatim) }

    var body: some View {
        text
            .font(.system(size: 12))
            .foregroundStyle(CopyoTheme.labelMeta)
            .lineLimit(1)
            .fixedSize()
    }
}

/// 脚注：11 / 15 `labelMeta`，左右各缩 4
struct SettingsFooter: View {
    var text: Text

    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(text: Text) { self.text = text }

    var body: some View {
        text
            .font(.system(size: 11))
            .lineSpacing(2)
            .foregroundStyle(CopyoTheme.labelMeta)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// keycap：高 20、最小宽 20、左右 5、圆角 6、底 `fill2`、11 / 500 等宽、色 `labelMeta`（design-spec 3.6）
struct SettingsKeycap: View {
    var text: Text

    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(verbatim: String) { text = Text(verbatim: verbatim) }

    var body: some View {
        text
            .font(CopyoTheme.Dense.Font.keycap)
            .foregroundStyle(CopyoTheme.labelMeta)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20, maxHeight: 20)
            .background(CopyoTheme.fill2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .fixedSize()
    }
}
