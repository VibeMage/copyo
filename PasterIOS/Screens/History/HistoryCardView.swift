import PasterCore
import SwiftData
import SwiftUI

/// 历史网格里的一张卡片：轻点复制、长按菜单、拖出到别的 App、详情 zoom 转场。
///
/// 卡片本体是共用的 `ClipCard`，这里只负责「围绕卡片的交互」。
/// 单独拆一个视图是因为按压回弹与插入动效需要各自的 `@State`——
/// 放在历史页那一层，任何一张卡片的状态变化都会重算整个网格。
struct HistoryCardView: View {
    let item: ClipItem
    let boards: [Pinboard]
    let namespace: Namespace.ID
    /// 长按预览的宽度，跟着网格列宽走
    var previewWidth: CGFloat
    var isFocused: Bool
    /// 刚保存进来的那条：从 y −12 / 透明淡入（设计 01d）
    var isHighlighted: Bool
    /// iPad 才挂拖放，iPhone 上多一个长按手势会和上下文菜单抢
    var allowsDrag: Bool

    var onCopy: () -> Void
    var onCopyPlainText: () -> Void
    var onPin: (Pinboard) -> Void
    var onUnpin: () -> Void
    var onCreatePinboard: () -> Void
    var onDelete: () -> Void

    @State private var isPressed = false
    @State private var hasAppeared = false

    var body: some View {
        card
            .contextMenu {
                menuItems
            } preview: {
                // 设计 01e：预览就是卡片本体放大 1.04，外面留点余量免得阴影被裁
                ClipCard(item: item)
                    .frame(width: max(240, previewWidth))
                    .scaleEffect(1.04)
                    .padding(10)
            }
            .opacity(isEntering ? 0 : 1)
            .offset(y: isEntering ? -12 : 0)
            .onAppear {
                guard !hasAppeared else { return }
                if isHighlighted {
                    withAnimation(PasterTheme.springAnimation) { hasAppeared = true }
                } else {
                    hasAppeared = true
                }
            }
    }

    /// 高亮插入的卡片在第一帧是「偏上 + 全透明」，onAppear 之后弹到原位
    private var isEntering: Bool { isHighlighted && !hasAppeared }

    @ViewBuilder
    private var card: some View {
        let link = NavigationLink {
            ClipDetailScreen(item: item)
                .navigationTransition(.zoom(sourceID: item.persistentModelID, in: namespace))
        } label: {
            ClipCard(item: item, isFocused: isFocused, isPressed: isPressed)
        }
        .buttonStyle(.plain)
        // 轻点是复制不是进详情——把 tap 抢在 NavigationLink 之前处理。
        // 进详情走长按菜单的预览点按（系统会执行 link 的目的地）。
        .highPriorityGesture(TapGesture().onEnded { tapped() })
        .matchedTransitionSource(id: item.persistentModelID, in: namespace)

        if allowsDrag {
            link.draggable(item.transferable)
        } else {
            link
        }
    }

    @ViewBuilder
    private var menuItems: some View {
        Button {
            onCopy()
        } label: {
            Label(String(localized: "Copy"), systemImage: "doc.on.doc")
        }
        Button {
            onCopyPlainText()
        } label: {
            Label(String(localized: "Copy as Plain Text"), systemImage: "doc.plaintext")
        }
        shareButton
        PinboardPickerMenu(boards: boards,
                           current: item.pinboard,
                           onSelect: onPin,
                           onUnpin: item.pinboard == nil ? nil : onUnpin,
                           onCreate: onCreatePinboard)
        Button(role: .destructive) {
            onDelete()
        } label: {
            Label(String(localized: "Delete"), systemImage: "trash")
        }
    }

    /// 分享按条目类型给最合适的表示：链接给 URL（对方能识别成网页）、
    /// 图片给图片（能存进相册）、其余给纯文本。
    @ViewBuilder
    private var shareButton: some View {
        let label = Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
        if let url = item.linkURL {
            ShareLink(item: url) { label }
        } else if item.kind == .image, let thumbnail = item.thumbnail {
            let image = Image(uiImage: thumbnail)
            ShareLink(item: image,
                      preview: SharePreview(item.displayTitleLocalized, image: image)) { label }
        } else {
            ShareLink(item: item.displayBody.isEmpty ? item.displayTitleLocalized : item.displayBody) { label }
        }
    }

    /// 设计四节：轻点 → 复制 + 卡片 scale .96 → 1 回弹。
    /// 回弹靠 ClipCard 自带的 `isPressed` 动画，这里只负责把状态按下再放开。
    private func tapped() {
        onCopy()
        isPressed = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            isPressed = false
        }
    }
}
