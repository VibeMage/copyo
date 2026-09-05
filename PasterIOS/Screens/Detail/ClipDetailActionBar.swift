import PasterCore
import SwiftUI

/// 详情页底部的浮动玻璃工具栏（design-spec 3.13）：
/// 高 64、内距 8、radius 32；主按钮高 48、内距 18、radius 24、accent 底；其余四个 50 × 48、图标 20。
/// 已固定时 pin 图标转 accent 色（设计 02b）。
struct ClipDetailActionBar: View {
    let item: ClipItem
    var onCopy: () -> Void
    var onCopyPlainText: () -> Void
    var onTogglePin: () -> Void
    var onDelete: () -> Void

    private var isPinned: Bool { item.pinboard != nil }

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onCopy) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16, weight: .semibold))
                    Text(String(localized: "Copy"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 48)
                .background(PasterTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)

            iconButton(symbol: "doc.plaintext",
                       label: String(localized: "Copy as Plain Text"),
                       action: onCopyPlainText)

            ShareLink(item: item.transferable, preview: SharePreview(item.displayTitleLocalized)) {
                icon("square.and.arrow.up", tint: PasterTheme.label)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Share"))

            iconButton(symbol: isPinned ? "pin.slash" : "pin",
                       label: isPinned ? String(localized: "Unpin") : String(localized: "Pin"),
                       tint: isPinned ? PasterTheme.accent : PasterTheme.label,
                       action: onTogglePin)

            iconButton(symbol: "trash",
                       label: String(localized: "Delete"),
                       tint: PasterTheme.destructive,
                       action: onDelete)
        }
        .padding(.horizontal, 8)
        .frame(height: PasterTheme.Metrics.tabBarHeight)
        .pasterGlass(in: Capsule())
        // 设计 3.13：工具栏底距 26，与标签栏齐平。外层是 safeAreaInset，
        // 底部安全区已经让出 34pt，所以这里要反向补 8pt 才落在 26。
        .padding(.bottom, -8)
    }

    private func iconButton(symbol: String,
                            label: String,
                            tint: Color = PasterTheme.label,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon(symbol, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func icon(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20))
            .foregroundStyle(tint)
            .frame(width: 50, height: 48)
            .contentShape(Rectangle())
    }
}
