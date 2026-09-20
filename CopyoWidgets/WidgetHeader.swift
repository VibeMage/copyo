import SwiftUI

/// 小组件顶部那一行：左边固定是「最近」，右边一格按尺寸放不同的东西（设计 08）——
/// 小尺寸放最新那条的相对时间，中尺寸放同步状态。
struct WidgetHeader: View {
    /// 右侧那一格的文字，没有就只剩标题
    var trailing: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(String(localized: "Recent"))
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .lineLimit(1)
                    // 法语的 `Synchronisation…` 比中英两版都长一截，宁可缩小也不要截成 `Synchr…`
                    .minimumScaleFactor(0.8)
            }
        }
        // 设计 3.16 的 12 Semibold。12 正好是 `caption` 的默认点数，走样式而不是 `.system(size: 12)`：
        // 小组件同样跟随「设置 → 辅助功能 → 显示与文字大小」，写死点数的话调大字号后
        // 下面的正文变大、这一行纹丝不动。
        .font(.caption.weight(.semibold))
        .foregroundStyle(CopyoTheme.labelSecondary)
    }
}
