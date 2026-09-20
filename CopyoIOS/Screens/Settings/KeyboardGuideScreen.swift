import CopyoCore
import SwiftUI

/// Copyo 键盘（设计 04e）。
///
/// 与设计稿有两处不同，都是平台限制逼出来的（预览那块的取舍另见 `KeyboardPreview`）：
///
/// 1. **底部按钮不叫「打开键盘设置」。** 「跳到系统设置」iOS 只开放
///    `UIApplication.openSettingsURLString` 这一个公开深链（`App-prefs:` 是私有 URL，
///    用了会被拒审），它落到的是 Copyo 自己那一格。
///    那一格里确实有「键盘」行和「允许完全访问」开关，也就是**第 3 步**；但第 1、2 步要去的
///    「设置 › 通用 › 键盘 › 键盘」没有任何办法跳。按钮做得到的就是第 3 步那一半，
///    所以沿用 04d 已有的「打开 Copyo 的系统设置」——写成「打开键盘设置」会多承诺一跳。
/// 2. **步骤 3 的附注把主语从「Copyo」收窄成「Copyo 键盘」。** 设计稿原文是「Copyo 不联网」，
///    而 Copyo 这个应用是联网的（CloudKit 私有数据库 + APNs 静默通知），按字面讲是假的。
///    收窄之后才是真的，理由与措辞跟 `CopyoKeyboard/ClipsUnavailableView.swift` 里那句一致
///    ——同一句话在两处出现，不能一处真一处假。
struct KeyboardGuideScreen: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        GuideScroll {
            KeyboardPreview()

            GuideParagraph(text: String(localized: "Switch to the Copyo keyboard in any text field and tap a card to type it — no jumping between apps."))

            GroupedCard {
                GuideStepRow(1, title: String(localized: "Settings › General › Keyboard › Keyboards"))
                HairlineSeparator()
                GuideStepRow(2, title: String(localized: "Tap “Add New Keyboard…” and choose Copyo"))
                HairlineSeparator()
                GuideStepRow(3,
                             title: String(localized: "Turn on “Allow Full Access”"),
                             detail: String(localized: "The keyboard extension needs it to read your history. The Copyo keyboard never goes online, and never records what you type."))
            }

            GuidePrimaryButton(title: String(localized: "Open Copyo's Settings"),
                               symbol: "arrow.up.forward.app") {
                if let url = SettingsLinks.appSettings { openURL(url) }
            }
        }
        .navigationTitle(String(localized: "Copyo Keyboard"))
    }
}

// MARK: - 键盘预览

/// 设计 04e 顶部那块预览：键盘底色的面板 + 搜索行 + 三张 dense 卡片。
///
/// **这是一幅画，不是键盘。** 真键盘在 `CopyoKeyboard/` 里，那些文件只属于键盘那个 target，
/// 主应用编译不到；`ClipStripCard` 吃的也是 `KeyboardClip`（键盘只读打开库之后摊平出来的值类型），
/// 主应用这边根本没有。所以照着设计稿另画一遍，画的目的只有一个：
/// 让用户在「设置 › 通用 › 键盘」那一串系统界面里认得出自己在找什么。
///
/// 两条无障碍上的处理共用同一个理由——**它没有任何一条信息不在下面那段说明里**：
/// - 整块 `accessibilityHidden`：读屏把三张假卡片的正文念出来，用户会以为那是自己的剪贴历史、
///   可以点进去用，而它们既不可点也不是真的。
/// - 动态字号封顶在默认档：卡片宽 150、条高 84 是按默认档的字摆出来的一幅画，
///   AX5 下一行 13pt 正文就有六十多点高，三张卡片会挤成看不出形状的碎片。
///   **只封上限不封下限**（`...(.large)`）——用户把字号调小时这幅画跟着变清爽，没有坏处。
private struct KeyboardPreview: View {
    /// 键盘的深浅在真机上跟宿主输入框的 `keyboardAppearance` 走（见 `CopyoTheme.keyCap(for:)`），
    /// 但这里没有宿主输入框，跟着应用自己的外观才不会在浅色页面里贴上一块深色方块
    @Environment(\.colorScheme) private var colorScheme

