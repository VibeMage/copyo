import CopyoCore
import SwiftUI

/// 小尺寸：最近一条（设计 08 / 3.16）。
/// 内容块是来源淡染底 + dense 角标 + 3 行正文，底下一行居中的「点按复制」。
struct SmallClipView: View {
    let snapshot: ClipSnapshot
    /// 这一帧代表的时刻，相对时间按它算（不是 `Date()`，理由见 `RecentClipsEntry.date`）
    let date: Date

    /// 内容块的内距（设计 3.16 的 padding 10，与 dense 卡片同一个值）
    var blockPadding: CGFloat = CopyoTheme.Metrics.cardPadDense
    /// 角标与正文之间、以及内容块与「点按复制」之间的间距（设计 3.16 的 gap 8）
    var gap: CGFloat = 8
    /// 正文最多画几行（设计 08：3 行截断）
    var bodyLineLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            Button(intent: CopyClipIntent(clipID: snapshot.id)) {
                block
            }
            // 默认按钮样式会给小组件里的按钮铺一层灰底和内距，把淡染底整个盖掉
            .buttonStyle(.plain)
            // 标签挂在按钮本身上，**不要**在外层写 `accessibilityElement(children: .combine)`：
            // 那会把按钮合并进一个纯文本元素，VoiceOver 就点不动它了
            .accessibilityLabel("\(snapshot.displayTitle), \(snapshot.sourceName), \(snapshot.relativeTime(at: date))")
            .accessibilityHint(Text(String(localized: "Tap to copy")))
            Text(String(localized: "Tap to copy"))
                // 设计 3.16 的 11 —— 正好是 caption2 的默认点数
                .font(.caption2)
                .foregroundStyle(CopyoTheme.labelTertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                // 这一行是给眼睛看的说明，内容已经进了上面那个按钮的 hint，再读一遍是重复
                .accessibilityHidden(true)
        }
    }

    private var block: some View {
        VStack(alignment: .leading, spacing: gap) {
            HStack(spacing: 6) {
                KindBadge(kind: snapshot.kind, sourceHex: snapshot.sourceColorHex, dense: true)
                Spacer(minLength: 0)
                if snapshot.isPinned {
                    // 与 `ClipCard` 的头部同一个排法：角标靠左、图钉靠右。
                    // 比那边小一档（caption2 而不是 caption），跟这里的 dense 角标配对。
                    // 中尺寸那一格**没有**这个图标——一行 12pt 正文加一行 10pt 元信息塞在 2 × 2 里，
                    // 再加一个图标只会把元信息挤掉。
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(CopyoTheme.labelSecondary)
                }
            }
            content
        }
        .padding(blockPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CopyoTheme.tint(sourceHex: snapshot.sourceColorHex),
                    in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if snapshot.kind == .image {
            // 图片条目在这里**永远**只画占位块：取缩略图要读 `ClipItem.imageData`，
            // 那是 `@Attribute(.externalStorage)` 的大对象，读一张 5K 截图就够把这个扩展挤爆
            // （理由与上限见 `ClipSnapshot.init(item:)`）。这也正是 `ClipCard.imageContent`
            // 给「iCloud 资产还没下载下来」准备的那一档画法。
            ZStack {
                CopyoTheme.fill
                Image(systemName: KindPresentation.symbol(.image))
                    .font(.title2)
                    .foregroundStyle(CopyoTheme.labelTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Radius.inner, style: .continuous))
        } else {
            Text(snapshot.body.isEmpty ? snapshot.displayTitle : snapshot.body)
                // 设计 3.16 的 13/17 正好是卡片 dense 档，直接借 `Fonts` 的那一对：
                // 正文 footnote（13）、等宽 caption2（11）。等宽比正文矮一档是设计 2.4 定的口径
                .font(snapshot.isMono
                      ? CopyoTheme.Fonts.cardMono(dense: true)
                      : CopyoTheme.Fonts.cardBody(dense: true))
                .foregroundStyle(CopyoTheme.label)
                .lineSpacing(CopyoTheme.cardLineSpacing(dense: true))
                .lineLimit(bodyLineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
