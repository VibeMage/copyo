import CopyoCore
import SwiftUI

/// 设计 3.1：整卡淡染来源色 + 实心类型角标 + 「来源 · 相对时间」。
///
/// 六种内容布局全部在这里，历史 / Pinboard / 详情预览 / 分享扩展 / iPad 网格共用同一个组件——
/// 卡片是这套设计的主体，多写一份迟早会走形。
struct ClipCard: View {
    let item: ClipItem
    /// 紧凑版（Slide Over、键盘扩展、小组件）：内距 10、字号降一档、截断行数减半
    var dense: Bool = false
    /// 2pt 环 + 5pt 光晕（硬件键盘焦点）
    var isFocused: Bool = false
    /// 拖拽 / 长按预览：放大并倾斜
    var isLifted: Bool = false
    var isPressed: Bool = false
    /// 拖走之后留在原位的影子
    var isGhost: Bool = false

    private var pad: CGFloat { dense ? CopyoTheme.Metrics.cardPadDense : CopyoTheme.Metrics.cardPad }
    private var headerSpacing: CGFloat { dense ? 6 : 10 }
    private var lineLimit: Int { dense ? 3 : 6 }
    private var radius: CGFloat { CopyoTheme.Radius.card }

    /// 12 / 14 都不在系统文本样式的默认点数上（caption 12 其实在，但和 14 配不成一对），
    /// 按 subheadline 缩：富文本的正文与首行标题要同档放大，不然标题跟着变大、正文不动。
    @ScaledMetric(relativeTo: .subheadline) private var richTextBodyRegular: CGFloat = 14
    @ScaledMetric(relativeTo: .subheadline) private var richTextBodyDense: CGFloat = 12
    private var richTextBodySize: CGFloat { dense ? richTextBodyDense : richTextBodyRegular }

