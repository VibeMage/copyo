import CopyoCore
import SwiftUI

/// 长按卡片弹出的预览，**盖在键盘 330pt 的框之内**。
///
/// 设计 07 的交互写的是「长按 = 预览」，而设计第四节给整个应用定的预览是系统上下文菜单
/// （`.contextMenu(preview:)`，预览从卡片向上弹出，规格里那句提示写的就是「↑ 长按卡片预览」）。
/// **那一套在键盘扩展里不能用**：自定义键盘不许在键盘主视图的上边界之外显示按键图形，
/// 而向上弹出的上下文菜单正是那样一块浮在键盘上方的图形。所以这里改成一块自绘浮层，
/// 上下左右都留在 330 之内，绝不越过上边界。已记进 design-spec 第八节等待设计确认。
///
/// 浮层里同时给出「插入」：长按看清楚之后紧接着要做的就是这件事，
/// 让用户退出浮层再去点那张 168 宽的卡片是多余的一步。
struct ClipPreviewOverlay: View {
    let clip: KeyboardClip
    /// 外观。理由见 `CopyoTheme.keyCap(for:)`
    let scheme: ColorScheme
    let onInsert: () -> Void
    let onDismiss: () -> Void

    /// 浮层四周留给键盘框的余量。留够才看得出它是**盖在**键盘上的一层，
    /// 而不是把正文区换掉了
    var inset: CGFloat = 16

    var body: some View {
        ZStack {
            // 设计第四节：上下文菜单出现时底层加 dim。这里不做 `blur`——
            // 模糊要对整棵键盘视图树做离屏渲染，而这个进程的预算经不起
            CopyoTheme.dim
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            card
                .padding(inset)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                KindBadge(kind: clip.kind, sourceHex: clip.sourceColorHex)
                    .fixedSize(horizontal: true, vertical: false)
                Text(verbatim: "\(clip.sourceName) · \(clip.relativeTime())")
                    .font(CopyoTheme.Fonts.meta)
                    .foregroundStyle(CopyoTheme.labelSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onDismiss) {
                    // 设计第五节：关闭 = `xmark`
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(CopyoTheme.labelSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Close"))
            }

            // 正文可能比浮层高（`KeyboardClip.body` 最长 240 字）。给它一个 ScrollView，
            // 而不是再截一次——长按的**全部目的**就是看清楚这条到底是什么
            ScrollView {
                Text(previewText)
                    .font(clip.isMono
                          ? CopyoTheme.Fonts.cardMono(dense: false)
                          : CopyoTheme.Fonts.cardBody(dense: false))
                    .foregroundStyle(CopyoTheme.label)
                    .lineSpacing(CopyoTheme.cardLineSpacing(dense: false))
                    .textSelection(.disabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)

            footer
        }
        .padding(CopyoTheme.Metrics.cardPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(clip.tintColor(for: scheme))
        .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous))
        .accessibilityAddTraits(.isModal)
    }

    /// 图片没有正文可看，写出类型名总好过一片空白
    private var previewText: String {
        clip.body.isEmpty ? clip.displayTitle : clip.body
    }

    @ViewBuilder
    private var footer: some View {
        if clip.insertion != nil {
            Button(action: onInsert) {
                Text(String(localized: "Insert"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(CopyoTheme.accent,
                                in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.inner, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            // 插不进去的两类（图片、文件）在这里把原因说清楚，而不是给一颗按不动的按钮。
            // 文案与轻点卡片时那条轻提示是同一个键，两处说法不会走散
            Text(clip.kind == .image
                 ? String(localized: "Images can only be copied inside Copyo")
                 : String(localized: "Files stay on your Mac"))
                .font(.footnote)
                .foregroundStyle(CopyoTheme.labelSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
