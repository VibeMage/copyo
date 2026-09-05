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
                        .foregroundStyle(PasterTheme.label)
                    Text(hint.action)
                        .foregroundStyle(PasterTheme.labelSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .font(PasterTheme.Fonts.footnote)
        .padding(.horizontal, PasterTheme.Metrics.pageInsetPad)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PasterTheme.bgGrouped.opacity(0.94))
        .accessibilityHidden(true)
    }
}
