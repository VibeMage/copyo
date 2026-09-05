import PasterCore
import SwiftUI

/// 类型角标：实心来源色底 + 11pt 图标 + 11 Semibold 文字。
/// 设计稿把 Mac 版的顶部色带压缩成了这枚角标，所以底色必须是来源色本身（不是淡染色）。
struct KindBadge: View {
    let kind: ClipKind
    /// 来源色 "#RRGGBB"，nil 走本机灰
    var sourceHex: String?
    var dense: Bool = false

    private var height: CGFloat { dense ? 18 : 20 }
    private var radius: CGFloat { dense ? 9 : PasterTheme.Radius.badge }
    private var fontSize: CGFloat { dense ? 10 : 11 }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: KindPresentation.symbol(kind))
                .font(.system(size: fontSize, weight: .semibold))
            Text(KindPresentation.label(kind))
                .font(.system(size: fontSize, weight: .semibold))
        }
        .foregroundStyle(PasterTheme.onBand(sourceHex: sourceHex))
        .padding(.leading, dense ? 5 : 6)
        .padding(.trailing, dense ? 6 : 7)
        .frame(height: height)
        .background(
            Color(uiColor: PasterTheme.uiColor(hexString: sourceHex) ?? PasterTheme.sourceLocalUI),
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
    }
}

extension KindBadge {
    init(item: ClipItem, dense: Bool = false) {
        self.init(kind: item.kind, sourceHex: item.sourceColorHex, dense: dense)
    }
}
