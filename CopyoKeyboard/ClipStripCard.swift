import CopyoCore
import SwiftUI

/// 卡片条上的一张 dense 卡片（设计 07：宽 168，高度吃满卡片条）。
///
/// 排版按设计 3.1 的 dense 档：内距 10（`Metrics.cardPadDense`）、头部下间距 6、
/// 正文 3 行、圆角 12、整卡来源色淡染、实心类型角标。
/// **这些数字一个都不是新发明的**——角标走 `CopyoShared/UI/KindBadge.swift` 的 `dense`
/// （高 18 / 圆角 9 / 10pt），其余取 `CopyoTheme` 里已有的常量，与主应用的 `ClipCard` 对齐。
/// 这张卡不能复用 `ClipCard` 本体：那个文件在 `CopyoIOS` target 里，键盘编译不到，
/// 而且它吃的是 `ClipItem`（惰性 fault，见 `KeyboardClip`）。
struct ClipStripCard: View {
    let clip: KeyboardClip
    /// 外观。键盘的深浅跟宿主输入框走，不跟系统走，理由见 `CopyoTheme.keyCap(for:)`
    let scheme: ColorScheme
    /// 轻点：插入或给提示，由上层按 `clip.insertion` 决定
    let onTap: () -> Void
    /// 长按：在 330pt 之内弹预览浮层
    let onLongPress: () -> Void

    /// 卡片宽（设计 07）
    var width: CGFloat = 168
    /// 头部与正文之间的间距（设计 3.1 dense）
    var headerSpacing: CGFloat = 6
    /// 正文行数（设计 3.1 dense）
    var lineLimit: Int = 3

