import PasterCore
import SwiftUI

/// 详情页的预览块（design-spec 3.13）：radius 12、内距 12、来源淡染底，
/// 头部与卡片同构（角标 + 「来源 · 相对时间」+ 已固定 pin），正文按类型展开、不截断。
struct ClipDetailPreview: View {
    let item: ClipItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 10)
            content
        }
        .padding(PasterTheme.Metrics.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(item.tintColor,
                    in: RoundedRectangle(cornerRadius: PasterTheme.Radius.card, style: .continuous))
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 6) {
            KindBadge(item: item)
            Text(verbatim: "\(item.sourceDisplayName) · \(item.relativeTime)")
                .font(PasterTheme.Fonts.meta)
                .foregroundStyle(PasterTheme.labelSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if item.pinboard != nil {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(PasterTheme.labelSecondary)
            }
        }
    }

    // MARK: - 正文

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

    /// 全文，不截断。命令与代码走等宽（PasterCore 的 looksLikeCode 判定）。
    private var textContent: some View {
        Text(item.plainText ?? "")
            .font(item.isMono ? Self.monoBody : .body)
            .foregroundStyle(PasterTheme.label)
            .lineSpacing(4)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 富文本按 RTF 原样渲染（粗体、字号都保留）。
    private var richTextContent: some View {
        Group {
            if let attributed = richText {
                Text(attributed)
            } else {
                // RTF 解不出来时不能留空：退回纯文本，至少内容还在
                Text(item.plainText ?? "")
                    .font(.body)
            }
        }
        .foregroundStyle(PasterTheme.label)
        .lineSpacing(4)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// RTF 里带的是采集时那台机器的固定文字色（多半是黑），深色模式下会看不见。
    /// 去掉颜色让它跟随 label 色，字体与粗细保留。
    private var richText: AttributedString? {
        guard var attributed = item.richTextAttributed else { return nil }
        let ranges = attributed.runs.map(\.range)
        for range in ranges {
            attributed[range].foregroundColor = nil
            attributed[range].backgroundColor = nil
        }
        return attributed
    }

    private var linkContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(linkTitle)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(PasterTheme.label)
                .lineSpacing(4)
                .textSelection(.enabled)
            if let domain = item.linkDomain {
                Text(domain)
                    .font(.subheadline)
                    .foregroundStyle(PasterTheme.accent)
                    .lineLimit(1)
            }
            if let url = item.linkURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                        Text(String(localized: "Open in Safari"))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PasterTheme.accent)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(PasterTheme.fill, in: Capsule())
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 220pt 大色块 + hex / rgb() / hsl() 三个等宽胶囊（窄屏时自动折行）
    private var colorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(item.colorValue ?? PasterTheme.fill)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
            WrappingHStack(spacing: 8, lineSpacing: 8) {
                ForEach(Array(colorValueStrings.enumerated()), id: \.offset) { index, value in
                    Text(value)
                        .font(.system(.footnote, design: .monospaced))
                        .fontWeight(index == 0 ? .semibold : .regular)
                        .foregroundStyle(index == 0 ? PasterTheme.label : PasterTheme.labelSecondary)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(PasterTheme.fill, in: Capsule())
                }
            }
        }
    }

    private var colorValueStrings: [String] {
        var values = [item.displayBody]
        if let rgb = item.colorRGBString { values.append(rgb) }
        if let hsl = item.colorHSLString { values.append(hsl) }
        return values
    }

    /// 大图：保持比例，双指可缩放
    @ViewBuilder
    private var imageContent: some View {
        if let image = item.thumbnail {
            ZoomableImage(image: image)
        } else {
            // CloudKit 的图片资产还没下载下来
            ZStack {
                PasterTheme.fill
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(PasterTheme.labelTertiary)
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var fileContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.displayTitle)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(PasterTheme.label)
                .lineLimit(2)
                .truncationMode(.middle)
            HStack(spacing: 3) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 10, weight: .semibold))
                Text(String(localized: "Mac only"))
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(PasterTheme.labelSecondary)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(PasterTheme.dynamic(light: PasterTheme.rgb(0x000000, 0.06),
                                            dark: PasterTheme.rgb(0xFFFFFF, 0.1)),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(String(localized: "File contents stay on your Mac. Paster keeps the name so you can find it there."))
                .font(.footnote)
                .foregroundStyle(PasterTheme.labelSecondary)
                .lineSpacing(2)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 详情正文的等宽字体：跟着 Dynamic Type 缩放，回落 Menlo 由系统负责
    private static let monoBody = Font.system(.subheadline, design: .monospaced)

    private var linkTitle: String {
        let text = (item.plainText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var stripped = text
        for prefix in ["https://", "http://"] where stripped.hasPrefix(prefix) {
            stripped.removeFirst(prefix.count)
        }
        return stripped.isEmpty ? item.displayTitleLocalized : stripped
    }
}

// MARK: - 可缩放大图

/// 双指捏合放大、双击复位。详情页在 ScrollView 里，所以只放大不平移——
/// 平移手势会和纵向滚动打架，捏合本身与滚动不冲突。
private struct ZoomableImage: View {
    let image: UIImage

    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    /// 容器宽度，用来把图片框算成「等比缩到宽度以内、且不超过 360 高」
    @State private var containerWidth: CGFloat = 0

    private var displayScale: CGFloat { min(max(scale * pinch, 1), 4) }

    private static let maxHeight: CGFloat = 360

    /// 图片实际占的框。必须算成确切数值再交给 `.frame(width:height:)`：
    /// 只给 `scaledToFit` + `maxHeight` 的话，视图框仍是整行宽、图片在里面留白，
    /// 圆角与缩放裁切就都落在留白的边上了。
    private var displaySize: CGSize {
        let width = containerWidth > 0 ? containerWidth : 320
        let ratio = image.size.height > 0 ? image.size.width / image.size.height : 1
        guard ratio > 0 else { return CGSize(width: width, height: Self.maxHeight) }
        let fitted = CGSize(width: width, height: width / ratio)
        guard fitted.height > Self.maxHeight else { return fitted }
        return CGSize(width: Self.maxHeight * ratio, height: Self.maxHeight)
    }

    var body: some View {
        Color.clear
            .frame(height: displaySize.height)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                containerWidth = width
            }
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: displaySize.width, height: displaySize.height)
                    .scaleEffect(displayScale)
                    // 裁在原始框上：放大时图片不会溢出预览块
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .gesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in
                        scale = min(max(scale * value.magnification, 1), 4)
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(PasterTheme.springAnimation) {
                    scale = scale > 1 ? 1 : 2
                }
            }
            .animation(PasterTheme.springAnimation, value: scale)
            .accessibilityLabel(String(localized: "Image"))
    }
}

// MARK: - 自动折行的横排

/// 一行放不下就换行的 HStack。颜色详情的三个色值胶囊在 iPhone 上横着放不下，
/// 设计稿画的是 440pt 宽的机型，真机窄一圈。
/// 只给详情页用，所以留在文件作用域内，免得和别的界面代理各自的同名布局撞车。
private struct WrappingHStack: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = layoutRows(subviews: subviews, maxWidth: maxWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + max(0, CGFloat(rows.count - 1)) * lineSpacing
        return CGSize(width: min(width, maxWidth == .infinity ? width : maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layoutRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layoutRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty, needed > maxWidth {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
