import CopyoCore
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
    /// 正被拖走：原位留一张 35% 的影子（设计 09 的 ghost 卡）
    var isGhost: Bool = false
    /// iPad 才挂拖放，iPhone 上多一个长按手势会和上下文菜单抢
    var allowsDrag: Bool
    /// 拖动开始 / 结束。SwiftUI 的 `.draggable` 不给回调，
    /// 只能借拖动预览视图的 onAppear / onDisappear 判断——预览在拖起来时出现、松手后消失。
    var onDragChanged: (Bool) -> Void = { _ in }

    var onCopy: () -> Void
    var onCopyPlainText: () -> Void
    var onPin: (Pinboard) -> Void
    var onUnpin: () -> Void
    var onCreatePinboard: () -> Void
    var onDelete: () -> Void
    /// 旁白的「打开详情」。具名动作只能回调闭包、点不动 `NavigationLink`，这条路径必须另有一个
    /// 程序化入口；入口只能放在历史页那一层——详见 `accessibilityActionList` 上面的说明。
    var onOpenDetail: () -> Void

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
                    withAnimation(CopyoTheme.springAnimation) { hasAppeared = true }
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
            // zoom 转场的 `sourceID` 与 namespace 必须和 `HistoryScreen` 那份
            // `navigationDestination(item:)` 一模一样：旁白的「打开详情」走的是那一条，
            // 手指点的是这一条，两边一旦走散，其中一条就退化成没有转场的硬切。
            // namespace 本来就是历史页传下来的 `zoomNamespace`，改这里时对着那边一起改。
            ClipDetailScreen(item: item)
                .navigationTransition(.zoom(sourceID: item.persistentModelID, in: namespace))
        } label: {
            ClipCard(item: item, isFocused: isFocused, isPressed: isPressed, isGhost: isGhost)
        }
        .buttonStyle(.plain)
        // 轻点是复制不是进详情——把 tap 抢在 NavigationLink 之前处理。
        // 进详情走长按菜单的预览点按（系统会执行 link 的目的地）。
        .highPriorityGesture(TapGesture().onEnded { tapped() })
        .matchedTransitionSource(id: item.persistentModelID, in: namespace)
        // 旁白的双击发出的是「激活」，而 `TapGesture` 不是无障碍动作、接不到它：
        // 不改的话激活落在 NavigationLink 自己身上，于是文档写的「轻点复制」对旁白用户
        // 正好反过来——双击进了详情，复制反而只能去转子里翻上下文菜单。
        // 这里把默认动作改写成复制，进详情降级成一条具名动作。
        //
        // 两组修饰必须挂在 **NavigationLink 外面**：写进 label 里会被按钮的元素吞掉
        // （按钮把 label 的无障碍元素并进自己），激活动作仍然是导航，等于没改。
        .accessibilityAction { tapped() }
        .accessibilityActions { accessibilityActionList }

        if allowsDrag {
            link.draggable(item.transferable) {
                ClipCard(item: item, isLifted: true)
                    .frame(width: max(240, previewWidth))
                    .onAppear { onDragChanged(true) }
                    .onDisappear { onDragChanged(false) }
            }
        } else {
            link
        }
    }

    /// 转子里的具名动作。旁白确实会把 `.contextMenu` 暴露出来，但那要先展开一层菜单；
    /// 这几条是这张卡的日常操作，摆在第一层。
    ///
    /// 「打开详情」只回调 `onOpenDetail`，推入动作由历史页的 `navigationDestination(item:)` 做。
    /// 卡片**不能**自带 `navigationDestination`：它住在 `MasonryGrid` 的 `LazyVStack` 里，
    /// 每张实体化的卡片都会往同一个 `NavigationStack` 注册一份互相打架的目的地，
    /// 而被回收的卡片那份会连带失效——表现就是这条动作按下去悄无声息地什么也不发生。
    ///
    /// **没有**「固定」：固定要选板，是个子菜单，具名动作没有层级；而外面那层 `SwipeableCard`
    /// 已经把右滑固定做成了具名动作，口径是「默认板」。这里再给一条「固定到第一个板」
    /// 只会得到两条名字相近、落点不同的动作。取消固定没有这个问题，所以留在这里。
    ///
    /// **也没有**「删除」：外层 `SwipeableCard` 已经给了同名的具名动作，而它和这张卡合成的是
    /// **同一个**停留点——两边都给，转子里就会连着念两次「删除」，名字一样却分不出哪条是哪条。
    /// 删除归 `SwipeableCard`（左滑手势本来就是它的），这里不要再加回来。
    ///
    /// `ClipCard` 现在是一个合成元素（`children: .ignore` + 自带标签），
    /// 这些动作全部挂在那一个停留点上。
    @ViewBuilder
    private var accessibilityActionList: some View {
        Button(String(localized: "Open Details")) { onOpenDetail() }
        Button(String(localized: "Copy as Plain Text")) { onCopyPlainText() }
        if item.pinboard != nil {
            Button(String(localized: "Remove from Pinboard")) { onUnpin() }
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
