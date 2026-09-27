import SwiftUI

/// 悬停动作簇：卡片右上角的玻璃小条，只有固定与删除两枚（design-spec 3.4，第八节第 7 条）。
///
/// 图钉按用途分形状（第 26 条）：未固定画描边 `pin`、点了由调用方弹 Pinboard 菜单；
/// 已固定画 `pin.fill`、点了即取消固定。两枚都只有图标，accessibilityLabel 是它们唯一可读的内容。
struct ClipCardActionCluster: View {
    let isPinned: Bool
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            ClusterButton(symbol: isPinned ? "pin.fill" : "pin",
                          color: CopyoTheme.accent,
                          label: isPinned ? String(localized: "Unpin") : String(localized: "Pin to Pinboard"),
                          action: onPin)
            ClusterButton(symbol: "trash",
                          color: CopyoTheme.destructive,
                          label: String(localized: "Delete"),
                          action: onDelete)
        }
        .padding(.horizontal, 3)
        .frame(height: 28)
        .modifier(ClipCardGlass(cornerRadius: 9))
    }
}

private struct ClusterButton: View {
    let symbol: String
    let color: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                // 画板线宽 1.5 → .regular（第 25 条换算表）
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .clipCardPointer(nested: true)
    }
}

/// 动作簇的玻璃外壳（第 32(c) 条：macOS 26+ 系统玻璃，14–25 退回系统材质；
/// 画板上的 `rgba(255,255,255,.74)` 只是视觉目标，不照抄成实色）。
/// 减弱透明度时统一降级成 `bg.grouped` 实色、保留阴影（design-spec 4.7.4，第 24 条）。
private struct ClipCardGlass: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content
                .background(CopyoTheme.glassSolid, in: shape)
                .overlay(shape.strokeBorder(CopyoTheme.glassRing, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
        } else if #available(macOS 26.0, *) {
            // 系统玻璃自带边缘高光与投影，再叠 glassRing / 阴影会画出两道边
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(CopyoTheme.glassRing, lineWidth: 0.5))
                // CSS `0 2px 8px` 的 8 是模糊直径，SwiftUI 的 radius 取一半
                .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
        }
    }
}
