import SwiftUI

/// Copyo 的品牌标记：骨白卡片 + 红蓝错位套印，图标语言的最小还原（design-spec 3.10）。
///
/// 原先挂在 `ShareTheme.swift` 末尾，那个文件在 token 上收之后删掉了。
/// 单开一个文件而不是并进 `ShareView.swift`：按文件名找得到它，
/// 而且它与分享面板并无绑定关系——小组件与引导页将来也可能用到同一枚标记。
struct CopyoMark: View {
    /// 标记的边长。design-spec 3.10 给的是 26；这是图形不是字，所以不跟随动态字体。
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(CopyoTheme.Brand.bone)
            Capsule()
                .fill(CopyoTheme.Brand.red.opacity(0.9))
                .frame(width: size * 0.54, height: size * 0.13)
                .offset(x: -size * 0.06, y: -size * 0.07)
            Capsule()
                .fill(CopyoTheme.Brand.blue.opacity(0.85))
                .frame(width: size * 0.54, height: size * 0.13)
                .offset(x: size * 0.06, y: size * 0.07)
                .blendMode(.multiply)
        }
        .frame(width: size, height: size)
        .compositingGroup()
        // 纯装饰：它旁边就是「保存到 Copyo」，读屏再念一遍品牌标记只会多一个停留点
        .accessibilityHidden(true)
    }
}