    /// 面板内距（设计 04e）
    var padding: CGFloat = 14
    /// 搜索行与卡片条之间、以及卡片之间的间距（设计 04e）
    var spacing: CGFloat = 8
    /// 搜索行高与圆角（设计 04e）
    var searchRowHeight: CGFloat = 30
    var searchRowRadius: CGFloat = 8
    /// 卡片宽（设计 6.6：04e 的 `kbCards` 是 dense、宽 150）
    var cardWidth: CGFloat = 150
    /// 卡片条高。84 = 内距 10 × 2 + 角标 18 + 头部下间距 6 + 两行 13pt 正文（18 + 行距 4 + 18）。
    /// 写成定值而不是 `@ScaledMetric`，是上面那条封顶的延伸：字号不长，盒子也不必长
    var cardHeight: CGFloat = 84

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            searchRow
            cardStrip
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CopyoTheme.keyboardBackground(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous))
        // 卡片条比面板宽，第三张会被裁掉半张——设计稿（`overflow:hidden`）就是这么画的，
        // 而且裁一半比只画两张更像那条能横向滑的卡片条
        .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityHidden(true)
    }

    /// 设计 04e 的搜索行只写了「搜索」两个字。真键盘那一行是「搜索历史」＋右端提示
    /// （见 `CopyoKeyboard/KeyboardSearchRow.swift`）；预览里按设计稿取短的那个，
    /// 150pt 的缩略图上摆不下那么多字。
    ///
    /// 这一行（以及下面卡片的定高）敢写死 `frame(height:)` 而不是走内距 + `minHeight`，
    /// 只因为整块预览的字号已经封顶在默认档：字不会长高，盒子也就切不到字。
    /// 这个前提一旦去掉，两处都要改回 `minHeight`
    private var searchRow: some View {
        HStack(spacing: 6) {
            // 设计第五节：搜索 = `magnifyingglass`
            Image(systemName: "magnifyingglass")
            Text(String(localized: "Search"))
        }
        .font(.footnote)
        .foregroundStyle(CopyoTheme.labelSecondary)
        .padding(.horizontal, 10)
        .frame(height: searchRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CopyoTheme.keyCap(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: searchRowRadius, style: .continuous))
    }

    private var cardStrip: some View {
        HStack(spacing: spacing) {
            ForEach(Self.clips) { clip in
                KeyboardPreviewCard(clip: clip, width: cardWidth, height: cardHeight)
            }
        }
        // 三张 150 的卡片加间距是 466，一定比面板宽。两个修饰的**顺序是关键**：
        // 先 `fixedSize` 让 HStack 按自己的 466 摆开（不然它会去压缩本来就是定宽的卡片），
        // 再套一个 `maxWidth: .infinity` 的框把**对外报出的宽度**收回到可用宽度。
        // 少了外面这一层，466 会一路顶出去，把整块面板撑得比页面还宽。
        // 溢出的部分留给面板的 `clipShape` 裁——设计要的正是露出半张
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 样例

    /// 设计 6.6 的 `kbCards` = `raw[0]`（验证码）/ `raw[9]`（地址）/ `raw[3]`（链接）。
    ///
    /// 时间一律用目录里现成的相对时间键。设计稿给 `raw[9]` 的是「昨天 09:30」，
    /// 那要为一幅插图新造一个写死时刻的本地化键——目录是手工维护的，
    /// 一个只在插图里出现的键要三种语言各养一份，不值得，换成「2 小时前」画面一样成立。
    private static var clips: [PreviewClip] {
        [
            PreviewClip(id: 0,
                        kind: .text,
                        sourceHex: "#8E8E93",
                        source: String(localized: "This iPhone"),
                        time: String(localized: "now"),
                        body: String(localized: "Your verification code is 482913. It expires in 5 minutes.")),
            PreviewClip(id: 1,
                        kind: .text,
                        sourceHex: "#8E8E93",
                        source: String(localized: "This iPhone"),
                        time: String(format: String(localized: "%lldh"), 2),
                        body: String(localized: "331 Caoxi North Rd, Tower B, 12F, Xuhui, Shanghai")),
            PreviewClip(id: 2,
                        kind: .link,
                        sourceHex: "#1B8EF1",
                        // Safari 是产品名，三种语言都一样，不进目录
                        source: "Safari",
                        time: String(format: String(localized: "%lldm"), 25),
                        // 网页标题是那一页自己的名字，不是界面文案，同样不进目录
                        body: "Adopting Liquid Glass | Apple Developer Documentation",
                        domain: "developer.apple.com"),
        ]
    }
}

