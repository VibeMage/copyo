import SwiftUI

/// 设计 07 的底排功能键：地球 46 × 42 · 面板切换 46 × 42 · 空格（自适应）× 42 ·
/// 删除 46 × 42 · 换行 72 × 42，圆角 6、键间距 6、整排下方留 40 给 Home 指示条
/// （那 40 由 `KeyboardViewController` 那一层按机型扣，不在本视图里）。
///
/// 设计稿里第二颗键画的是一个 `↑`，且没有定义任何行为。这里把它改成面板切换键：
/// 指南 4.4.1 明文禁止「把键盘按键挪作他用」，而一颗长得像上档键、按下去却翻一整面键盘的键，
/// 正好是那条禁令说的事。改成 `123` / `ABC` 之后它做的就是系统键盘上同名键做的事，
/// 键面写的是去处——设计 07 画的 `ABC` 正是卡片条那一面上该有的字样，见 `KeyboardPlane`。
struct KeyRow: View {
    @Binding var plane: KeyboardPlane
    let actions: KeyboardActions
    /// 外观。理由见 `CopyoTheme.keyCap(for:)`
    let scheme: ColorScheme
    /// 地球键的接线；nil = 系统不要求显示地球键（这台设备只装了这一块键盘）
    var globe: GlobeKeyWiring?

    /// 键间距（设计 07 `gap:6`）
    var spacing: CGFloat = 6
    /// 功能键宽（设计 07）
    var functionWidth: CGFloat = 46
    /// 换行键宽（设计 07）
    var returnWidth: CGFloat = 72
    /// 键高（设计 07 全部 42）
    var keyHeight: CGFloat = 42

    var body: some View {
        HStack(spacing: spacing) {
            if let globe {
                GlobeKey(scheme: scheme, wiring: globe, width: functionWidth, height: keyHeight)
            }

            KeyCap(width: functionWidth,
                   height: keyHeight,
                   fill: .function,
                   scheme: scheme,
                   action: { plane.toggle() }) {
                Text(plane.switchKeyTitle)
                    // 设计 07 这颗键 15pt → 契约里的 `.subheadline`
                    .font(.subheadline)
            }
            .accessibilityLabel(plane.switchKeyAccessibilityLabel)

            KeyCap(height: keyHeight,
                   fill: .cap,
                   scheme: scheme,
                   action: actions.space) {
                Text(String(localized: "space"))
                    // 设计 07 空格键 16pt → `.callout`
                    .font(.callout)
            }

            KeyCap(width: functionWidth,
                   height: keyHeight,
                   fill: .function,
                   repeatsOnHold: true,
                   scheme: scheme,
                   action: actions.deleteBackward) {
                // 设计 6.x 符号表：键盘删除 = `delete.left`
                Image(systemName: "delete.left")
                    .font(.title3)
            }
            .accessibilityLabel(String(localized: "Delete"))

            KeyCap(width: returnWidth,
                   height: keyHeight,
                   fill: .function,
                   scheme: scheme,
                   action: actions.newline) {
                // 设计 07 这颗键是文字「换行」，不是 `return` 图标。
                // 键面没有跟着宿主的 `returnKeyType` 变（搜索框里系统键盘会写「搜索」）——
                // 本阶段一律写「换行」，宿主收到的也确实是一个换行符，二者是一致的
                Text(String(localized: "return"))
                    .font(.subheadline)
            }
        }
    }
}
