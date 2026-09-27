import AppKit
import CopyoCore
import SwiftUI
import UniformTypeIdentifiers

/// 预览浮层（design-spec 第八节第 2 条）：面板上方的**独立子窗口**，宽 720、高随内容、最高 480，
/// 底边离面板顶 12。它不能成为 key window——按键仍由面板处理，所以面板不会因为它而失焦收起，
/// 也就不需要此前那套 `suppressAutoHide` 补丁。作为面板的子窗口，它跟着面板一起出现、一起消失。
@MainActor
final class PreviewWindowController {
    private final class PreviewPanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    private let window: PreviewPanel
    private let hosting: NSHostingView<AnyView>
    private(set) var isShown = false
    /// 图片尺寸还不在内存里时，等后台读出图片头再按真实比例重排一次窗口（7.5.5：尺寸不再在主线程上读 imageData 求）
    private var relayout: Task<Void, Never>?

    init() {
        window = PreviewPanel(contentRect: .zero,
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered,
                              defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hosting = NSHostingView(rootView: AnyView(EmptyView()))
        window.contentView = hosting
    }

    /// 打开或换成另一条（预览开着时在卡片间移动，内容跟着当前卡走，像 Quick Look）
    func show(_ item: ClipItem, above panel: NSWindow) {
        layout(item, above: panel, keepingHeight: isShown)
        scheduleRelayoutIfNeeded(for: item, above: panel)
    }

    /// - Parameter keepingHeight: 图片的像素尺寸还不在内存里时，是否沿用窗口现在的高度（见下）
    private func layout(_ item: ClipItem, above panel: NSWindow, keepingHeight: Bool) {
        let width = CopyoTheme.Dense.previewWidth
        let gap = CopyoTheme.Dense.previewGap
        let screenTop = panel.screen?.visibleFrame.maxY ?? panel.frame.maxY + CopyoTheme.Dense.previewMaxHeight
        let room = screenTop - panel.frame.maxY - gap * 2
        let maxHeight = max(160, min(CopyoTheme.Dense.previewMaxHeight, room))

        hosting.rootView = AnyView(PreviewContentView(item: item, maxHeight: maxHeight))
        // 不用 fittingSize：内容里有 ScrollView，它的理想高度是 0，会把窗口压成最小值。
        // 图片的像素尺寸还不在内存里时，已经开着的窗口先沿用现在的高度，等图片头读出来再重排：
        // 连按方向键在没见过的图片之间切换时，窗口不会在默认高度与真实高度之间来回跳。
        // 但不能低于尺寸未知时的默认高度（60 + 占位 200）：NSHostingView 会按内容的最小高度把窗口撑高，
        // 而且是顶边不动、底边往下长——从 160 高的文本预览切过来时，窗口会压到下面的面板上
        let preferred = PreviewContentView.preferredHeight(for: item)
        let keepsHeight = keepingHeight && item.kind == .image && PreviewImageSize.of(item) == nil
        let height = min(maxHeight, max(160, keepsHeight ? max(window.frame.height, preferred) : preferred))
        let frame = NSRect(x: panel.frame.midX - width / 2,
                           y: panel.frame.maxY + gap,
                           width: width,
                           height: height)
        window.setFrame(frame, display: true)
        window.level = panel.level
        if !isShown {
            panel.addChildWindow(window, ordered: .above)
            window.alphaValue = 0
            window.orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.14
                window.animator().alphaValue = 1
            }
            isShown = true
        }
    }

    /// 图片条目的窗口高度按像素比例算，而像素尺寸只从内存里取。多数时候卡片缩略图已经顺带记下了它；
    /// 还没有的话这一次先按默认高度（或沿用当前高度）出窗，同时在后台只读一次图片头——
    /// 几毫秒就回来，不必等大图整张解完——拿到尺寸再重排，信息行的「宽 × 高」也随之补上。
    /// 读不出来（CloudKit 资源还没下完、坏图）也重排一次，但不再沿用旧高度，改用尺寸未知时的默认高度，
    /// 与改动前缺图时的样子一致；这一次重排不再排新的读取，不会来回重试
    private func scheduleRelayoutIfNeeded(for item: ClipItem, above panel: NSWindow) {
        relayout?.cancel()
        relayout = nil
        guard item.kind == .image,
              PreviewImageSize.of(item) == nil,
              let request = ThumbnailCache.Request(item) else { return }
        relayout = Task { [weak self, weak panel] in
            _ = await ThumbnailCache.pixelSize(for: request)
            guard !Task.isCancelled, let self, let panel, self.isShown else { return }
            self.layout(item, above: panel, keepingHeight: false)
        }
    }

    func hide() {
        relayout?.cancel()
        relayout = nil
        guard isShown else { return }
        isShown = false
        window.parent?.removeChildWindow(window)
        window.orderOut(nil)
    }
}

