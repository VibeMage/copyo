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
        let width = CopyoTheme.Dense.previewWidth
        let gap = CopyoTheme.Dense.previewGap
        let screenTop = panel.screen?.visibleFrame.maxY ?? panel.frame.maxY + CopyoTheme.Dense.previewMaxHeight
        let room = screenTop - panel.frame.maxY - gap * 2
        let maxHeight = max(160, min(CopyoTheme.Dense.previewMaxHeight, room))

        hosting.rootView = AnyView(PreviewContentView(item: item, maxHeight: maxHeight))
        // 不用 fittingSize：内容里有 ScrollView，它的理想高度是 0，会把窗口压成最小值
        let height = min(maxHeight, max(160, PreviewContentView.preferredHeight(for: item)))
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

    func hide() {
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
            style.lineSpacing = item.isCodeLike ? 4 : 7
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
                content = min(size.height, size.height * (contentWidth - 24) / size.width) + 24
            } else {
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
        var parts = [source, RelativeTime.string(for: item.createdAt)]
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
                    .lineSpacing(item.isCodeLike ? 4 : 7)
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

    @ViewBuilder
    private var imageContent: some View {
        if let data = item.imageData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: maxHeight - 72)
                .padding(12)
        } else {
            // 7.5.5：CloudKit 资源还没下完或解码失败时，淡染底 + 居中 photo 符号，不留一块空白
            Image(systemName: "photo")
                .font(.system(size: 34))
                .foregroundStyle(CopyoTheme.labelTertiary)
                .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    private var fileContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(item.filePaths.enumerated()), id: \.offset) { index, path in
                    HStack(spacing: 10) {
                        // 按扩展名取类型图标，不读文件本身（第 44 条）：沙盒下这些路径多半读不到
                        Image(nsImage: FileTypeIconCache.icon(forPath: path))
                            .resizable()
                            .frame(width: 28, height: 28)
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

/// 预览信息行里的图片尺寸。只读图片头，不解码整张图。
enum PreviewImageSize {
    static func of(_ item: ClipItem) -> CGSize? {
        guard let data = item.imageData,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: width, height: height)
    }
}
