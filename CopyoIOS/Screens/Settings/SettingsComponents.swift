import SwiftUI

/// 设置页与三个说明页共用的零件（设计 3.8）。
///
/// 这些形状在四个界面里重复出现，散着写必然会在圆角、行高、图标尺寸上走形——
/// 设计稿把「图标砖 30×30 / 行高 52 / 步骤序号圆 28」定得很死，集中一处才好对齐。
enum SettingsTint {
    /// 设计 04 里图标砖的底色，顺序与设计帧一致
    static let cloud = Color(uiColor: CopyoTheme.rgb(0x0A84FF))
    static let question = Color(uiColor: CopyoTheme.rgb(0xFF9F0A))
    static let bolt = Color(uiColor: CopyoTheme.rgb(0xFF2D55))
    static let clipboard = Color(uiColor: CopyoTheme.rgb(0x8E8E93))
    /// 「自动读取剪贴板」是设计 04 里没有的一行（04e 的「Copyo 键盘」留给 Phase 2）。
    /// 原来借用了键盘那格的 #5856D6，会跟 04 的图标序列撞色；换成不在序列里的青色。
    static let autoRead = Color(uiColor: CopyoTheme.rgb(0x30B0C7))
    static let clock = Color(uiColor: CopyoTheme.rgb(0x34C759))
    /// 系统搜索索引同样是设计 04 里没有的一行。刻意避开 #5856D6——那是 04e 留给
    /// 「Copyo 键盘」的紫色，占掉它等于把后面那一行的颜色先用了；这里取序列外的洋红紫。
    static let spotlight = Color(uiColor: CopyoTheme.rgb(0xAF52DE))
    static let code = Color(uiColor: CopyoTheme.rgb(0x48484A))
    static let hand = Color(uiColor: CopyoTheme.rgb(0x0A84FF))
    static let info = Color(uiColor: CopyoTheme.rgb(0x8E8E93))
}

// MARK: - 设置行

/// 30 × 30 圆角砖 + 18pt 白色符号。设计 3.8 的「图标砖」。
///
/// 砖与砖内符号都**不跟随**辅助功能字号：这是一块定尺的纯装饰色块，符号一放大就顶破
/// 30 × 30 的圆角砖，画出来是个缺角的图形。它整块已经 `accessibilityHidden`，
/// 放大对读屏用户也没有任何收益——真正需要长高的是包着它的那一行。
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
/// 行高默认档 52（放大档位下按内容长高），配合 `.settingsRow()` 的 16pt 左右内距使用。
struct SettingsRowLabel: View {
    let symbol: String
    let color: Color
    let title: String
    var detail: String?
    var detailColor: Color = CopyoTheme.labelSecondary
    /// 用 Button 而不是 NavigationLink 推页面时系统不给披露箭头，得自己画
    var showsDisclosure = false

    /// 52 的行高与 14 的箭头都落不到样式表上，一律按 `.body` 缩：
    /// 这一行里会长高的只有 17pt 的标题（正是 `.body`），三者用同一把尺子才不会各长各的。
    @ScaledMetric(relativeTo: .body) private var rowMinHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var disclosureSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconTile(symbol: symbol, color: color)
            Text(title)
                .font(.body)
                .foregroundStyle(CopyoTheme.label)
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
                    // 右值放大后必然撑破剩下的宽度。法语的「Bouton Action」缩到 0.8 还读得全，
                    // 截成「Bouton A…」就等于没显示
                    .minimumScaleFactor(0.8)
            }
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.system(size: disclosureSize, weight: .semibold))
                    .foregroundStyle(CopyoTheme.labelTertiary)
                    .accessibilityHidden(true)
            }
        }
        // 写死 `height` 会把折行的标题整条切掉，所以改成内距 + `minHeight` 兜底。
        // **默认字号下这一行也会长高，那不是回归**：393pt 机型上 inset-grouped 一格的内容宽只有
        // 353 − 16 − 16 = 321，扣掉图标砖、右值与箭头后留给标题的不到一半，英文
        // 「Allow Paste from Other Apps」默认档就要折三行（52 → 76），法语的
        // 「Comment Copyo enregistre les éléments」等三行折两行（52 → 56）。
        // 长高正是修复本身——旧的写死 52 是把标题截成「Allow Paste from Other A…」。
        // 谁只拿新旧截图比行高就改回 `.frame(height: 52)`，等于把那个截断重新装回去。
        .padding(.vertical, 8)
        .frame(minHeight: rowMinHeight)
        // 「标题 · 右值 · 箭头」读成一句，不是三个停留点
        .accessibilityElement(children: .combine)
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
            .padding(.horizontal, CopyoTheme.Metrics.pageInset)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(CopyoTheme.bgGrouped)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 说明页的导语 / 脚注：15/21 与 13/18，左右各再缩 4pt（设计稿里正文比卡片窄一点）