// MARK: - 内容

/// 按 iOS 详情页骨架降到 Mac 档（第 2 条）：玻璃外壳圆角 20、内边距 12；内容块圆角 12、来源淡染底；
/// 底部 28 高的信息行「来源 · 相对时间 · 字数」，右侧只放两枚键帽提示，不要 iOS 那条工具栏。
struct PreviewContentView: View {
    let item: ClipItem
    let maxHeight: CGFloat

    /// 文字类正文的行距。非代码类是 13 / 20：SF 13pt 默认行高 16，再加 4（第八节第 2 条；gen_v2.py:375
    /// `font-size: 13px; line-height: 20px`）；代码类 12pt 等宽也是 4。preferredHeight 的估算与正文 Text 共用这一个值，
    /// 两边对不上窗高就会估偏
    private static let textLineSpacing: CGFloat = 4

    var body: some View {
        VStack(spacing: 8) {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(CopyoTheme.tint(sourceHex: item.renderColorHex),
                            in: RoundedRectangle(cornerRadius: CopyoTheme.Dense.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CopyoTheme.Dense.cardRadius, style: .continuous)
                    .strokeBorder(CopyoTheme.cardRing, lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Dense.cardRadius, style: .continuous))
            footer
        }
        .padding(12)
        .frame(width: CopyoTheme.Dense.previewWidth)
        .frame(maxHeight: maxHeight)
        .background(GlassBackground(cornerRadius: CopyoTheme.Dense.previewRadius))
        .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Dense.previewRadius, style: .continuous))
    }

    /// 按内容估出窗口该有多高（再由调用方夹在 160…480 之间）。
    /// 外壳内边距 12×2 + 底部信息行 28 + 间距 8，再加内容块本身。
    @MainActor
    static func preferredHeight(for item: ClipItem) -> CGFloat {
        let chrome: CGFloat = 12 * 2 + 28 + 8
        let contentWidth = CopyoTheme.Dense.previewWidth - 24
        let content: CGFloat
        switch item.kind {
        case .text, .richText:
            let font = item.isCodeLike ? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular) : NSFont.systemFont(ofSize: 13)
            let style = NSMutableParagraphStyle()
            style.lineSpacing = textLineSpacing
            // 只量前 4000 字：更长的反正超过 480，量全文是白费
            let text = String((item.plainText ?? "").prefix(4000)) as NSString
            let rect = text.boundingRect(with: NSSize(width: contentWidth - 40, height: .greatestFiniteMagnitude),
                                         options: [.usesLineFragmentOrigin, .usesFontLeading],
                                         attributes: [.font: font, .paragraphStyle: style])
            content = ceil(rect.height) + 32
        case .link:
            content = 120
        case .color:
            content = 160
        case .image:
            if let size = PreviewImageSize.of(item), size.width > 0 {
                // 不低于图片的 minHeight 120：矮于 120 的小图（图标、窄条截图）与特别宽的长图按比例算出来更矮，
                // 窗口给矮了，NSHostingView 会按内容最小高度把底边往下撑、压到面板上
                content = max(120, min(size.height, size.height * (contentWidth - 24) / size.width)) + 24
            } else {
                // 与占位的 minHeight 200 一致：尺寸未知时窗口不能比它矮（见 PreviewWindowController.layout）
                content = 200
            }
        case .file:
            content = CGFloat(item.filePaths.count) * 41 + 20
        }
        return chrome + content
    }

    private var footer: some View {
        HStack(spacing: 8) {
            KindBadge(item: item, dense: true)
            Text(verbatim: metaLine)
                .font(.system(size: 11))
                .foregroundStyle(CopyoTheme.labelMeta)
                .lineLimit(1)
            Spacer(minLength: 8)
            KeyHint(keys: "↩", label: String(localized: "Copy"))
            KeyHint(keys: String(localized: "Space"), label: String(localized: "Close"))
        }
        .padding(.horizontal, 4)
        .frame(height: 28)
    }

    private var metaLine: String {
        let source = item.sourceAppName ?? String(localized: "Other Device")
        // 参照时间取当前这一分钟的起点，与卡片轨道的 TimelineView(.everyMinute) 同一个钟：
        // 用 Date() 的话，跨过整分钟时预览写「12 分钟前」、下面的卡片还是「11 分钟前」
        let minute = Calendar.current.dateInterval(of: .minute, for: Date())?.start ?? Date()
        var parts = [source, RelativeTime.string(for: item.createdAt, reference: minute)]
        switch item.kind {
        case .image:
            if let size = PreviewImageSize.of(item) { parts.append("\(Int(size.width)) × \(Int(size.height))") }
        case .file:
            parts.append(String(localized: "\(item.filePaths.count) files"))
        default:
            parts.append(String(localized: "\(item.charCount) characters"))
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text, .richText:
            ScrollView {
                Text(item.plainText ?? "")
                    .font(item.isCodeLike ? .system(size: 12, design: .monospaced) : .system(size: 13))
                    .lineSpacing(Self.textLineSpacing)
                    .foregroundStyle(CopyoTheme.label)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
        case .link:
            VStack(alignment: .leading, spacing: 8) {
                Text(item.linkDomain ?? "")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CopyoTheme.label)
                Text(item.plainText ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(CopyoTheme.accent)
                    .textSelection(.enabled)
                    .lineLimit(6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        case .color:
            colorContent
        case .image:
            imageContent
        case .file:
            fileContent
        }
    }

    private var colorContent: some View {
        let hex = item.renderColorHex ?? ""
        return HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: CopyoTheme.Dense.thumbRadius, style: .continuous)
                .fill(Color(hexString: hex) ?? CopyoTheme.sourceLocal)
                .overlay(RoundedRectangle(cornerRadius: CopyoTheme.Dense.thumbRadius, style: .continuous)
                    .strokeBorder(CopyoTheme.swatchRing, lineWidth: 0.5))
                .frame(width: 180, height: 120)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: hex)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                if let rgb = rgbString(hex) {
                    Text(verbatim: rgb)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(CopyoTheme.labelSecondary)
                }
            }
            .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func rgbString(_ hex: String) -> String? {
        guard let color = CopyoTheme.uiColor(hexString: hex) else { return nil }
        let c = CopyoTheme.components(color)
        return "rgb(\(Int((c.r * 255).rounded())), \(Int((c.g * 255).rounded())), \(Int((c.b * 255).rounded())))"
    }

    /// 大图与卡片缩略图同一套（7.5.5）：body 里只查内存，读 externalStorage 与解码在后台。
    /// 大图还在解的那几帧先拿卡片那张缩略图顶上——同一张图、同一个版式，只是糊一点，
    /// 在卡片间左右换着看时不会每换一张都闪一下占位；连缩略图都没有才画占位，缩略图后到时自己换上
    /// （`previewStandIn`）。这个过渡态是规格外的补充，已提请在 7.5.18 的 7.5.5 行补记。
    @ViewBuilder
    private var imageContent: some View {
        let key = ThumbnailCache.key(for: item)
        let request = ThumbnailCache.Request(item)
        AsyncCachedImage(key: key,
                         cached: { ThumbnailCache.cachedPreview(forKey: key) },
                         load: {
                             guard let request else { return nil }
                             return await ThumbnailCache.preview(for: request)
                         },
                         retryToken: { ThumbnailCache.retryToken }) { preview in
            if let image = preview ?? ThumbnailCache.previewStandIn(forKey: key) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 120, maxHeight: maxHeight - 72)
                    .padding(12)
            } else {
                // 7.5.5：还没解出来、CloudKit 资源还没下完或解码失败时，淡染底 + 居中 photo 符号，不留一块空白
                Image(systemName: "photo")
                    .font(.system(size: 34))
                    .foregroundStyle(CopyoTheme.labelTertiary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
    }

    private var fileContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(item.filePaths.enumerated()), id: \.offset) { index, path in
                    HStack(spacing: 10) {
                        // 按扩展名取类型图标，不读文件本身（第 44 条）：沙盒下这些路径多半读不到。
                        // 类型表查询也在后台（7.5.5），查到之前图标位空着
                        let ext = FileTypeIconCache.extensionKey(forPath: path)
                        AsyncCachedImage(key: ext,
                                         cached: { FileTypeIconCache.cachedIcon(forExtension: ext) },
                                         load: { await FileTypeIconCache.icon(forExtension: ext) }) { icon in
                            if let icon {
                                Image(nsImage: icon)
                                    .resizable()
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: FileTypeIconCache.previewIconSize, height: FileTypeIconCache.previewIconSize)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: (path as NSString).lastPathComponent)
                                .font(.system(size: 13))
                                .lineLimit(1)
                            Text(verbatim: (path as NSString).deletingLastPathComponent)
                                .font(.system(size: 11))
                                .foregroundStyle(CopyoTheme.labelMeta)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                    }
                    .padding(.vertical, 6)
                    if index < item.filePaths.count - 1 {
                        Divider().opacity(0.6)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }
}

/// 预览信息行与窗口高度用的图片像素尺寸。只查内存（7.5.5）：以前这里在 body 里读整份 imageData 再解图片头，
/// 现在由缩略图 / 大图在后台解码时顺带读出、记在 `ThumbnailCache`。卡片在屏上时它的缩略图多半已经解过，
/// 所以通常一打开预览就有；还没有时返回 nil，调用方先出窗，后台读出图片头再重排（见 `PreviewWindowController.show`）。
enum PreviewImageSize {
    @MainActor
    static func of(_ item: ClipItem) -> CGSize? {
        ThumbnailCache.cachedPixelSize(for: item)
    }
}
