import SwiftUI

/// 设置页与三个说明页共用的零件（设计 3.8）。
///
/// 这些形状在四个界面里重复出现，散着写必然会在圆角、行高、图标尺寸上走形——
/// 设计稿把「图标砖 30×30 / 行高 52 / 步骤序号圆 28」定得很死，集中一处才好对齐。
enum SettingsTint {
    /// 设计 04 里图标砖的底色，顺序与设计帧一致
    static let cloud = Color(uiColor: PasterTheme.rgb(0x0A84FF))
    static let question = Color(uiColor: PasterTheme.rgb(0xFF9F0A))
    static let bolt = Color(uiColor: PasterTheme.rgb(0xFF2D55))
    static let clipboard = Color(uiColor: PasterTheme.rgb(0x8E8E93))
    /// 「自动读取剪贴板」是设计 04 里没有的一行（04e 的「Paster 键盘」留给 Phase 2）。
    /// 原来借用了键盘那格的 #5856D6，会跟 04 的图标序列撞色；换成不在序列里的青色。
    static let autoRead = Color(uiColor: PasterTheme.rgb(0x30B0C7))
    static let clock = Color(uiColor: PasterTheme.rgb(0x34C759))
    static let code = Color(uiColor: PasterTheme.rgb(0x48484A))
    static let hand = Color(uiColor: PasterTheme.rgb(0x0A84FF))
    static let info = Color(uiColor: PasterTheme.rgb(0x8E8E93))
}

// MARK: - 设置行

/// 30 × 30 圆角砖 + 18pt 白色符号。设计 3.8 的「图标砖」。
struct SettingsIconTile: View {
    let symbol: String
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(color)
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: symbol)
                    // 设计 3.8 的砖内图标是 18pt。SF Symbol 的 point size 与设计稿的图标框不是
                    // 一一对应（符号自带留白），实拍下来 17 与设计的留白最接近。
                    .font(.system(size: 17, weight: .semibold))
                    // 分层配色会把砖上的白图标画成半透明，设计要的是纯白
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// 设置分组里的一行：图标砖 + 标题 +（可选）右侧值。
/// 行高固定 52，配合 `.settingsRow()` 的 16pt 左右内距使用。
struct SettingsRowLabel: View {
    let symbol: String
    let color: Color
    let title: String
    var detail: String?
    var detailColor: Color = PasterTheme.labelSecondary
    /// 用 Button 而不是 NavigationLink 推页面时系统不给披露箭头，得自己画
    var showsDisclosure = false

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconTile(symbol: symbol, color: color)
            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(PasterTheme.label)
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(.system(size: 17))
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
            }
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PasterTheme.labelTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 52)
    }
}

extension View {
    /// 设计 3.8：行高 52、左右内距 16、分隔线通栏（系统默认会缩进到文字，与设计不符）
    func settingsRow(leading: CGFloat = 16) -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: leading, bottom: 0, trailing: 16))
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }
}

// MARK: - 说明页容器

/// 三个说明页（04b / 04c / 04d）共用的滚动容器：页边距 20、顶部 8、inline 标题。
struct GuideScroll<Content: View>: View {
    var spacing: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PasterTheme.Metrics.pageInset)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(PasterTheme.bgGrouped)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 说明页的导语 / 脚注：15/21 与 13/18，左右各再缩 4pt（设计稿里正文比卡片窄一点）
struct GuideParagraph: View {
    let text: String
    var footnote = false

    var body: some View {
        Text(text)
            .font(.system(size: footnote ? 13 : 15))
            .lineSpacing(footnote ? 5 : 6)
            .foregroundStyle(PasterTheme.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }
}

/// radius 12 的白卡容器，说明页里所有分组都套它
struct GroupedCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PasterTheme.bgCard,
                    in: RoundedRectangle(cornerRadius: PasterTheme.Radius.group, style: .continuous))
    }
}

/// .5pt 分隔线。卡片里手工排版，用不了 List 的分隔线。
struct HairlineSeparator: View {
    var body: some View {
        Rectangle()
            .fill(PasterTheme.separator)
            .frame(height: 0.5)
    }
}

// MARK: - 步骤条目

/// 设计 3.8 的步骤条目：序号圆 28 + 标题 15 + 副文 13。
/// `below` 用来放步骤里的示意块（04d 第三步的「询问 / 拒绝 / 允许」）。
struct GuideStepRow<Below: View>: View {
    let number: Int
    let title: String
    var detail: String?
    @ViewBuilder var below: () -> Below

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PasterTheme.label)
                .frame(width: 28, height: 28)
                .background(PasterTheme.fill, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(PasterTheme.label)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(PasterTheme.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                below()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 单行步骤要与 28pt 序号圆居中对齐，多行则顶对齐：给标题一个 28 的最小高度即可
            .frame(minHeight: 28, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

extension GuideStepRow where Below == EmptyView {
    init(_ number: Int, title: String, detail: String? = nil) {
        self.init(number: number, title: title, detail: detail) { EmptyView() }
    }
}

// MARK: - 按钮

/// 行动主按钮：高 52、radius 14、accent 底、17 Semibold 白字（设计 3.8）
struct GuidePrimaryButton: View {
    let title: String
    var symbol: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(PasterTheme.accent,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// 内联行动胶囊：高 30、radius 15、fill 底、14 Semibold accent 字 + 披露箭头
struct InlineActionPill: View {
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(PasterTheme.accent)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(PasterTheme.fill, in: Capsule())
    }
}

// MARK: - 通道卡（04c）

/// 44 × 44 图标砖 + 标题 + 正文 +（可选）行动胶囊
struct GuideChannelCard<Action: View>: View {
    let symbol: String
    let symbolColor: Color
    let tileBackground: Color
    let title: String
    let message: String
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tileBackground)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(symbolColor)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PasterTheme.label)
                Text(message)
                    .font(.system(size: 15))
                    .lineSpacing(5)
                    .foregroundStyle(PasterTheme.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                action()
                    .padding(.top, 10)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PasterTheme.bgCard,
                    in: RoundedRectangle(cornerRadius: PasterTheme.Radius.group, style: .continuous))
    }
}

extension GuideChannelCard where Action == EmptyView {
    init(symbol: String, symbolColor: Color, tileBackground: Color, title: String, message: String) {
        self.init(symbol: symbol,
                  symbolColor: symbolColor,
                  tileBackground: tileBackground,
                  title: title,
                  message: message) { EmptyView() }
    }
}
