import CopyoCore
import SwiftData
import SwiftUI

/// 详情页的预览块（design-spec 3.13）：radius 12、内距 12、来源淡染底，
/// 头部与卡片同构（角标 + 「来源 · 相对时间」+ 已固定 pin），正文按类型展开、不截断。
struct ClipDetailPreview: View {
    let item: ClipItem

    /// 去过色的富文本。解码很贵，只在换条目、或这条被原地改过之后重做，见 `decodeRichText()`
    @State private var richText: AttributedString?

    /// 「在 Safari 打开」胶囊：14pt 字与 30pt 高都不在系统样式表上，按 subheadline 缩
    @ScaledMetric(relativeTo: .subheadline) private var openLinkFontSize: CGFloat = 14
    @ScaledMetric(relativeTo: .subheadline) private var openLinkMinHeight: CGFloat = 30
    /// 色值胶囊的 30pt 高。里面的字是 footnote，两者必须按同一个样式缩才会一起长
    @ScaledMetric(relativeTo: .footnote) private var colorValueMinHeight: CGFloat = 30
    /// 「仅 Mac」小胶囊：10pt 图标 + 18pt 高都不在样式表上（与 `ClipCard` 同一套值）
    @ScaledMetric(relativeTo: .caption2) private var macOnlySymbolSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption2) private var macOnlyMinHeight: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 10)
            content
        }
        .padding(CopyoTheme.Metrics.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(item.tintColor,
                    in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous))
        // 按「条目标识 + 入库时间」重跑，两者缺一不可，见 `decodeRichText()`。
        // `ClipDetailScreen` 每次 body 重算都会新造一个 `ClipDetailPreview` 值，
        // 但 `@State` 认的是视图标识而不是这个值，所以解码不会跟着白跑一遍
        .task(id: RichTextKey(item: item)) { decodeRichText() }
    }

    /// 重解富文本的触发键。见 `decodeRichText()` 里为什么不能只认 `persistentModelID`
    private struct RichTextKey: Hashable {
        let id: PersistentIdentifier
        let createdAt: Date

        init(item: ClipItem) {
            id = item.persistentModelID
            createdAt = item.createdAt
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 6) {
            KindBadge(item: item)
            Text(verbatim: "\(item.sourceDisplayName) · \(item.relativeTime)")
                .font(CopyoTheme.Fonts.meta)
                .foregroundStyle(CopyoTheme.labelSecondary)
                .lineLimit(1)
                // 放大档位下这一行同样会顶出去，缩到 0.8 是全项目统一的下限（为法语定的）
                .minimumScaleFactor(0.8)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if item.pinboard != nil {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(CopyoTheme.labelSecondary)
                    // 这枚图钉是「已固定」的唯一提示，不能当装饰藏掉；给它一句话让旁白读得出来
                    .accessibilityLabel(String(localized: "Pinned"))
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

    /// 全文，不截断。命令与代码走等宽（CopyoCore 的 looksLikeCode 判定）。
    /// 长文本由 `ChunkedText` 分块，短文本仍然是原来那一个 `Text`。
    private var textContent: some View {
        ChunkedText(text: item.plainText ?? "")
            .font(item.isMono ? Self.monoBody : .body)
            .foregroundStyle(CopyoTheme.label)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 富文本按 RTF 原样渲染（粗体、字号都保留）。
    private var richTextContent: some View {
        Group {
            if let richText {
                Text(richText)
            } else {
                // 解不出来、以及解码还没跑完的第一帧，都退回纯文本：内容一模一样，只是还没上样式。
                // 这里不能留空——留空的话「打开详情先看到一片空白」比看到没样式的正文更像坏了
                ChunkedText(text: item.plainText ?? "")
                    .font(.body)
            }
        }
        .foregroundStyle(CopyoTheme.label)
        .lineSpacing(ChunkedText.defaultLineSpacing)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// RTF 里带的是采集时那台机器的固定文字色（多半是黑），深色模式下会看不见。
    /// 去掉颜色让它跟随 label 色，字体与粗细保留。
    ///
    /// 这件事必须**只做一次**。它原来是个计算属性：body 每重算一次，就要把 externalStorage
    /// 里的 RTF blob 整个读回来、建一份 `NSAttributedString`、再逐 run 写回属性——
    /// 滚动、转屏、弹删除确认框都会让它从头来一遍。
    ///
    /// 不学 `ImageMetadataCache` 挂一个全局 `NSCache`：那边一屏有十几张图要反复取，
    /// 得为此算内存上限；详情页同时只有一条条目在屏幕上，解码结果跟着视图生灭就够了。
    ///
    /// 不往后台队列挪：`NSAttributedString` 的 documentType 初始化器不保证线程安全，
    /// 而且 `item` 是 SwiftData 模型，只能在自己的 ModelContext（主线程）上读。
    ///
    /// **触发键是 `persistentModelID` + `createdAt`，只认前者不够。**
    /// `ClipSaver.insert` 命中去重时不新增条目，而是**原地改**已有的那条：
    /// `duplicate.rtfData = newItem.rtfData` 与 `duplicate.kindRaw = newItem.kindRaw`
    /// （它自己的注释写着「同一段文本这次可能带来不同的富文本表示（或不再有）」），
    /// 而 `persistentModelID` 一动不动。只认标识的话，详情页一直开着的时候
    /// （iPad 分栏、或者 Mac 重新复制同一段文字再同步下来）这里会一直画着上一份属性串，
    /// 而且再也不会自己醒过来。那条分支必定先写 `duplicate.createdAt = Date()`，
    /// 所以把入库时间并进键里就能兜住它——没有任何一条路会只改 `rtfData` 不改 `createdAt`。
    private func decodeRichText() {
        guard var attributed = item.richTextAttributed else {
            richText = nil
            return
        }
        for range in attributed.runs.map(\.range) {
            attributed[range].foregroundColor = nil
            attributed[range].backgroundColor = nil
        }
        richText = attributed
    }

    private var linkContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(linkTitle)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(CopyoTheme.label)
                .lineSpacing(ChunkedText.defaultLineSpacing)
                .textSelection(.enabled)
            if let domain = item.linkDomain {
                Text(domain)
                    .font(.subheadline)
                    .foregroundStyle(CopyoTheme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if let url = item.linkURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                            // 右边的文字已经说了「在 Safari 打开」，图标再读一遍是多余的停留
                            .accessibilityHidden(true)
                        Text(String(localized: "Open in Safari"))
                    }
                    .font(.system(size: openLinkFontSize, weight: .semibold))
                    .foregroundStyle(CopyoTheme.accent)
                    .padding(.horizontal, 12)
                    // 内距 + minHeight 而不是写死 30：默认档位下 14pt 行高只有 17，
                    // 仍然是 30 高的胶囊，放大档位下才撑开——写死 30 会把文字上下切掉
                    .padding(.vertical, 4)
                    .frame(minHeight: openLinkMinHeight)
                    .background(CopyoTheme.fill, in: Capsule())
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
                .fill(item.colorValue ?? CopyoTheme.fill)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
            WrappingHStack(spacing: 8, lineSpacing: 8) {
                ForEach(Array(colorValueStrings.enumerated()), id: \.offset) { index, value in
                    Text(value)
                        .font(.system(.footnote, design: .monospaced))
                        .fontWeight(index == 0 ? .semibold : .regular)
                        .foregroundStyle(index == 0 ? CopyoTheme.label : CopyoTheme.labelSecondary)
                        .lineLimit(1)
                        // `hsl(36 100% 52%)` 十七个等宽字符，放大档位下比整行还宽。
                        // `WrappingHStack` 会把它夹到行宽，这里再让文字自己缩回去
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .frame(minHeight: colorValueMinHeight)
                        .background(CopyoTheme.fill, in: Capsule())
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
                CopyoTheme.fill
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(CopyoTheme.labelTertiary)
            }
            // 占位块是定高的图片框，不是文字盒子，220 保持写死
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            // 整块只报一句「图片」。不这么做旁白会在这里读出符号名，用户听不出是什么
            .accessibilityElement()
            .accessibilityLabel(String(localized: "Image"))
        }
    }

    private var fileContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.displayTitle)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(CopyoTheme.label)
                .lineLimit(2)
                .truncationMode(.middle)
            HStack(spacing: 3) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: macOnlySymbolSize, weight: .semibold))
                Text(String(localized: "Mac only"))
                    .font(.system(.caption2, weight: .semibold))
            }
            .foregroundStyle(CopyoTheme.labelSecondary)
            .padding(.horizontal, 6)
            // 与 `ClipCard` 的同一枚胶囊保持一致：内距 + minHeight，写死 18 会把文字切掉
            .padding(.vertical, 1)
            .frame(minHeight: macOnlyMinHeight)
            .background(CopyoTheme.dynamic(light: CopyoTheme.rgb(0x000000, 0.06),
                                            dark: CopyoTheme.rgb(0xFFFFFF, 0.1)),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(String(localized: "File contents stay on your Mac. Copyo keeps the name so you can find it there."))
                .font(.footnote)
                .foregroundStyle(CopyoTheme.labelSecondary)
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

// MARK: - 长正文分块

/// 长正文的分块渲染。
///
/// 一条十万字的剪贴板交给单个 `Text`，SwiftUI 要把整串一次排版并测量；详情页外面只是一个普通
/// `ScrollView`，没有任何东西替它裁掉屏幕外的部分，于是「推入详情」这一下就是几百毫秒的僵直，
/// `.textSelection(.enabled)` 还要再为整串建一遍可选区。
///
/// 这里把正文切成若干块交给 `LazyVStack`，只有滚到的块才排版。
/// （`MasonryGrid` 也是把 `LazyVStack` 套进调用方的 `ScrollView` 里用的，同一套路。）
///
/// **代价：选择不跨块。** 拖选无法一路选到全文末尾——但详情页底部工具栏第一个按钮就是「复制」，
/// 要整条内容的人本来也不会靠手指拖选十万字；块内选择照常。预览 sheet 同理。
struct ChunkedText: View {
    let text: String
    /// 行距。块与块之间的间距必须与它相等，否则接缝处会比别处松一档
    var lineSpacing: CGFloat = ChunkedText.defaultLineSpacing

    /// 详情页正文的行距（设计稿给的是行高，SwiftUI 用行距表达）
    static let defaultLineSpacing: CGFloat = 4

    /// 每块的目标字数。切在行边界上，所以实际大小会在这个数上下浮动
    private static let chunkSize = 4_000
    /// 短于它就整串交给一个 `Text`。分块本身要花一次 split、多一层 `LazyVStack`，
    /// 绝大多数剪贴板只有几行字，为它们付这笔钱是倒贴
    private static let chunkingThreshold = 8_000

    /// 切分结果的备忘，见 `ChunkMemo`
    @State private var memo = ChunkMemo()

    var body: some View {
        if let chunks = memo.chunks(for: text) {
            LazyVStack(alignment: .leading, spacing: lineSpacing) {
                ForEach(chunks) { chunk in
                    Text(chunk.text)
                        .lineSpacing(lineSpacing)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            Text(text)
                .lineSpacing(lineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 切分结果的备忘。
    ///
    /// 切一遍的实际代价：`split` 要把整串按行走一趟，其中 `line.count` 是逐字形簇数的，
    /// 加起来就是一次全文扫描；`joined(separator:)` 再给每一块拷一份，合起来是第二份全文副本。
    /// 这件事**只值得做一次**。原来它是个计算属性、又正好在 body 里读，
    /// 于是滚动、转屏、弹删除确认框，每让 body 重算一次就整串重来一遍。
    ///
    /// 用 `@State` 持有的**引用类型**，而不是像 `richText` 那样 `@State` 属性 + `.task`：
    /// `.task` 要等第一帧画完才跑，而第一帧正是要省下来的那一帧——那一帧会拿整串去喂一个
    /// `Text`，恰恰是分块存在的理由。（富文本那边用 `.task` 是对的：它第一帧退回没样式的
    /// 纯文本，看着只是还没上样式；这边退回的是几百毫秒的僵直。）
    /// 引用类型才能在 body 里就地算好、当帧就用上——写 `@State` 属性会在视图更新期间改状态。
    private final class ChunkMemo {
        private var key: String?
        private var value: [Chunk]?

        /// `nil` = 这段正文不值得分块，整串走一个 `Text`（原来的路径，短内容逐像素不变）。
        ///
        /// `key == text` 这次比较本身：同一份 String 走的是指针相等的快路，
        /// 最坏也只是一次 memcmp，和上面那趟「全文扫描 + 全文副本」不在一个量级。
        func chunks(for text: String) -> [Chunk]? {
            if let key, key == text { return value }
            key = text
            // 不用 `text.count` 判长短：字符数要逐个切字形簇，为了决定该不该分块先扫一遍全文，
            // 短内容就白付了这笔钱。`utf8.count` 是现成的，而且只会比字符数大——
            // 宁可多切一篇 CJK 长文。过了门槛之后 `split` 本来就要整串走一趟，
            // 所以这道门槛省的是**短内容**那一次，不是长内容那一次
            value = text.utf8.count > ChunkedText.chunkingThreshold ? ChunkedText.split(text) : nil
            return value
        }
    }

    /// 按行边界切块。**不能**直接 `prefix(4000)` 硬切：切在一行中间，后半块会从行首重新排版，
    /// 折行位置和原文对不上；更糟的是可能把一个字形簇（emoji、组合字）劈成两半。
    ///
    /// 单独一行就超过一块的（压成一行的 JSON、minify 过的代码）原样留成一块——
    /// 要切开它只能切进行内，正是上面要避开的事。这类内容仍然会整行排版，是已知的剩余情况。
    private static func split(_ text: String) -> [Chunk] {
        var chunks: [Chunk] = []
        var pending: [Substring] = []
        var pendingCount = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if !pending.isEmpty, pendingCount + line.count > chunkSize {
                chunks.append(Chunk(id: chunks.count, text: pending.joined(separator: "\n")))
                pending = []
                pendingCount = 0
            }
            pending.append(line)
            // +1 是被 split 吃掉的那个换行符
            pendingCount += line.count + 1
        }
        if !pending.isEmpty {
            chunks.append(Chunk(id: chunks.count, text: pending.joined(separator: "\n")))
        }
        return chunks
    }

    /// 一块正文。`id` 用序号而不是内容：连着两段空行的文本会切出两块一模一样的字符串，
    /// 按内容做 id 会被 `ForEach` 当成同一个
    private struct Chunk: Identifiable {
        let id: Int
        let text: String
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
                withAnimation(CopyoTheme.springAnimation) {
                    scale = scale > 1 ? 1 : 2
                }
            }
            .animation(CopyoTheme.springAnimation, value: scale)
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
                let size = Self.clamped(subviews[index].sizeThatFits(.unspecified), to: bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    /// 放大档位下单个胶囊的理想宽度会超过整行。不夹一下的话它会按理想宽度摆出去、
    /// 直接被裁到预览块外面；夹到行宽之后它独占一行，再由文字的 `minimumScaleFactor` 往回缩。
    private static func clamped(_ size: CGSize, to maxWidth: CGFloat) -> CGSize {
        CGSize(width: min(size.width, maxWidth), height: size.height)
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
            let size = Self.clamped(subviews[index].sizeThatFits(.unspecified), to: maxWidth)
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
