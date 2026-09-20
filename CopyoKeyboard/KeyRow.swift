import SwiftUI

/// 设计 07 的底排功能键：地球 46 × 42 · 面板切换 46 × 42 · 空格（自适应）× 42 ·
/// 删除 46 × 42 · 换行 72 × 42，圆角 6、键间距 6、整排下方留 40 给 Home 指示条
/// （那 40 由 `KeyboardViewController` 那一层按机型扣，不在本视图里）。
///
/// 设计稿里第二颗键画的是一个 `↑`，且没有定义任何行为。这里把它改成面板切换键：
/// 指南 4.4.1 明文禁止「把键盘按键挪作他用」，而一颗长得像上档键、按下去却翻一整面键盘的键，
/// 正好是那条禁令说的事。改成面板切换之后它做的就是系统键盘上同名键做的事，
/// 键面写的是**去处**：卡片条上写 `ABC`（正是设计 07 画的那个）、字母面上写 `123`、
/// 数字面上画一个剪贴板符号回到卡片条。三档轮转的取舍见 `KeyboardPlane`。
struct KeyRow: View {
    @Binding var plane: KeyboardPlane
    let actions: KeyboardActions
    /// 外观。理由见 `CopyoTheme.keyCap(for:)`
    let scheme: ColorScheme
    /// 地球键的接线；nil = 系统不要求显示地球键（这台设备只装了这一块键盘）
    var globe: GlobeKeyWiring?
    /// 正在编辑搜索查询：最右那颗键改写成「搜索」。
    ///
    /// **只换键面，不换接线。** 按下去走的仍然是 `actions.newline`——根视图在编辑查询时
    /// 递进来的是一整套写查询的 `KeyboardActions`，那一套里的 `newline` 做的就是
    /// 「收起键位、显示筛选后的卡片条」。键面与实际行为因此不可能各说各话：
    /// 两者由同一个 `KeyboardRootView.isEditingQuery` 驱动。
    ///
    /// 这也是本键盘唯一一处跟着上下文改键面的地方；其余时候它一律写「换行」，
    /// 不跟随宿主的 `returnKeyType`（搜索框里系统键盘会写「搜索」），那是另一笔待补的打磨。
    var submitsSearch: Bool = false

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
                   action: { plane.advance() }) {
                switch plane.switchKeyLabel {
                case .text(let title):
                    Text(title)
                        // 设计 07 这颗键 15pt → 契约里的 `.subheadline`
                        .font(.subheadline)
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.title3)
                }
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
                // 设计 07 这颗键是文字「换行」，不是 `return` 图标
                Text(submitsSearch ? String(localized: "Search") : String(localized: "return"))
                    .font(.subheadline)
            }
        }
    }
}
