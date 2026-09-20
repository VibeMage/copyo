import CopyoCore
import SwiftUI

/// 类型角标：实心来源色底 + 11pt 图标 + 11 Semibold 文字。
/// 设计稿把 Mac 版的顶部色带压缩成了这枚角标，所以底色必须是来源色本身（不是淡染色）。
///
/// 视图本体只吃 `kind` + `sourceHex` 两个值类型（底下的 `init(item:)` 只是主应用列表的便利写法），
/// 不需要 `ModelContext` 里的 `ClipItem`，所以分享扩展与 Widget 也能直接渲染它。
/// 此前它在 `CopyoIOS/UI/` 下，分享面板只能在 `SharePreviewCard` 里另抄一份 `ShareKindBadge`，
/// 两份实现差半个点就会被看出来；那份副本已删。
struct KindBadge: View {
    let kind: ClipKind
    /// 来源色 "#RRGGBB"，nil 走本机灰
    var sourceHex: String?
    var dense: Bool = false

    /// 只有 dense 的 10pt 不在样式表上（caption2 正好是 11）。两档都走 `@ScaledMetric`
    /// 而不是让非 dense 那档用 `.caption2`：两档必须按同一条曲线缩，各用一套机制
    /// 迟早会在某个字号档位上让 dense 反过来比常规还大。
    /// 属性包装器的默认值必须是编译期常量，取不到 `dense`，只能两个都声明再挑一个。
    @ScaledMetric(relativeTo: .caption2) private var regularFontSize: CGFloat = 11
    @ScaledMetric(relativeTo: .caption2) private var denseFontSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption2) private var regularHeight: CGFloat = 20
    @ScaledMetric(relativeTo: .caption2) private var denseHeight: CGFloat = 18

    private var radius: CGFloat { dense ? 9 : CopyoTheme.Radius.badge }
    private var fontSize: CGFloat { dense ? denseFontSize : regularFontSize }
    /// 用 minHeight 而不是 height：字号放大后文字本来就比胶囊高，
    /// 写死 height 的表现是把「富文本」四个字从上下切掉，比不跟随放大还糟。
    private var minHeight: CGFloat { dense ? denseHeight : regularHeight }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: KindPresentation.symbol(kind))
                .font(.system(size: fontSize, weight: .semibold))
                // textformat / bold / italic 这一族符号带 zh / ja / ko 本地化变体，
                // 跟随视图 locale 会把富文本角标画成「格式」两个汉字。角标图形按设计固定拉丁字形，
                // 只作用于这一个 Image，右边的 Text 仍走当前语言。
                .environment(\.locale, Locale(identifier: "en"))
            Text(KindPresentation.label(kind))
                .font(.system(size: fontSize, weight: .semibold))
        }
        .foregroundStyle(CopyoTheme.onBand(sourceHex: sourceHex))
        .padding(.leading, dense ? 5 : 6)
        .padding(.trailing, dense ? 6 : 7)
        .padding(.vertical, 1)
        .frame(minHeight: minHeight)
        .background(
            Color(uiColor: CopyoTheme.uiColor(hexString: sourceHex) ?? CopyoTheme.sourceLocalUI),
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
    }
}

extension KindBadge {
    init(item: ClipItem, dense: Bool = false) {
        self.init(kind: item.kind, sourceHex: item.sourceColorHex, dense: dense)
    }
}
