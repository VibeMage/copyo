import PasterCore
import SwiftUI

/// 设计 3.1：整卡淡染来源色 + 实心类型角标 + 「来源 · 相对时间」。
///
/// 六种内容布局全部在这里，历史 / Pinboard / 详情预览 / 分享扩展 / iPad 网格共用同一个组件——
/// 卡片是这套设计的主体，多写一份迟早会走形。
struct ClipCard: View {
    let item: ClipItem
    /// 紧凑版（Slide Over、键盘扩展、小组件）：内距 10、字号降一档、截断行数减半
    var dense: Bool = false
    /// 3pt accent 环（iPad 选中）
    var isSelected: Bool = false
    /// 2pt 环 + 5pt 光晕（硬件键盘焦点），与选中是两套独立视觉
    var isFocused: Bool = false
    /// 拖拽 / 长按预览：放大并倾斜
    var isLifted: Bool = false
    var isPressed: Bool = false
    /// 拖走之后留在原位的影子
    var isGhost: Bool = false

    private var pad: CGFloat { dense ? PasterTheme.Metrics.cardPadDense : PasterTheme.Metrics.cardPad }
    private var headerSpacing: CGFloat { dense ? 6 : 10 }
    private var lineLimit: Int { dense ? 3 : 6 }
    private var radius: CGFloat { PasterTheme.Radius.card }

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
        .animation(PasterTheme.springAnimation, value: isPressed)
        .animation(PasterTheme.springAnimation, value: isLifted)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 6) {
            KindBadge(item: item, dense: dense)
            Text(verbatim: "\(item.sourceDisplayName) · \(item.relativeTime)")
                .font(PasterTheme.Fonts.meta)
                .foregroundStyle(PasterTheme.labelSecondary)
                .lineLimit(1)
                // 设计稿按 440pt 画布画的列宽 194，真机 iPhone 只有 171——
                // 英文的 `This iPhone · now` 在原字号下放不下，宁可缩到 9.4pt 也要把时间显示全
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if item.pinboard != nil {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(PasterTheme.labelSecondary)
            }
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
            .font(item.isMono ? PasterTheme.Fonts.cardMono(dense: dense) : PasterTheme.Fonts.cardBody(dense: dense))
            .foregroundStyle(PasterTheme.label)
            .lineSpacing(PasterTheme.cardLineSpacing(dense: dense))
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var richTextContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            let title = item.richTextTitleLine
            if !title.isEmpty {
                Text(title)
                    .font(PasterTheme.Fonts.cardBody(dense: dense).bold())
                    .foregroundStyle(PasterTheme.label)
                    .lineLimit(2)
            }
            let remainder = item.richTextRemainder
            if !remainder.isEmpty {
                Text(remainder)
                    .font(.system(size: dense ? 12 : 14))
                    // 富文本正文用专用的 sec2（比元信息行的 label.secondary 深一档），见设计 PasterCard sec2
                    .foregroundStyle(PasterTheme.cardBodySecondary)
                    .lineSpacing(PasterTheme.cardLineSpacing(dense: dense))
                    .lineLimit(max(1, lineLimit - 2))
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var linkContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(linkTitle)
                .font(PasterTheme.Fonts.cardBody(dense: dense).weight(.semibold))
                .foregroundStyle(PasterTheme.label)
                .lineSpacing(PasterTheme.cardLineSpacing(dense: dense))
                .lineLimit(dense ? 2 : 3)
            if let domain = item.linkDomain {
                Text(domain)
                    .font(PasterTheme.Fonts.linkDomain)
                    .foregroundStyle(PasterTheme.accent)
                    .lineLimit(1)
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
            RoundedRectangle(cornerRadius: PasterTheme.Radius.inner, style: .continuous)
                .fill(item.colorValue ?? PasterTheme.fill)
                .frame(height: dense ? PasterTheme.Metrics.colorSwatchDense : PasterTheme.Metrics.colorSwatch)
                .frame(maxWidth: .infinity)
            Text(item.displayBody)
                .font(.system(size: dense ? 13 : 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(PasterTheme.label)
                .lineLimit(1)
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
                    PasterTheme.fill
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundStyle(PasterTheme.labelTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: dense ? PasterTheme.Metrics.thumbnailDense : PasterTheme.Metrics.thumbnail)
            .clipShape(RoundedRectangle(cornerRadius: PasterTheme.Radius.inner, style: .continuous))
            if let meta = item.imageMetadata, !dense {
                Text(meta)
                    .font(.system(size: 12))
                    .foregroundStyle(PasterTheme.labelSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var fileContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.displayTitle)
                .font(PasterTheme.Fonts.cardBody(dense: dense).weight(.semibold))
                .foregroundStyle(PasterTheme.label)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 3) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 10, weight: .semibold))
                Text("Mac only")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(PasterTheme.labelSecondary)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(PasterTheme.dynamic(light: PasterTheme.rgb(0x000000, 0.06),
                                            dark: PasterTheme.rgb(0xFFFFFF, 0.1)),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 状态环

    @ViewBuilder
    private var stateRings: some View {
        // 设计稿用 box-shadow 画外环，SwiftUI 里用负 padding 把描边推到卡片外沿
        if isSelected {
            RoundedRectangle(cornerRadius: radius + 1.5, style: .continuous)
                .stroke(PasterTheme.accent, lineWidth: 3)
                .padding(-1.5)
        } else if isFocused {
            ZStack {
                RoundedRectangle(cornerRadius: radius + 3.5, style: .continuous)
                    .stroke(PasterTheme.accent.opacity(0.35), lineWidth: 3)
                    .padding(-3.5)
                RoundedRectangle(cornerRadius: radius + 1, style: .continuous)
                    .stroke(PasterTheme.accent, lineWidth: 2)
                    .padding(-1)
            }
        }
    }
}

extension ClipCard {
    /// 瀑布流分列用的估算高度。只要相对大小对，两列高度就不会差太多；
    /// 精确高度得等布局跑完，那时候再分列就晚了。
    static func estimatedHeight(for item: ClipItem, width: CGFloat, dense: Bool) -> CGFloat {
        let pad = dense ? PasterTheme.Metrics.cardPadDense : PasterTheme.Metrics.cardPad
        let headerHeight: CGFloat = (dense ? 18 : 20) + (dense ? 6 : 10)
        let lineHeight: CGFloat = dense ? 17 : 20
        let maxLines = dense ? 3 : 6
        let charsPerLine = max(1, Int((width - pad * 2) / (dense ? 11 : 13)))

        var contentHeight: CGFloat
        switch item.kind {
        case .color:
            contentHeight = (dense ? PasterTheme.Metrics.colorSwatchDense : PasterTheme.Metrics.colorSwatch) + 8 + lineHeight
        case .image:
            contentHeight = (dense ? PasterTheme.Metrics.thumbnailDense : PasterTheme.Metrics.thumbnail)
                + (dense ? 0 : 8 + 16)
        case .file:
            contentHeight = lineHeight + 6 + 18
        case .link:
            let lines = min(dense ? 2 : 3, max(1, item.displayTitle.count / charsPerLine + 1))
            contentHeight = CGFloat(lines) * lineHeight + 4 + 16
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