struct GuideParagraph: View {
    let text: String
    var footnote = false

    var body: some View {
        Text(text)
            // 13 → footnote、15 → subheadline，默认档逐像素不变
            .font(footnote ? .footnote : .subheadline)
            .lineSpacing(footnote ? 5 : 6)
            .foregroundStyle(CopyoTheme.labelSecondary)
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
        .background(CopyoTheme.bgCard,
                    in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.group, style: .continuous))
    }
}

/// .5pt 分隔线。卡片里手工排版，用不了 List 的分隔线。
struct HairlineSeparator: View {
    var body: some View {
        Rectangle()
            .fill(CopyoTheme.separator)
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

    /// 序号圆的 28 不在样式表上，按标题的 `.subheadline`（15pt）缩。
    /// 圆圈不跟着长的话，放大档位下 `Circle` 会把「3」上下各裁掉一截——
    /// 步骤号读不出来比不放大更糟。
    @ScaledMetric(relativeTo: .subheadline) private var numberDiameter: CGFloat = 28

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(CopyoTheme.label)
                .frame(width: numberDiameter, height: numberDiameter)
                .background(CopyoTheme.fill, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(CopyoTheme.label)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(CopyoTheme.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                below()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 单行步骤要与序号圆居中对齐，多行则顶对齐：给标题一个与圆同高的最小高度即可。
            // 这里必须用同一个 `numberDiameter`，写死 28 会在放大档位下与圆错位。
            .frame(minHeight: numberDiameter, alignment: .leading)
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

    /// 52 的按钮高按标题的 `.body`（17pt）缩，写死的话大字号下白字会被胶囊上下切掉
    @ScaledMetric(relativeTo: .body) private var buttonMinHeight: CGFloat = 52

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(.body, weight: .semibold))
                        // 符号只是标题的装饰，读屏念出「arrow up forward app」没有意义
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(.white)
            // 「Ouvrir les réglages de Copyo」放大后会折行，靠**纵向**内距撑开；
            // 默认档 20 的行高 + 28 内距 = 48 < 52，按钮仍是 52。
            // 横向一律不加内距——标签本来就在 `maxWidth: .infinity` 里居中，左右各 16 在短标题下
            // 根本看不出来，只会把长标题可用的宽度削掉 32：375pt 机型（SE 3 / 13 mini / 开了
            // 显示缩放的任意机型）说明页内容宽 335，04b 的
            // 「Add the “Save Clipboard” Shortcut」连符号带间距约 305，加了内距只剩 303，
            // 默认字号就折成两行，按钮 52 → 68。
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: buttonMinHeight)
            .background(CopyoTheme.accent,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// 内联行动胶囊：高 30、radius 15、fill 底、14 Semibold accent 字 + 披露箭头
struct InlineActionPill: View {
    let title: String

    /// 14 与 30 都落不到样式表上，一起按 `.subheadline` 缩：字与胶囊高必须走同一把尺子，
    /// 各缩各的会让放大后的文字顶破圆角。
    /// 箭头的 12 **在**表上（`.caption`），就走样式——`@ScaledMetric` 只留给落不到表上的尺寸。
    @ScaledMetric(relativeTo: .subheadline) private var fontSize: CGFloat = 14
    @ScaledMetric(relativeTo: .subheadline) private var pillMinHeight: CGFloat = 30

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: fontSize, weight: .semibold))
            Image(systemName: "chevron.right")
                .font(.system(.caption, weight: .semibold))
                .accessibilityHidden(true)
        }
        .foregroundStyle(CopyoTheme.accent)
        .padding(.horizontal, 12)
        // 默认档 14pt 的行高约 17，加 8 内距是 25 < 30，胶囊仍是 30
        .padding(.vertical, 4)
        .frame(minHeight: pillMinHeight)
        .background(CopyoTheme.fill, in: Capsule())
    }
}

// MARK: - 通道卡（04c）

/// 44 × 44 图标砖 + 标题 + 正文 +（可选）行动胶囊
///
/// 砖与 `SettingsIconTile` 同理：定尺装饰，整块已 `accessibilityHidden`，
/// 20pt 符号跟着放大会顶破 44 × 44，所以保留写死的 point size。长高的是右边那一列文字。
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
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(CopyoTheme.label)
                Text(message)
                    .font(.subheadline)
                    .lineSpacing(5)
                    .foregroundStyle(CopyoTheme.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                action()
                    .padding(.top, 10)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CopyoTheme.bgCard,
                    in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.group, style: .continuous))
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
