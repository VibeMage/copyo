import PasterCore
import SwiftUI
import UIKit

/// `ClipKind` 在分享面板里的名字与图标。
///
/// 主应用有 `KindPresentation`，但那是 target "Paster iOS" 的文件，扩展编译不到；
/// 名字与符号两处必须保持一致（design-spec 3.2 / 第五节）。
enum ShareKindPresentation {
    static func label(_ kind: ClipKind) -> String {
        switch kind {
        case .text: String(localized: "Text")
        // 设计 3.2 的英文角标是 `Rich`，与主应用的 KindPresentation 保持同一套文案
        case .richText: String(localized: "Rich")
        case .link: String(localized: "Link")
        case .color: String(localized: "Color")
        case .image: String(localized: "Image")
        case .file: String(localized: "File")
        }
    }

    static func symbol(_ kind: ClipKind) -> String {
        switch kind {
        case .text: "text.alignleft"
        case .richText: "textformat"
        case .link: "link"
        case .color: "circle.lefthalf.filled"
        case .image: "photo"
        case .file: "doc"
        }
    }
}

/// 分享面板里的类型角标。主应用 `KindBadge` 的精简版：
/// 分享扩展存进来的条目一律没有来源色，底色恒为本机灰，不需要 dense 变体。
struct ShareKindBadge: View {
    let kind: ClipKind

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: ShareKindPresentation.symbol(kind))
                .font(.system(size: 11, weight: .semibold))
                // 与主应用 KindBadge 同一处理：textformat 带中日韩本地化变体，
                // 不固定拉丁 locale 的话富文本角标会渲染成「格式」字形
                .environment(\.locale, Locale(identifier: "en"))
            Text(ShareKindPresentation.label(kind))
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(ShareTheme.onBand(sourceHex: nil))
        .padding(.leading, 6)
        .padding(.trailing, 7)
        .frame(height: 20)
        .background(
            Color(uiColor: ShareTheme.sourceLocalUI),
            in: RoundedRectangle(cornerRadius: ShareTheme.Metrics.badgeRadius, style: .continuous)
        )
    }
}

/// 设计 06 的内容预览卡：角标 + 「本机 · 现在」+ 正文 + 底部统计。
///
/// 与主应用的 `ClipCard` 是同一套视觉规格的两份实现（扩展编译不到主应用的 UI/），
/// 但用途不同：这里展示的是**还没入库**的内容，没有来源色、没有固定标记、不接手势。
struct SharePreviewCard: View {
    let payload: SharePayload

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                ShareKindBadge(kind: payload.kind)
                Text(metaLine)
                    .font(.system(size: 11))
                    .foregroundStyle(ShareTheme.labelSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 10)

            content

            Text(payload.statsLine)
                .font(.system(size: 11))
                .foregroundStyle(ShareTheme.labelSecondary)
                .lineLimit(1)
                .padding(.top, 8)
        }
        .padding(ShareTheme.Metrics.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ShareTheme.tint(sourceHex: nil),
            in: RoundedRectangle(cornerRadius: ShareTheme.Metrics.cardRadius, style: .continuous)
        )
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
        Text(string)
            .font(isMono(string) ? .system(size: 13, design: .monospaced) : .system(size: 15))
            .foregroundStyle(ShareTheme.label)
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ShareTheme.label)
                .lineSpacing(5)
                .lineLimit(3)
            if let domain = url.shareDomain {
                Text(domain)
                    .font(.system(size: 12))
                    .foregroundStyle(ShareTheme.accent)
                    .lineLimit(1)
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
            RoundedRectangle(cornerRadius: ShareTheme.Metrics.innerRadius, style: .continuous)
                .fill(Color(hexString: hex) ?? ShareTheme.labelTertiary)
                .frame(height: 80)
                .frame(maxWidth: .infinity)
            Text(hex.uppercased())
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(ShareTheme.label)
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
                .clipShape(RoundedRectangle(cornerRadius: ShareTheme.Metrics.innerRadius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: ShareTheme.Metrics.innerRadius, style: .continuous)
                .fill(ShareTheme.labelTertiary.opacity(0.3))
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
    /// 去掉 "www." 的主机名。PasterCore 的 `ClipItem.linkDomain` 是同一套规则，
    /// 但那个要先有 ClipItem，分享面板在入库之前就要显示，只能从 URL 直接算。
    var shareDomain: String? {
        guard let host = host(), !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
