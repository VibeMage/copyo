import PasterCore
import SwiftUI

/// 设计 01 的筛选 chips：全部 / 文本 / 链接 / 图片 / 颜色（单选）。
/// 「全部」含富文本与文件；「文本」把富文本一并算进来，口径由 `KindPresentation` 统一。
struct HistoryFilterChips: View {
    @Binding var selection: ClipKind?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(title: String(localized: "All"), kind: nil)
                ForEach(KindPresentation.compactFilters, id: \.self) { kind in
                    chip(title: Self.filterTitle(kind), kind: kind)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// chips 用复数（设计 01g：`All / Text / Links / Images / Colors`），
    /// 卡片角标用单数（3.2 的 `Link / Image / Color`）——两处文案不共用一套 key。
    /// 中文两边一样，只有英文分单复数。
    private static func filterTitle(_ kind: ClipKind) -> String {
        switch kind {
        case .link: String(localized: "Links")
        case .image: String(localized: "Images")
        case .color: String(localized: "Colors")
        default: KindPresentation.label(kind)
        }
    }

    private func chip(title: String, kind: ClipKind?) -> some View {
        let isSelected = selection == kind
        return Button {
            withAnimation(PasterTheme.springAnimation) { selection = kind }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : PasterTheme.label)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(isSelected ? PasterTheme.accent : PasterTheme.fill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