/// 预览里一张卡片的内容。
private struct PreviewClip: Identifiable {
    let id: Int
    var kind: ClipKind
    var sourceHex: String
    var source: String
    var time: String
    var body: String
    /// 只有链接卡片有：正文底下那一行域名
    var domain: String?
}

/// 预览里的一张 dense 卡片（设计 3.1 的 dense 档）。
///
/// **不复用 `ClipCard`**：它吃的是 `ClipItem`，一个 SwiftData 托管对象。说明页没有
/// `ModelContext`，为了一幅插图往库里插三条假条目，就是把演示内容混进用户真实历史的最短路径。
/// 排版数字一个都不是新发明的：内距、圆角、行距、字号全取 `CopyoTheme`，角标直接用共用的
/// `KindBadge`，与 `ClipCard` 和键盘里的 `ClipStripCard` 是同一套值。
private struct KeyboardPreviewCard: View {
    let clip: PreviewClip
    let width: CGFloat
    let height: CGFloat

    /// 头部与正文之间的间距（设计 3.1 dense）
    var headerSpacing: CGFloat = 6
    /// 正文行数。真卡片 dense 档是 3 行，这里收到 2 行——`cardHeight` 的 84 就是按两行算出来的，
    /// 两个数必须一起改，否则第三行会被卡片下沿切掉
    var lineLimit: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, headerSpacing)
            content
            // 正文短的时候把卡片顶到上边，别让剩下的空白把它撑成居中
            Spacer(minLength: 0)
        }
        .padding(CopyoTheme.Metrics.cardPadDense)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(CopyoTheme.tint(sourceHex: clip.sourceHex))
        .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: headerSpacing) {
            KindBadge(kind: clip.kind, sourceHex: clip.sourceHex, dense: true)
                .fixedSize(horizontal: true, vertical: false)
            Text(verbatim: "\(clip.source) · \(clip.time)")
                .font(CopyoTheme.Fonts.meta)
                .foregroundStyle(CopyoTheme.labelSecondary)
                .lineLimit(1)
                // 150pt 的卡片比真机上的 171 还窄，法语的 `Cet iPhone · < 1 min` 原字号放不下；
                // 与 `ClipCard.metaLine` 同一条取舍：宁可缩到 0.8 也要把来源和时间都留住
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let domain = clip.domain {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: clip.body)
                    .font(CopyoTheme.Fonts.cardBody(dense: true).weight(.semibold))
                    .foregroundStyle(CopyoTheme.label)
                    .lineSpacing(CopyoTheme.cardLineSpacing(dense: true))
                    .lineLimit(lineLimit - 1)
                Text(verbatim: domain)
                    .font(CopyoTheme.Fonts.linkDomain)
                    .foregroundStyle(CopyoTheme.accent)
                    .lineLimit(1)
            }
        } else {
            Text(clip.body)
                .font(CopyoTheme.Fonts.cardBody(dense: true))
                .foregroundStyle(CopyoTheme.label)
                .lineSpacing(CopyoTheme.cardLineSpacing(dense: true))
                .lineLimit(lineLimit)
        }
    }
}