    /// 「仅 Mac」小胶囊：10pt 图标 + 18pt 高都不在样式表上
    @ScaledMetric(relativeTo: .caption2) private var macOnlySymbolSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption2) private var macOnlyMinHeight: CGFloat = 18

    /// 当前动态字体相对默认档的倍率，只用来决定头部排一行还是两行（见 `headerStacks`）。
    /// 与 `HistoryScreen` 传给 `estimatedHeight` 的是同一个量，两边判据才能一致。
    @ScaledMetric(relativeTo: .subheadline) private var typeScale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, headerSpacing)
            content
        }
        .padding(pad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(item.tintColor)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay { stateRings }
        .opacity(isGhost ? 0.35 : 1)
        .scaleEffect(isPressed ? 0.96 : (isLifted ? 1.04 : 1))
        .rotationEffect(.degrees(isLifted ? -2 : 0))
        .shadow(color: isLifted ? .black.opacity(0.28) : .clear, radius: 16, y: 12)
        .animation(CopyoTheme.springAnimation, value: isPressed)
        .animation(CopyoTheme.springAnimation, value: isLifted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - 头部

    /// 头部一行还是两行。辅助功能字号下角标会宽到把元信息行挤没：
    /// 角标带 `fixedSize` 优先占位，元信息只能缩 20%（0.8 的下限），
    /// 实测 AX2 下整行只剩一个「…」——来源和时间全丢了，比不跟随放大还糟。
    ///
    /// 判据用 `typeScale` 而不是 `dynamicTypeSize.isAccessibilitySize`，是为了和
    /// `estimatedHeight` 共用同一条线：瀑布流估高拿不到 environment，只有调用方传进来的倍率，
    /// 两边各写一套迟早在边界档位上对不齐，那一列的高度就会算错一行。
    ///
    /// 1.5 这个值落在 subheadline 的两档之间：最大的非辅助档 xxxLarge 是 21/15 = 1.4，
    /// 第一个辅助档 AX1 是 25/15 ≈ 1.67，取中间任何数效果都一样。
    static func headerStacks(typeScale: CGFloat) -> Bool { typeScale >= 1.5 }

    @ViewBuilder
    private var header: some View {
        if Self.headerStacks(typeScale: typeScale) {
            // 两行：角标单独一行（右端留给图钉），元信息整行铺开，不再跟角标抢宽度
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    KindBadge(item: item, dense: dense)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    pinGlyph
                }
                metaLine
            }
        } else {
            HStack(spacing: 6) {
                // 角标本身没有降级手段，被挤窄就直接截成「Cou…」（法语的 Couleur 就会这样）。
                // 右边那行有缩放和截断兜底，让它先让位。
                KindBadge(item: item, dense: dense)
                    .fixedSize(horizontal: true, vertical: false)
                metaLine
                pinGlyph
            }
        }
    }

    private var metaLine: some View {
        Text(verbatim: "\(item.sourceDisplayName) · \(item.relativeTime)")
            .font(CopyoTheme.Fonts.meta)
            .foregroundStyle(CopyoTheme.labelSecondary)
            .lineLimit(1)
            // 设计稿按 440pt 画布画的列宽 194，真机 iPhone 只有 171——
            // 英文的 `This iPhone · now` 在原字号下放不下，宁可缩小也要把时间显示全。
            // 下限按最长的语言定：法语的 `Cet iPhone · 3 min` 比英文还长一截，
            // 0.85 会把时间截成 `3…`，反而把这一行里最有用的信息丢了
            .minimumScaleFactor(0.8)
            .allowsTightening(true)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var pinGlyph: some View {
        if item.pinboard != nil {
            Image(systemName: "pin.fill")
                .font(.caption)
                .foregroundStyle(CopyoTheme.labelSecondary)
        }
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text: textContent
        case .richText: richTextContent
        case .link: linkContent
        case .color: colorContent
        case .image: imageContent
        case .file: fileContent
        }
    }

    /// 卡片最多显示 6 行，没必要把一份十万字的剪贴板整个交给 Text 去测量。
    /// 600 字远超 6 行能显示的量，截断在视觉上不可见。
    private static let bodyRenderLimit = 600

    private var textContent: some View {
        Text(String((item.plainText ?? "").prefix(Self.bodyRenderLimit)))
            .font(item.isMono ? CopyoTheme.Fonts.cardMono(dense: dense) : CopyoTheme.Fonts.cardBody(dense: dense))
            .foregroundStyle(CopyoTheme.label)
            .lineSpacing(CopyoTheme.cardLineSpacing(dense: dense))
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var richTextContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            let title = item.richTextTitleLine
            if !title.isEmpty {
                Text(title)
                    .font(CopyoTheme.Fonts.cardBody(dense: dense).bold())
                    .foregroundStyle(CopyoTheme.label)
                    .lineLimit(2)
            }
            // 与 textContent 同一道 600 字闸门。之前这里漏了：一条二十万字的富文本
            // 每次布局都要把全文 split + join（`richTextRemainder`）再交给 Text 去测量，
            // 滚动瀑布流时每帧重来一次。卡片最多显示 4 行，截断看不出来。
            let remainder = String(item.richTextRemainder.prefix(Self.bodyRenderLimit))
            if !remainder.isEmpty {
                Text(remainder)
                    .font(.system(size: richTextBodySize))
                    // 富文本正文用专用的 sec2（比元信息行的 label.secondary 深一档），见设计 CopyoCard sec2
                    .foregroundStyle(CopyoTheme.cardBodySecondary)
                    .lineSpacing(CopyoTheme.cardLineSpacing(dense: dense))
                    .lineLimit(max(1, lineLimit - 2))
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var linkContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(linkTitle)
                .font(CopyoTheme.Fonts.cardBody(dense: dense).weight(.semibold))
                .foregroundStyle(CopyoTheme.label)
                .lineSpacing(CopyoTheme.cardLineSpacing(dense: dense))
                .lineLimit(dense ? 2 : 3)
            if let domain = item.linkDomain {
                Text(domain)
                    .font(CopyoTheme.Fonts.linkDomain)
                    .foregroundStyle(CopyoTheme.accent)
                    .lineLimit(1)
                    // 域名现在跟着 caption 一起放大，`developer.apple.com` 在放大档位下会被截成
                    // 「develop…」——那已经认不出是哪个站了，而这一行的全部价值就是认站。
                    // 先缩后截，0.8 是全应用统一的下限；`SharePreviewCard` 的同一行必须一起改
                    .minimumScaleFactor(0.8)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 链接卡片的标题。目前只有 URL 可用（网页标题两端都没有抓），所以去掉 scheme 与 www.
    /// 让路径部分能占满三行——带 `https://` 的话前半行全被协议头吃掉，读不出这是什么页面。
    private var linkTitle: String {
        let text = (item.plainText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let domain = item.linkDomain else { return text }
        let path = item.linkURL?.path ?? ""
        guard !path.isEmpty, path != "/" else { return domain }
        var stripped = text
        for prefix in ["https://", "http://"] where stripped.hasPrefix(prefix) {
            stripped.removeFirst(prefix.count)
        }
        if stripped.hasPrefix("www.") { stripped.removeFirst(4) }
        return stripped
    }

    private var colorContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: CopyoTheme.Radius.inner, style: .continuous)
                .fill(item.colorValue ?? CopyoTheme.fill)
                .frame(height: dense ? CopyoTheme.Metrics.colorSwatchDense : CopyoTheme.Metrics.colorSwatch)
                .frame(maxWidth: .infinity)
            Text(item.displayBody)
                .font(.system(dense ? .footnote : .subheadline, design: .monospaced, weight: .semibold))
                .foregroundStyle(CopyoTheme.label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var imageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let thumbnail = item.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    // CloudKit 的图片资产还没下载下来：给一个占位块，不要留空洞
                    CopyoTheme.fill
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(CopyoTheme.labelTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: dense ? CopyoTheme.Metrics.thumbnailDense : CopyoTheme.Metrics.thumbnail)
            .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Radius.inner, style: .continuous))
            if let meta = item.imageMetadata, !dense {
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(CopyoTheme.labelSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var fileContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.displayTitle)
                .font(CopyoTheme.Fonts.cardBody(dense: dense).weight(.semibold))
                .foregroundStyle(CopyoTheme.label)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 3) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: macOnlySymbolSize, weight: .semibold))
                Text("Mac only")
                    .font(.system(.caption2, weight: .semibold))
            }
            .foregroundStyle(CopyoTheme.labelSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .frame(minHeight: macOnlyMinHeight)
            .background(CopyoTheme.dynamic(light: CopyoTheme.rgb(0x000000, 0.06),
                                            dark: CopyoTheme.rgb(0xFFFFFF, 0.1)),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 状态环

    /// 设计 09 还画了一圈 3pt 的「选中」环，本轮**没有实现**：
    /// 这个应用里点一下卡片就是复制，没有多选、没有检查器面板，
    /// 也就没有任何动作以「当前选中哪张卡」为前提。留一个谁都不会去设的参数，
    /// 只会让下一个人以为它接好了。要做选中态时连同它的用途一起设计。
    @ViewBuilder
    private var stateRings: some View {
        // 设计稿用 box-shadow 画外环，SwiftUI 里用负 padding 把描边推到卡片外沿
        if isFocused {
            ZStack {
                RoundedRectangle(cornerRadius: radius + 3.5, style: .continuous)
                    .stroke(CopyoTheme.accent.opacity(0.35), lineWidth: 3)
                    .padding(-3.5)
                RoundedRectangle(cornerRadius: radius + 1, style: .continuous)
                    .stroke(CopyoTheme.accent, lineWidth: 2)
                    .padding(-1)
            }
        }
    }

    // MARK: - 旁白

    /// VoiceOver 把这张卡读成一句话，而不是「角标图形、角标文字、来源、时间、正文」五个停留点。
    ///
    /// 逐条读的问题不只是啰嗦：瀑布流是两个 `LazyVStack` 并排，光标会先走完左列再走右列，
    /// 碎片多一倍就更难分辨哪一段属于哪张卡。合成一句之后，一张卡就是一个停留点，
    /// 左右列的次序由 `MasonryGrid` 的排序优先级纠正。
    ///
    /// 正文只取前 120 字：读完一份十万字的剪贴板没有意义，用户要的是「这是哪一条」。
    private var accessibilityDescription: String {
        var parts = [KindPresentation.label(item.kind),
                     item.sourceDisplayName,
                     item.relativeTime]
        // 图片没有正文，读出来是空的；标题里已经有「图片」了
        let body = item.kind == .image ? "" : item.displayBody.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty {
            parts.append(String(body.prefix(120)))
        }
        if item.pinboard != nil {
            parts.append(String(localized: "Pinned"))
        }
        // 用逗号连接：三种语言的 VoiceOver 都会在逗号处停顿，不必给每种语言各写一条格式串
        return parts.joined(separator: ", ")
    }
}

extension ClipCard {
    /// 瀑布流分列用的估算高度。只要相对大小对，两列高度就不会差太多；
    /// 精确高度得等布局跑完，那时候再分列就晚了。
    ///
    /// `typeScale` 是当前动态字体相对默认档的倍率，调用方用
    /// `@ScaledMetric(relativeTo: .subheadline) var typeScale: CGFloat = 1` 取。
    /// 卡片里的字号现在会跟着辅助功能字号放大，这里的行高、头部高、每行字数如果还用
    /// 默认档的常数，放大档位下每张卡都会被低估同一个比例——两列各自累计误差，
    /// 贪心分列就会把大部分卡片堆到同一列，屏幕右半边空一大片。
    static func estimatedHeight(for item: ClipItem,
                                width: CGFloat,
                                dense: Bool,
                                typeScale: CGFloat = 1) -> CGFloat {
        let scale = max(1, typeScale)
        let pad = dense ? CopyoTheme.Metrics.cardPadDense : CopyoTheme.Metrics.cardPad
        let lineHeight: CGFloat = (dense ? 17 : 20) * scale
        // 辅助功能字号下头部换成两行（`headerStacks`），角标一行、元信息一行，中间 4pt。
        // 漏算这一行，放大档位下每张卡都少算一行的高度，两列又会错开——
        // 正是 `typeScale` 这个参数存在的理由，判据必须跟 `header` 用同一个。
        let badgeHeight: CGFloat = (dense ? 18 : 20) * scale
        let headerHeight: CGFloat = headerStacks(typeScale: scale)
            ? badgeHeight + 4 + lineHeight + (dense ? 6 : 10)
            : badgeHeight + (dense ? 6 : 10)
        let maxLines = dense ? 3 : 6
        // 字宽跟着字号一起放大，每行装得下的字数就变少——分母要一起缩放
        let charsPerLine = max(1, Int((width - pad * 2) / ((dense ? 11 : 13) * scale)))

        var contentHeight: CGFloat
        switch item.kind {
        case .color:
            contentHeight = (dense ? CopyoTheme.Metrics.colorSwatchDense : CopyoTheme.Metrics.colorSwatch) + 8 + lineHeight
        case .image:
            // 缩略图是定高的，不随字号变；只有下面那行元信息会放大
            contentHeight = (dense ? CopyoTheme.Metrics.thumbnailDense : CopyoTheme.Metrics.thumbnail)
                + (dense ? 0 : 8 + 16 * scale)
        case .file:
            contentHeight = lineHeight + 6 + 18 * scale
        case .link:
            let lines = min(dense ? 2 : 3, max(1, item.displayTitle.count / charsPerLine + 1))
            contentHeight = CGFloat(lines) * lineHeight + 4 + 16 * scale
        case .text, .richText:
            // 同样只看前 600 字：估高只要相对大小对就够，全文 split + count 会在每次布局重跑
            let text = String((item.plainText ?? "").prefix(bodyRenderLimit))
            let hardLines = text.split(separator: "\n", omittingEmptySubsequences: false).count
            let wrapped = max(hardLines, text.count / charsPerLine + 1)
            contentHeight = CGFloat(min(maxLines, max(1, wrapped))) * lineHeight
        }
        return pad * 2 + headerHeight + contentHeight
    }
}