    /// 长按到弹预览之间的等待。比 `KeyCap` 的连发阈值（450ms）短：那一颗是「按住不放会连删」，
    /// 宁可迟一点；这一张是「按住看一眼」，迟了会先被误认成没反应而松手
    private static let previewHoldDuration = 0.4

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, headerSpacing)
            content
            // 正文短的时候把卡片顶到上边，不要让三行的空白把它撑成居中
            Spacer(minLength: 0)
        }
        .padding(CopyoTheme.Metrics.cardPadDense)
        .frame(width: width)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(clip.tintColor(for: scheme))
        .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous))
        // 设计第四节：轻点卡片 scale .96 → 1 回弹。在键盘上这不是装饰——
        // 插入发生在宿主的输入框里，键盘这一侧如果一点反馈都没有，
        // 用户会以为没按到而再按一次，于是插进去两份
        .scaleEffect(isPressed ? 0.96 : 1)
        .animation(CopyoTheme.springAnimation, value: isPressed)
        .contentShape(RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous))
        .onTapGesture { tapped() }
        .onLongPressGesture(minimumDuration: Self.previewHoldDuration) {
            onLongPress()
        } onPressingChanged: { pressing in
            // 按下态借长按手势来出，不另装 `DragGesture`：那会和外面横向 `ScrollView`
            // 的拖动抢手势，表现是卡片条滑不动
            isPressed = pressing
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(Text(clip.insertion == nil ? "" : String(localized: "Tap to insert")))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text(String(localized: "Preview")), onLongPress)
    }

    private func tapped() {
        onTap()
        isPressed = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            isPressed = false
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: headerSpacing) {
            // 角标没有降级手段，被挤窄就直接截成「Cou…」（法语的 Couleur 就会这样）。
            // 右边那行有缩放和截断兜底，让它先让位——与 `ClipCard.header` 同一条理由
            KindBadge(kind: clip.kind, sourceHex: clip.sourceColorHex, dense: true)
                .fixedSize(horizontal: true, vertical: false)
            Text(verbatim: "\(clip.sourceName) · \(clip.relativeTime())")
                .font(CopyoTheme.Fonts.meta)
                .foregroundStyle(CopyoTheme.labelSecondary)
                .lineLimit(1)
                // 168 的卡片比主应用的 171 还窄一点，英文 `This iPhone · now` 原字号放不下；
                // 宁可缩小也要把时间显示全——卡片条上最有用的信息就是「哪条是刚复制的」
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(CopyoTheme.labelSecondary)
            }
        }
    }

    // MARK: - 正文

    @ViewBuilder
    private var content: some View {
        switch clip.kind {
        case .text: textContent
        case .richText: richTextContent
        case .link: linkContent
        case .color: colorContent
        case .image: imageContent
        case .file: fileContent
        }
    }

    private var textContent: some View {
        Text(clip.body)
            .font(clip.isMono ? CopyoTheme.Fonts.cardMono(dense: true) : CopyoTheme.Fonts.cardBody(dense: true))
            .foregroundStyle(CopyoTheme.label)
            .lineSpacing(CopyoTheme.cardLineSpacing(dense: true))
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var richTextContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(clip.displayTitle)
                .font(CopyoTheme.Fonts.cardBody(dense: true).bold())
                .foregroundStyle(CopyoTheme.label)
                .lineLimit(1)
            let remainder = richTextRemainder
            if !remainder.isEmpty {
                Text(remainder)
                    // 富文本正文用专用的 sec2（比元信息行的 label.secondary 深一档），
                    // 见设计 CopyoCard 的 sec2
                    .font(CopyoTheme.Fonts.cardBody(dense: true))
                    .foregroundStyle(CopyoTheme.cardBodySecondary)
                    .lineSpacing(CopyoTheme.cardLineSpacing(dense: true))
                    .lineLimit(lineLimit - 1)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 富文本去掉首行之后的正文。`ClipItem` 有同名派生值，但那是 `CopyoIOS` 的扩展，
    /// 这里只有摊平后的 `body`（已截到 240 字），所以就地再切一次——240 字上的
    /// 一次 split 每帧重算也不值得缓存
    private var richTextRemainder: String {
        let lines = clip.body.split(separator: "\n", omittingEmptySubsequences: false)
        guard let index = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return ""
        }
        return lines[(index + 1)...].joined(separator: "\n")
    }

    private var linkContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(linkTitle)
                .font(CopyoTheme.Fonts.cardBody(dense: true).weight(.semibold))
                .foregroundStyle(CopyoTheme.label)
                .lineSpacing(CopyoTheme.cardLineSpacing(dense: true))
                .lineLimit(lineLimit - 1)
            if let domain = clip.linkDomain {
                Text(domain)
                    .font(CopyoTheme.Fonts.linkDomain)
                    .foregroundStyle(CopyoTheme.accent)
                    .lineLimit(1)
                    // `developer.apple.com` 在放大档位下会被截成「develop…」，
                    // 而这一行的全部价值就是认出这是哪个站。0.8 是全应用统一的下限
                    .minimumScaleFactor(0.8)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 去掉 scheme 与 `www.` 之后的链接文本。带着 `https://` 的话，168pt 的第一行
    /// 全被协议头吃掉，读不出这是什么页面——与 `ClipCard.linkTitle` 同一条理由与同一套规则
    private var linkTitle: String {
        guard let domain = clip.linkDomain else { return clip.body }
        var stripped = clip.body
        for prefix in ["https://", "http://"] where stripped.hasPrefix(prefix) {
            stripped.removeFirst(prefix.count)
        }
        if stripped.hasPrefix("www.") { stripped.removeFirst(4) }
        // 只有域名、没有路径时就别把域名写两遍（下面那一行已经是域名了）
        return stripped == domain || stripped == "\(domain)/" ? domain : stripped
    }

    private var colorContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: CopyoTheme.Radius.inner, style: .continuous)
                .fill(Color(hexString: clip.body) ?? CopyoTheme.fill)
                .frame(height: CopyoTheme.Metrics.colorSwatchDense)
                .frame(maxWidth: .infinity)
            Text(clip.body)
                .font(.system(.footnote, design: .monospaced, weight: .semibold))
                .foregroundStyle(CopyoTheme.label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// **不画缩略图，画占位块。**
    ///
    /// 解一张图要读 `imageData`（externalStorage），而 Mac 同步来的一张 5K 截图解出来约 59MB，
    /// 键盘的预算按 30MB 规划。降采样（`CGImageSourceCreateThumbnailAtIndex`）能把它压下去，
    /// 但这里连那个都不值得做：**图片根本插不进宿主文稿**（`textDocumentProxy` 只有
    /// `insertText(_:)`），所以这张卡片唯一的职责是说清「这条在这儿用不了，去 Copyo 里复制」——
    /// 缩略图不改变这个结论，却要拿键盘最缺的那样资源去换。
    /// 设计 07 的 `kbStrip` 四条样例里也没有图片条目。
    /// 占位画法与小组件、以及 `ClipCard` 在「iCloud 资产还没下载」时画的是同一个。
    private var imageContent: some View {
        ZStack {
            CopyoTheme.fill
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(CopyoTheme.labelTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: CopyoTheme.Metrics.thumbnailDense)
        .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Radius.inner, style: .continuous))
    }

    private var fileContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(clip.displayTitle)
                .font(CopyoTheme.Fonts.cardBody(dense: true).weight(.semibold))
                .foregroundStyle(CopyoTheme.label)
                .lineLimit(1)
                // 文件名从中间截：`Q3-复盘.key` 这种后缀比前缀更能认出是什么东西
                .truncationMode(.middle)
            HStack(spacing: 3) {
                // 设计第五节：仅 Mac = `desktopcomputer`
                Image(systemName: "desktopcomputer")
                    .font(.system(.caption2, weight: .semibold))
                Text(String(localized: "Mac only"))
                    .font(.system(.caption2, weight: .semibold))
            }
            .foregroundStyle(CopyoTheme.labelSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(CopyoTheme.dynamic(light: CopyoTheme.rgb(0x000000, 0.06),
                                           dark: CopyoTheme.rgb(0xFFFFFF, 0.1)),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 旁白

    /// 一张卡片读成一句话，而不是「角标图形、角标文字、来源、时间、正文」五个停留点——
    /// 与 `ClipCard.accessibilityDescription` 同一条理由。卡片条是横向的，碎片多一倍
    /// 更难分辨哪一段属于哪张卡。
    private var accessibilityDescription: String {
        var parts = [KindPresentation.label(clip.kind), clip.sourceName, clip.relativeTime()]
        let body = clip.kind == .image ? "" : clip.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty {
            parts.append(String(body.prefix(120)))
        }
        if clip.isPinned {
            parts.append(String(localized: "Pinned"))
        }
        // 用逗号连接：三种语言的旁白都会在逗号处停顿，不必给每种语言各写一条格式串
        return parts.joined(separator: ", ")
    }
}
