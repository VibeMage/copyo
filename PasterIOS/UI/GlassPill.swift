import SwiftUI

extension View {
    /// 玻璃材质容器。iOS 26 用系统的 Liquid Glass，iOS 18 手工拼 glass / glassRing / glassSh 三个 token。
    /// 之所以不直接一律用材质：iOS 26 上系统玻璃会随背后内容折射，手工版做不到。
    @ViewBuilder
    func pasterGlass<S: InsettableShape>(in shape: S, shadow: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(PasterTheme.glassStroke, lineWidth: 0.5))
                .shadow(color: shadow ? PasterTheme.glassShadow : .clear, radius: 12, y: 8)
                .shadow(color: shadow ? PasterTheme.glassShadow.opacity(0.5) : .clear, radius: 1.5, y: 1)
        }
    }
}

/// 胶囊玻璃容器：iCloud 状态、轻提示、浮动工具栏共用。
/// 左右内距分开给，设计稿里带图标的一侧总是窄 2pt。
struct GlassPill<Content: View>: View {
    var height: CGFloat = PasterTheme.Metrics.syncPillHeight
    var leading: CGFloat = 10
    var trailing: CGFloat = 12
    var spacing: CGFloat = 5
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: spacing, content: content)
            .padding(.leading, leading)
            .padding(.trailing, trailing)
            .frame(height: height)
            .pasterGlass(in: Capsule())
    }
}
