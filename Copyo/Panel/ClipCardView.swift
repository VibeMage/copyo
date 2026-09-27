import CopyoCore
import SwiftUI

/// 卡片在面板里的状态（design-spec 第八节：「选中」与「键盘焦点」合并为「当前卡」）
enum CardState: Equatable {
    case normal
    /// 当前卡，面板是 key window：2px accent + 7px @32% 光晕
    case current
    /// 当前卡，面板失焦：3px @45%
    case currentInactive
}

/// 卡片的一个读屏动作
struct CardAccessibilityAction: Identifiable {
    let name: String
    let perform: () -> Void
    var id: String { name }
}

/// ClipCard · dense（260 × 184，`gen_v2.py` 的 `card()`，design-spec 3.1 / 3.2 / 3.4）。
///
/// 三段竖排：头行 18（类型角标 + 「来源 · 时间」+ 已固定图钉）/ 正文（其余 106pt）/ 底行 20（来源图标）。
/// 整卡底色是来源淡染；颜色条目的淡染取剪贴内容自身的颜色（`renderColorHex`，7.4.2）。
///
/// 悬停、增强对比度、减弱透明度、减弱动态都在卡片内部就地处理，面板只需要告诉它「是不是当前卡」。
/// 当前卡的环与光晕画在卡片形状**外面**（最多外扩 7pt），放卡片的轨道要给上下左右留出这 7pt，否则会被裁掉。
struct ClipCardView: View {
    let item: ClipItem
    var state: CardState = .normal
    /// 悬停动作簇的图钉按钮：已固定时由调用方取消固定，未固定时由调用方弹 Pinboard 菜单
    var onPinButton: () -> Void = {}
    var onDelete: () -> Void = {}
    /// 相对时间按哪个时刻算。面板定时刷新这个值，时间才不会停在面板打开的那一刻（7.5.4）
    var now: Date = Date()
    /// 当前搜索词，正文命中处高亮（01c）
    var highlight: String = ""
    /// 排在「固定 / 删除」前面的读屏动作（复制、纯文本复制、预览）。由面板传入，
    /// 这样动作顺序与右键菜单一致（4.7.2），不必在外层再追加一串排在后面的动作
    var leadingActions: [CardAccessibilityAction] = []

