import SwiftUI

/// 设计 09 的底部快捷键提示条。只在 regular 宽度出现——
/// 那是唯一可能接着硬件键盘的场景，iPhone 上多这一行只会占掉一张卡片的位置。
struct HistoryShortcutHints: View {
    private struct Hint: Identifiable {
        let id = UUID()
        let key: String
        let action: String
    }

    private var hints: [Hint] {
        [
            Hint(key: "↵", action: String(localized: "Copy")),
            Hint(key: "⇧↵", action: String(localized: "Plain Text")),
            Hint(key: String(localized: "Space"), action: String(localized: "Preview")),
            Hint(key: "⌘P", action: String(localized: "Pin")),
            Hint(key: "⌫", action: String(localized: "Delete")),
        ]
    }

    var body: some View {
        HStack(spacing: 14) {
            ForEach(hints) { hint in
                HStack(spacing: 4) {
                    Text(hint.key)
                        .fontWeight(.semibold)
                        .foregroundStyle(CopyoTheme.label)
                    Text(hint.action)
                        .foregroundStyle(CopyoTheme.labelSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .font(CopyoTheme.Fonts.footnote)
        // 五组「键 + 动作」排成一行，放大档位下总宽会超过内容区。
        // 让它们按房规的 0.8 先缩一档再截断，而不是各自折成两行——
        // 一条两行高的提示条会把网格顶掉小半张卡片，而它本来只是锦上添花：
        // 这五个动作每一个都另有入口（轻点、长按菜单、左右滑）。
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, CopyoTheme.Metrics.pageInsetPad)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CopyoTheme.bgGrouped.opacity(0.94))
        .accessibilityHidden(true)
    }
}
