import CopyoCore
import SwiftUI

/// Pinboard 的图标与配色。
///
/// CopyoCore 里 `iconName` / `colorHex` 都是可选：Mac 端建的板、以及本轮之前存量的板都拿不到值，
/// 所以取值一律走这里的回落，界面不要直接读那两个字段。
enum PinboardAppearance {

    /// 没有自定义图标时的默认符号（design-spec 第五节：标签栏 Pinboard 用 pin）
    static let defaultSymbol = "pin"
    /// 没有自定义颜色时回落到 accent
    static let defaultColorHex = "#0A84FF"

    /// 可选图标。前四个取自 design-spec 第五节「Pinboard 图标可选」，
    /// 后四个补齐到 8 个，凑成两行四列的菜单。
    static let symbols = [
        "paintpalette", "mappin", "terminal", "doc.text",
        "pin", "star", "tag", "bookmark",
    ]

    /// 8 色调色板。取值都在设计稿里出现过（样例板的图标色 + 品牌 / 语义色），
    /// 不引入设计稿之外的新色。
    static let palette = [
        "#0A84FF", "#A259FF", "#FF2D55", "#FF9F0A",
        "#34C759", "#F7C600", "#5B8DC9", "#8E8E93",
    ]

    static func symbol(for board: Pinboard) -> String {
        let name = board.iconName?.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? defaultSymbol : name
    }

    static func colorHex(for board: Pinboard) -> String {
        let hex = board.colorHex?.trimmingCharacters(in: .whitespaces) ?? ""
        return Color(hexString: hex) == nil ? defaultColorHex : hex
    }

    static func color(for board: Pinboard) -> Color {
        Color(hexString: colorHex(for: board)) ?? CopyoTheme.accent
    }

    /// 新建时按已有板数轮转取色，前八个板不会撞色
    static func nextColorHex(existingCount: Int) -> String {
        palette[max(0, existingCount) % palette.count]
    }
}

/// 设计 3.7 的图标砖：32 × 32、radius 8、底色 = 主题色 15%、内含 18pt 彩色图标。
///
/// 砖和图标都**不跟随辅助功能字号**，这是有意的：它是一块装饰色砖，不是文字盒子，
/// 里面的图标既不承载信息（旁边就是板名），放大也不会更好认；
/// 真让它按字号长到 96pt，`PinboardRow` 的板名和条目数就没地方站了。
/// 对应地，整块砖对旁白隐藏，免得光标在每一行上多停一次读出符号名。
struct PinboardIconTile: View {
    let board: Pinboard
    var size: CGFloat = 32

    var body: some View {
        let color = PinboardAppearance.color(for: board)
        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
            .fill(color.opacity(0.15))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: PinboardAppearance.symbol(for: board))
                    // 32 砖配 18pt 图标，换尺寸时按同一比例缩
                    .font(.system(size: size * 0.5625, weight: .medium))
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)
    }
}
