import SwiftUI

/// 分享面板标题旁那枚 26pt 应用标记（design-spec 3.10）。
///
/// 设计稿这里放的是 App 图标本身，但扩展 bundle 里没有图标资源（图标只在主应用的 Assets 里），
/// 跨进程取自己的图标也没有公开 API，所以照图标的构图现画一枚缩小版：
/// 深色径向底 + 骨白卡片 + 四条内容条（墨、墨、红、蓝），卡片左上透红、右下透蓝。
///
/// 早先画的是「骨白底 + 两条红蓝套印」，放在浅色 sheet（#F2F2F7）上几乎没有轮廓，
/// 只看得见两截短横线浮在标题前面，认不出是个 App 图标；深色底在两种外观下都立得住。
///
/// 原先挂在 `ShareTheme.swift` 末尾，那个文件在 token 上收之后删掉了。
/// 单开一个文件而不是并进 `ShareView.swift`：按文件名找得到它，
/// 而且它与分享面板并无绑定关系——小组件与引导页将来也可能用到同一枚标记。
struct CopyoMark: View {
    /// 标记的边长。design-spec 3.10 给的是 26；这是图形不是字，所以不跟随动态字体。
    var size: CGFloat = 26

    /// 图标深底的径向渐变两端（ios-plan 品牌说明：#1B1620 → #08060B）
    private static let deepInner = Color(red: 0x1B / 255, green: 0x16 / 255, blue: 0x20 / 255)
    private static let deepOuter = Color(red: 0x08 / 255, green: 0x06 / 255, blue: 0x0B / 255)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(RadialGradient(colors: [Self.deepInner, Self.deepOuter],
                                     center: .center, startRadius: 0, endRadius: size * 0.7))

            card
                // 图标上卡片边缘那圈红蓝辉光，缩到 26pt 只剩一点色晕
                .shadow(color: CopyoTheme.Brand.red.opacity(0.8), radius: size * 0.05,
                        x: -size * 0.04, y: -size * 0.04)
                .shadow(color: CopyoTheme.Brand.blue.opacity(0.8), radius: size * 0.05,
                        x: size * 0.04, y: size * 0.04)
        }
        .frame(width: size, height: size)
        // 深色 sheet（#1C1C1E）上深底会与面板糊在一起，补一圈极细的描边把方块轮廓勾出来
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
        .compositingGroup()
        // 纯装饰：它旁边就是「保存到 Copyo」，读屏再念一遍品牌标记只会多一个停留点
        .accessibilityHidden(true)
    }

    /// 骨白卡片 + 四条内容条，比例取自 art/icon 的母图
    private var card: some View {
        VStack(alignment: .leading, spacing: size * 0.055) {
            bar(CopyoTheme.Brand.ink, width: 0.30)
            bar(CopyoTheme.Brand.ink, width: 0.30)
            bar(CopyoTheme.Brand.red, width: 0.30)
            bar(CopyoTheme.Brand.blue, width: 0.22)
        }
        .frame(width: size * 0.48, height: size * 0.6)
        .background(CopyoTheme.Brand.bone,
                    in: RoundedRectangle(cornerRadius: size * 0.07, style: .continuous))
    }

    private func bar(_ color: Color, width: CGFloat) -> some View {
        Capsule()
            .fill(color)
            .frame(width: size * width, height: size * 0.06)
            // 四条都靠左对齐，最短的那条才看得出长短
            .frame(width: size * 0.30, alignment: .leading)
    }
}
