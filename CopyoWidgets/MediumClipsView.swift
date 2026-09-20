import SwiftUI

/// 中尺寸：最近四条排成 2 × 2（设计 08 / 3.16，样例见 design-spec 6.7）。
///
/// 每一格都是**独立的点按目标**，所以一格一个 `Button(intent:)`，
/// 而不是整张小组件一个 `.widgetURL`——后者只认整块，四格会指向同一条内容。
struct MediumClipsView: View {
    let snapshots: [ClipSnapshot]
    /// 这一帧代表的时刻，相对时间按它算
    let date: Date

    /// 格子之间的间距（设计 3.16 的 gap 8）
    var gap: CGFloat = 8

    /// 判据用 `dynamicTypeSize` 而不是 `ClipCard.headerStacks` 那种 `@ScaledMetric` 倍率：
    /// 那边是为了和瀑布流估高共用同一条线（估高拿不到 environment），这里没有第二个地方要对齐。
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 辅助功能字号下改成单列：中尺寸的高度是固定的（设计 3.16 记的是 364 × 170），
    /// 而一格里「一行正文 + 一行元信息」在 AX 档位上光字就比半格高。
    /// 单列两条——少看两条，好过四条各露半行字。
    private var columns: Int { dynamicTypeSize.isAccessibilitySize ? 1 : 2 }

    /// 始终两行，所以条数就是列数的两倍
    private var visible: [ClipSnapshot] {
        Array(snapshots.prefix(columns * 2))
    }

    var body: some View {
        VStack(spacing: gap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: gap) {
                    ForEach(row) { snapshot in
                        MediumClipCell(snapshot: snapshot, date: date)
                    }
                    // 条目数不是列数的整数倍时补空位：不补的话最后那一格会被拉成整行宽，
                    // 与上面一行对不齐
                    ForEach(Array(row.count..<columns), id: \.self) { _ in
                        Color.clear
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 按列数切块
    private var rows: [[ClipSnapshot]] {
        let items = visible
        return stride(from: 0, to: items.count, by: columns).map {
            Array(items[$0..<min($0 + columns, items.count)])
        }
    }
}

/// 2 × 2 里的一格：左侧来源色条 + 单行正文 + 「来源 · 时间」。
private struct MediumClipCell: View {
    let snapshot: ClipSnapshot
    let date: Date

    /// 设计 3.16：格子 radius 10、padding 8×10、内部 gap 8。
    /// 这几个数在 `CopyoTheme` 里没有对应 token，就地声明并注明出处——
    /// 比借一个语义不沾边的常量（`Radius.badge` 也是 10）读起来清楚。
    private let cellRadius: CGFloat = 10
    private let cellPaddingVertical: CGFloat = 8
    private let cellPaddingHorizontal: CGFloat = 10
    private let contentGap: CGFloat = 8
    /// 色条圆角 3
    private let barRadius: CGFloat = 3
    /// 格子底色 = 来源色 14% 透明。**不是** `CopyoTheme.tint`（那是 12% / 20% 混进白或 #1C1C1E 的
    /// 不透明卡片底色）——设计稿这里给的就是半透明叠在 `bg.card` 上，两处数值不同是有意的。
    private let cellTintAlpha: CGFloat = 0.14

    /// 色条 6 × 28、元信息 10，都不在系统文本样式的默认点数上，按 `KindBadge` 的写法用 `@ScaledMetric`。
    /// 只缩高度不缩宽度：6pt 的竖条按比例拉到 10pt 就不像色条、像第二个色块了。
    @ScaledMetric(relativeTo: .caption) private var barHeight: CGFloat = 28
    @ScaledMetric(relativeTo: .caption2) private var metaFontSize: CGFloat = 10
    private let barWidth: CGFloat = 6

    private var sourceColor: Color {
        Color(uiColor: CopyoTheme.uiColor(hexString: snapshot.sourceColorHex) ?? CopyoTheme.sourceLocalUI)
    }

    var body: some View {
        Button(intent: CopyClipIntent(clipID: snapshot.id)) {
            HStack(spacing: contentGap) {
                RoundedRectangle(cornerRadius: barRadius, style: .continuous)
                    .fill(sourceColor)
                    .frame(width: barWidth, height: barHeight)
                VStack(alignment: .leading, spacing: 2) {
                    // 链接条目这里显示的是域名而不是 design-spec 6.7 第 3 行那样的页面标题：
                    // `ClipItem` 根本没有标题字段（`SharePayload.link` 的注释写着 `title` 只用于预览），
                    // 库里存的就是 URL 本身。这不是漏实现，是数据模型没有那个值。
                    Text(snapshot.displayTitle)
                        // 设计 3.16 的 12 —— caption 的默认点数。等宽档同样走 caption，
                        // 不借 `Fonts.cardMono(dense:)`：那个是 caption2（11），比这一行矮一档，
                        // 四格里混着 11 和 12 两种高度会看出来
                        .font(snapshot.isMono ? .system(.caption, design: .monospaced) : .caption)
                        .foregroundStyle(CopyoTheme.label)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(verbatim: "\(snapshot.sourceName) · \(snapshot.relativeTime(at: date))")
                        .font(.system(size: metaFontSize))
                        .foregroundStyle(CopyoTheme.labelSecondary)
                        .lineLimit(1)
                        // 与 `ClipCard.metaLine` 同一条理由：法语的 `Cet iPhone · 3 min` 最长，
                        // 宁可缩小也要把时间显示全，丢掉时间这一行就没什么信息了
                        .minimumScaleFactor(0.8)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, cellPaddingVertical)
            .padding(.horizontal, cellPaddingHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(sourceColor.opacity(cellTintAlpha),
                        in: RoundedRectangle(cornerRadius: cellRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(snapshot.displayTitle), \(snapshot.sourceName), \(snapshot.relativeTime(at: date))")
        .accessibilityHint(Text(String(localized: "Tap to copy")))
    }
}
