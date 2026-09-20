import CopyoCore
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
                        .font(.system(.callout, weight: .semibold))
                        // 右边就写着「复制」，图标再报一遍只是噪音
                        .accessibilityHidden(true)
                    Text(String(localized: "Copy"))
                        .font(.system(.subheadline, weight: .semibold))
                        .lineLimit(1)
                        // 法语的 `Copier` 比英文长两个字母，放大档位下要能缩回来，
                        // 否则它会把右边四个图标按钮挤出屏幕
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                // 内距 + minHeight：主按钮是**装着文字的**点按目标，写死 `height: 48`
                // 会在放大档位下把「Copier」上下切掉。48 本身不跟着缩——
                // 加了上下内距之后，封顶档位（AX1）的 25pt 文字连内距才 42，仍然落在 48 里，
                // 胶囊维持设计稿的形状，同时再也不会裁字
                .padding(.vertical, 6)
                .frame(minHeight: 48)
                .background(CopyoTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)

            iconButton(symbol: "doc.plaintext",
                       label: String(localized: "Copy as Plain Text"),
                       action: onCopyPlainText)

            ShareLink(item: item.transferable, preview: SharePreview(item.displayTitleLocalized)) {
                icon("square.and.arrow.up", tint: CopyoTheme.label)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Share"))

            iconButton(symbol: isPinned ? "pin.slash" : "pin",
                       label: isPinned ? String(localized: "Unpin") : String(localized: "Pin"),
                       tint: isPinned ? CopyoTheme.accent : CopyoTheme.label,
                       action: onTogglePin)

            iconButton(symbol: "trash",
                       label: String(localized: "Delete"),
                       tint: CopyoTheme.destructive,
                       action: onDelete)
        }
        .padding(.horizontal, 8)
        // minHeight 而不是 height：主按钮万一撑到 48 以上，这条胶囊要跟着长而不是把它裁掉
        .frame(minHeight: CopyoTheme.Metrics.tabBarHeight)
        .copyoGlass(in: Capsule())
        // 设计 3.13：工具栏底距 26，与标签栏齐平。外层是 safeAreaInset，
        // 底部安全区已经让出 34pt，所以这里要反向补 8pt 才落在 26。
        .padding(.bottom, -8)
        // 这一条是**横排五个控件的固定几何**，只有 375pt 可用。放到 AX2 以上，
        // 光主按钮就要吃掉半屏，剩下四个图标会被挤没或裁掉——比不放大糟得多。
        // 退路是导航栏右上的「更多」菜单：`ClipDetailScreen.menuContent` 完整地放着这五个动作
        // （复制 / 复制为纯文本 / 分享 / 固定 / 删除），那是系统菜单，字号不封顶。
        // **动那个菜单时要回头看这里**——它少哪一个，这条封顶就把哪一个彻底卡死了。
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func iconButton(symbol: String,
                            label: String,
                            tint: Color = CopyoTheme.label,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon(symbol, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// 四个图标按钮的 50 × 48 保持写死——它们是**纯点按目标**，里面一个字都没有：
    /// 48 已经高过 `CopyoTheme.Metrics.hitMin` 的 44，框再大也换不来更好点；
    /// 而一行五个控件在 375pt 宽的机身上根本没有各自长大的余地。
    /// 图标本身走 `.title3`（就是设计的 20pt），封顶档位下 31pt 仍然落在 48 的框里，不会被裁。
    /// 它们表达的含义由 `accessibilityLabel` 交给旁白，由右上「更多」菜单交给放大字号的用户。
    private func icon(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(tint)
            .frame(width: 50, height: 48)
            .contentShape(Rectangle())
    }
}