    @State private var isHovering = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CopyoTheme.Dense.cardRadius, style: .continuous)
    }

    private var increasedContrast: Bool { contrast == .increased }
    private var isPinned: Bool { item.pinboard != nil }
    /// 淡染、角标、底行色块、文件卡顶块共用的那个色；nil 回退 `source.local`（第 30 条）
    private var renderColor: Color {
        Color(platformColor: CopyoTheme.uiColor(hexString: item.renderColorHex) ?? CopyoTheme.sourceLocalUI)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClipCardMetrics.sectionSpacing) {
            header
            ClipCardBody(item: item, highlight: highlight)
            footer
        }
        .padding(CopyoTheme.Dense.cardPadding)
        .frame(width: CopyoTheme.Dense.cardWidth, height: CopyoTheme.Dense.cardHeight)
        .background(background, in: shape)
        .overlay { outline }
        .overlay(alignment: .topTrailing) {
            if isHovering {
                ClipCardActionCluster(isPinned: isPinned, onPin: onPinButton, onDelete: onDelete)
                    .padding(8)
                    // 淡入带 2pt 下落（design-spec 4.6「动作簇淡入」）；减弱动态时 onHover 不包动画，这里自然瞬变
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: -2)),
                                            removal: .opacity))
            }
        }
        .background { currentRing }
        .contentShape(shape)
        .onHover { hovering in
            // 进 0.12s easeOut、出 0.10s easeIn（第 7 条）；淡染加深与描边随同一个事务过渡
            let animation: Animation? = reduceMotion
                ? nil
                : (hovering ? .easeOut(duration: 0.12) : .easeIn(duration: 0.10))
            withAnimation(animation) { isHovering = hovering }
        }
        .clipCardPointer()
        // 视图被移除时 SwiftUI 不补发 onHover(false)；复用同一视图身份时别把上一次的悬停态带回来
        .onDisappear { isHovering = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(isPinned ? String(localized: "Pinned") : "")
        .accessibilityAddTraits(state == .normal ? [] : .isSelected)
        .accessibilityActions {
            ForEach(leadingActions) { action in
                Button(action.name, action: action.perform)
            }
        }
        .accessibilityAction(named: isPinned ? String(localized: "Unpin") : String(localized: "Pin to Pinboard"),
                             onPinButton)
        .accessibilityAction(named: String(localized: "Delete"), onDelete)
    }

    // MARK: - 头行

    private var header: some View {
        HStack(spacing: ClipCardMetrics.headerSpacing) {
            KindBadge(item: item, dense: true)
            ClipCardMetaLine(source: sourceName,
                             time: timeText,
                             color: increasedContrast ? CopyoTheme.label : CopyoTheme.labelMeta)
            // 悬停时动作簇盖在这个位置上，图钉让位给簇里的 pin.fill 按钮（第 26 条）
            if isPinned && !isHovering {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CopyoTheme.accent)
            }
        }
        .frame(height: ClipCardMetrics.headerHeight)
    }

    private var sourceName: String {
        item.sourceAppName ?? String(localized: "Other Device")
    }

    private var timeText: String {
        RelativeTime.string(for: item.createdAt, reference: now)
    }

    // MARK: - 底行

    /// 右对齐的来源图标位。有 bundle ID 取 App 图标（`AppIconProvider` 按 ID 缓存）；
    /// 没有的（iPhone 存进来的条目）画一块来源色方片，与画板上的色块同形。
    private var footer: some View {
        HStack {
            Spacer(minLength: 0)
            if let bundleID = item.sourceAppBundleID {
                Image(nsImage: AppIconProvider.icon(forBundleID: bundleID))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: ClipCardMetrics.sourceIconSize, height: ClipCardMetrics.sourceIconSize)
            } else {
                let square = RoundedRectangle(cornerRadius: ClipCardMetrics.sourceIconRadius, style: .continuous)
                square
                    .fill(renderColor)
                    .overlay(square.strokeBorder(CopyoTheme.swatchRing, lineWidth: 0.5))
                    .frame(width: ClipCardMetrics.sourceIconSize, height: ClipCardMetrics.sourceIconSize)
            }
        }
        .frame(height: ClipCardMetrics.footerHeight)
    }

    // MARK: - 底色与描边

    /// 常态 12% / 20% 淡染，悬停 16% / 26%（第 7 条）；增强对比度淡染降到 0%，
    /// 来源身份只留给角标的实心色（design-spec 4.7.3，第 24 条）
    private var background: Color {
        increasedContrast ? CopyoTheme.bgCard : CopyoTheme.tint(sourceHex: item.renderColorHex, hover: isHovering)
    }

    /// 卡片形状**内侧**的细描边。当前卡的环整体替换它（design-spec 3.2：三态里 cring 不再绘制）。
    @ViewBuilder
    private var outline: some View {
        if state == .normal {
            if isHovering {
                shape.strokeBorder(renderColor.opacity(0.4), lineWidth: increasedContrast ? 1 : 0.5)
            } else if increasedContrast {
                shape.strokeBorder(CopyoTheme.separator, lineWidth: 1)
            } else {
                shape.strokeBorder(CopyoTheme.cardRing, lineWidth: 0.5)
            }
        }
    }

    /// 当前卡的环画在卡片**外面**，对应 CSS 的 `box-shadow: 0 0 0 Npx`（向外扩散、圆角随之放大）。
    /// key：2pt 实色 + 总扩散 7pt 的 32% 光晕（第 36(b) 条：7 是总量，露出来的光晕是 5pt）；
    /// 失焦：3pt @45%。增强对比度光晕提到 .60、失焦环提到 .70（第 24 条）。
    /// 用「放大的圆角矩形垫在卡片下面」画，卡片底是不透明淡染，盖住的部分自然看不见。
    @ViewBuilder
    private var currentRing: some View {
        ZStack {
            switch state {
            case .normal:
                EmptyView()
            case .current:
                ring(spread: 7, color: CopyoTheme.accent.opacity(increasedContrast ? 0.60 : 0.32))
                ring(spread: 2, color: CopyoTheme.accent)
            case .currentInactive:
                ring(spread: 3, color: CopyoTheme.accent.opacity(increasedContrast ? 0.70 : 0.45))
            }
        }
        // 环切换走统一的 spring（design-spec 4.6「选中 / 焦点环切换」），减弱动态时瞬变
        .animation(reduceMotion ? nil : CopyoTheme.springAnimation, value: state)
    }

    private func ring(spread: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: CopyoTheme.Dense.cardRadius + spread, style: .continuous)
            .fill(color)
            .padding(-spread)
    }

    // MARK: - 辅助功能

    /// 「类型，来源，时间，内容摘要」四段、顺序固定（design-spec 4.7.2，第 24 条）；已固定走 accessibilityValue
    private var accessibilityText: String {
        let kind = KindPresentation.label(item.kind)
        return String(localized: "\(kind), \(sourceName), \(timeText), \(accessibilitySummary)")
    }

    /// 摘要：文本读正文（换行读作空格，截到 120 字）；图片读「图片」；文件读首个文件名 + 另外 N 个；其余读 displayTitle
    private var accessibilitySummary: String {
        switch item.kind {
        case .image:
            return KindPresentation.label(.image)
        case .file:
            let more = item.filePaths.count - 1
            return more > 0
                ? "\(item.displayTitle), \(String(localized: "\(more) more files"))"
                : item.displayTitle
        case .text, .richText:
            return Self.summarize(item.plainText ?? "")
        case .link, .color:
            return item.displayTitle
        }
    }

    private static func summarize(_ text: String) -> String {
        let limit = ClipCardMetrics.accessibilitySummaryLimit
        // 先截一段再折叠空白，几 MB 的正文也只处理开头
        let words = text.prefix(limit * 4).split(whereSeparator: \.isWhitespace)
        let flat = words.joined(separator: " ")
        return flat.count > limit ? String(flat.prefix(limit)) + "…" : flat
    }
}
