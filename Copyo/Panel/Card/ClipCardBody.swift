import AppKit
import CopyoCore
import SwiftUI

/// 卡片正文区：按 kind 分六种画法（`gen_v2.py` 的 `body_text` / `body_link` / `body_color` /
/// `body_image` / `body_image_pending` / `body_files`）。外层给它剩下的全部高度（106pt，第 38 条）。
struct ClipCardBody: View {
    let item: ClipItem
    /// 搜索词。非空时正文里的命中处加 accent 22% 的底（01c：只加底，不改字色）
    var highlight: String = ""
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text, .richText:
            textBody
        case .link:
            linkBody
        case .color:
            // 解析失败的颜色条目（第 31 条）：淡染已由 `renderColorHex` 退回来源色，正文按普通文本卡画
            if let color = CopyoTheme.uiColor(hexString: item.plainText) {
                colorBody(Color(platformColor: color))
            } else {
                textBody
            }
        case .image:
            imageBody
        case .file:
            fileBody
        }
    }

    // MARK: - 文本 / 富文本

    /// 12/16，最多 6 行（第 38 条）；像代码的改 11/15 等宽 **Regular**（第 35 条）。
    /// 富文本也只画纯文本：卡片是 106pt 高的摘要，RTF 的字号与颜色在淡染底上只会互相打架。
    private var textBody: some View {
        let mono = isCodeLike
        return Text(highlighted(bodyText))
            .font(mono ? CopyoTheme.Dense.Font.mono : CopyoTheme.Dense.Font.body)
            .lineSpacing(mono ? ClipCardMetrics.monoLineSpacing : ClipCardMetrics.bodyLineSpacing)
            .lineLimit(CopyoTheme.Dense.bodyLineLimit)
            .foregroundStyle(CopyoTheme.label)
            .multilineTextAlignment(.leading)
    }

    /// 在正文里标出搜索命中（与面板过滤同一口径：不区分大小写、按本地化规则比较）
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let query = highlight.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return attributed }
        var searchRange = text.startIndex..<text.endIndex
        while let found = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange,
                                     locale: .current) {
            if let lower = AttributedString.Index(found.lowerBound, within: attributed),
               let upper = AttributedString.Index(found.upperBound, within: attributed) {
                attributed[lower..<upper].backgroundColor = CopyoTheme.accent.opacity(0.22)
            }
            searchRange = found.upperBound..<text.endIndex
        }
        return attributed
    }

    /// 不直接用 `item.isCodeLike`：它把整段 plainText 交给 `looksLikeCode`，那里先对全文 trim 再取前 4000 字，
    /// 几 MB 的日志每张卡在 LazyHStack 里重建一次就要整段拷贝一次。判断本来也只看开头，先截再判结果一致。
    private var isCodeLike: Bool {
        guard item.kind == .text || item.kind == .richText, let text = item.plainText else { return false }
        return ClipClassifier.looksLikeCode(String(text.prefix(4_000)))
    }

    /// 画板是 `white-space: pre-line`：保留换行。首尾的空行去掉，否则一段以空行开头的复制会让卡片看着像空的
    private var bodyText: String {
        let raw = item.plainText ?? ""
        return String(raw.prefix(ClipCardMetrics.bodyCharacterBudget))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 链接

    /// 标题位放 URL 本身（12 Medium，3 行），下面一行域名用 accent（11/15，1 行）
    private var linkBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(bodyText)
                .font(.system(size: 12, weight: .medium))
                .lineSpacing(ClipCardMetrics.bodyLineSpacing)
                .lineLimit(3)
                .foregroundStyle(CopyoTheme.label)
            if let domain = item.linkDomain {
                Text(domain)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(CopyoTheme.accent)
            }
        }
    }

    // MARK: - 颜色

    private func colorBody(_ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let swatch = RoundedRectangle(cornerRadius: CopyoTheme.Dense.thumbRadius, style: .continuous)
            swatch
                .fill(color)
                .overlay(swatch.strokeBorder(CopyoTheme.swatchRing, lineWidth: 0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(item.displayTitle)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(CopyoTheme.label)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(CopyoTheme.fill2, in: Capsule())
        }
    }

    // MARK: - 图片

    /// 缩略图走 `ThumbnailCache`（NSCache，按 imageHash 键），命中后 body 里不再解码。
    /// 取不到（CloudKit 资源还没下完、解码失败）时画 7.5.5 的占位：淡染底上居中 `photo`，
    /// 与预览浮层同一种画法，不留一块空白。
    private var imageBody: some View {
        let shape = RoundedRectangle(cornerRadius: CopyoTheme.Dense.thumbRadius, style: .continuous)
        return Group {
            if let thumbnail = ThumbnailCache.thumbnail(for: item) {
                Color.clear
                    .overlay {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                    }
                    .clipShape(shape)
            } else {
                Color.clear
                    .overlay {
                        Image(systemName: "photo")
                            // 画板线宽 1.4，比换算表最细一档还细，取 .regular（第 25 条「个别偏差单独调」）
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(CopyoTheme.labelTertiary)
                    }
            }
        }
        .overlay(shape.strokeBorder(CopyoTheme.swatchRing, lineWidth: 0.5))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 文件

    /// 三块叠放（前两块 fill2、最上面一块来源色）+ 首个文件名两行 + 「另外 N 个文件」（第 40、44 条）
    private var fileBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            fileStack
            Text(item.displayTitle)
                .font(CopyoTheme.Dense.Font.body)
                .lineSpacing(ClipCardMetrics.bodyLineSpacing)
                .lineLimit(2)
                // 画板是 `word-break: break-all`：文件名多半没有空格，按字符断，尾部省略
                .truncationMode(.tail)
                .foregroundStyle(CopyoTheme.label)
            let more = item.filePaths.count - 1
            if more > 0 {
                // 复数键（String Catalog 复数变体）：en `1 more file` / `%lld more files`（第 40 条）
                Text("\(more) more files")
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundStyle(contrast == .increased ? CopyoTheme.label : CopyoTheme.labelMeta)
            }
        }
    }

    private var fileStack: some View {
        ZStack(alignment: .topLeading) {
            fileSquare(fill: CopyoTheme.fill2).offset(x: 0, y: 6)
            fileSquare(fill: CopyoTheme.fill2).offset(x: 7, y: 3)
            fileSquare(fill: Color(platformColor: CopyoTheme.uiColor(hexString: item.renderColorHex)
                                   ?? CopyoTheme.sourceLocalUI))
                .overlay {
                    Image(nsImage: FileTypeIconCache.icon(forPath: item.filePaths.first))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 22, height: 22)
                }
                .offset(x: 14, y: 0)
        }
        .frame(width: 46, height: 38, alignment: .topLeading)
    }

    private func fileSquare(fill: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        return shape
            .fill(fill)
            .overlay(shape.strokeBorder(CopyoTheme.swatchRing, lineWidth: 0.5))
            .frame(width: 30, height: 30)
    }
}
