import CopyoCore
import SwiftUI
import UIKit

/// 设计 06 的内容预览卡：角标 + 「本机 · 现在」+ 正文 + 底部统计。
///
/// 角标与设计 token 直接用 `CopyoShared/UI/` 里的 `KindBadge` / `CopyoTheme`，不再另抄一份。
/// 但**卡片本体没有跟着共享**，与主应用的 `ClipCard` 仍是同一套视觉规格的两份实现：
/// `ClipCard` 吃的是 `ClipItem`（`@Model`，绑在 `ModelContext` 上），而且经 `ClipItem+Display`
/// 牵出 `ImageMetadataCache`——96MB 的 `totalCostLimit` + 全尺寸 `UIImage(data:)` 解码，
/// 那边自己记着一张同步来的 5K Mac 截图解码后约 59MB，塞进 ~30MB 预算的扩展就是一次 jetsam。
///
/// 两边用途也不同：这里展示的是**还没入库**的内容，没有来源色、没有固定标记、不接手势。
struct SharePreviewCard: View {
    let payload: SharePayload

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // 角标本身没有降级手段，被挤窄就直接截成「Cou…」（法语的 Couleur 就会这样）。
                // 右边那行有缩放和截断兜底，让它先让位
                //
                // 分享扩展存进来的条目一律没有来源色，`sourceHex` 恒为 nil，底色落到本机灰；
                // 也用不上 dense 变体——分享面板只有这一张标准卡
                KindBadge(kind: payload.kind, sourceHex: nil)
                    .fixedSize(horizontal: true, vertical: false)
                Text(metaLine)
                    .font(CopyoTheme.Fonts.meta)
                    .foregroundStyle(CopyoTheme.labelSecondary)
                    .lineLimit(1)
                    // 放大档位下「本机 · 现在」一定装不下这一行，宁可缩小也要把时间显示全；
                    // 0.8 是全应用统一的下限（按最长的法语定的）
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 10)

            content

            Text(payload.statsLine)
                .font(CopyoTheme.Fonts.meta)
                .foregroundStyle(CopyoTheme.labelSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 8)
        }
        .padding(CopyoTheme.Metrics.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            CopyoTheme.tint(sourceHex: nil),
            in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous)
        )
        // 整张卡读成一句，与主应用 `ClipCard` 同一处理
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    /// 旁白把这张卡读成一句话：类型、来源与时间、内容、统计。
    ///
    /// 逐条读的话是「角标图形、角标文字、本机 · 现在、正文、63 字 · 纯文本」五个停留点，
    /// 而这张卡不接任何手势——五个停留点没有一个是可操作的，纯属挡在「取消」和「保存」中间的噪音。
    ///
    /// 正文只取前 120 字：分享进来的可能是一整篇文章，用户要的是「这是哪一条」，不是听完全文。
    private var accessibilityDescription: String {
        var parts = [KindPresentation.label(payload.kind), metaLine]
        let body = accessibilityBody.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty {
            parts.append(String(body.prefix(120)))
        }
        parts.append(payload.statsLine)
        // 用逗号连接：三种语言的旁白都会在逗号处停顿，不必给每种语言各写一条格式串
        return parts.joined(separator: ", ")
    }

    /// 图片没有可读的正文，尺寸在 `statsLine` 里已经念过了
    private var accessibilityBody: String {
        switch payload {
        case .text(let string, _): string
        case .link(let url, let title): linkTitle(url: url, title: title)
        case .image: ""
        }
    }

    /// 「本机 · 现在」。内容还没入库，时间恒为「现在」，不必算相对时间。
    private var metaLine: String {
        "\(String(localized: "This iPhone")) · \(String(localized: "Now"))"
    }

    @ViewBuilder
    private var content: some View {
        switch payload {
        case .text(let string, _):
            switch payload.kind {
            case .color:
                colorContent(hex: string.trimmingCharacters(in: .whitespacesAndNewlines))
            default:
                textContent(string)
            }
        case .link(let url, let title):
            linkContent(url: url, title: title)
        case .image(let png, _, _):
            imageContent(png: png)
        }
    }

    private func textContent(_ string: String) -> some View {
        // 分享面板只有一张标准卡，`dense` 恒为 false
        Text(string)
            .font(isMono(string)
                  ? CopyoTheme.Fonts.cardMono(dense: false)
                  : CopyoTheme.Fonts.cardBody(dense: false))
            .foregroundStyle(CopyoTheme.label)
            .lineSpacing(5)
            .lineLimit(4)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isMono(_ string: String) -> Bool {
        (payload.kind == .text || payload.kind == .richText) && ClipClassifier.looksLikeCode(string)
    }

    private func linkContent(url: URL, title: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(linkTitle(url: url, title: title))
                .font(CopyoTheme.Fonts.cardBody(dense: false).weight(.semibold))
                .foregroundStyle(CopyoTheme.label)
                .lineSpacing(5)
                .lineLimit(3)
            if let domain = url.shareDomain {
                Text(domain)
                    .font(CopyoTheme.Fonts.linkDomain)
                    .foregroundStyle(CopyoTheme.accent)
                    .lineLimit(1)
                    // 与主应用 `ClipCard` 的链接域名同一处理：域名跟着 caption 放大后会被截成
                    // 「develop…」，而这一行的全部价值就是认出是哪个站，宁可按 0.8 先缩
                    .minimumScaleFactor(0.8)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 网页分享通常连标题一起给，有标题就用标题；没有就退回去掉 scheme 的 URL——
    /// 带 `https://` 的话前半行全被协议头吃掉，读不出这是什么页面。
    private func linkTitle(url: URL, title: String?) -> String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let domain = url.shareDomain else { return url.absoluteString }
        let path = url.path
        guard !path.isEmpty, path != "/" else { return domain }
        var stripped = url.absoluteString
        for prefix in ["https://", "http://"] where stripped.hasPrefix(prefix) {
            stripped.removeFirst(prefix.count)
        }
        if stripped.hasPrefix("www.") { stripped.removeFirst(4) }
        return stripped
    }

    private func colorContent(hex: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: CopyoTheme.Radius.inner, style: .continuous)
                .fill(Color(hexString: hex) ?? CopyoTheme.labelTertiary)
                .frame(height: 80)
                .frame(maxWidth: .infinity)
            Text(hex.uppercased())
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .foregroundStyle(CopyoTheme.label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private func imageContent(png: Data) -> some View {
        if let image = UIImage(data: png) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Radius.inner, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: CopyoTheme.Radius.inner, style: .continuous)
                .fill(CopyoTheme.labelTertiary.opacity(0.3))
                .frame(height: 160)
        }
    }
}

extension SharePayload {
    /// 卡片底部那行统计：`63 字 · 纯文本` / `链接` / `1284 × 2778 · PNG`
    var statsLine: String {
        switch self {
        case .text(let string, let rtf):
            if kind == .color { return String(localized: "Color") }
            // 英文单数要另给一个键，否则 1 个字符会显示成「1 characters」。
            // 口径与 ClipDetailInfoGroup 的字数行一致（中文两条译文相同）。
            let count = string.count
            if rtf == nil {
                return count == 1
                    ? String(localized: "1 character · Plain text")
                    : String(localized: "\(count) characters · Plain text")
            }
            return count == 1
                ? String(localized: "1 character · Rich text")
                : String(localized: "\(count) characters · Rich text")
        case .link:
            return String(localized: "Link")
        case .image(_, let width, let height):
            // 纯数字与 PNG 两端一样，不进字符串表
            return "\(width) × \(height) · PNG"
        }
    }
}

extension URL {
    /// 去掉 "www." 的主机名。CopyoCore 的 `ClipItem.linkDomain` 是同一套规则，
    /// 但那个要先有 ClipItem，分享面板在入库之前就要显示，只能从 URL 直接算。
    var shareDomain: String? {
        guard let host = host(), !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
