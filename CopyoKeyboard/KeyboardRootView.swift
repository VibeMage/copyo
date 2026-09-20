import SwiftUI

/// 键盘的 SwiftUI 根：设计 07 的竖向排布（上留白 10、左右 8、块间距 10）。
///
/// 三面共用同一套外框，只换中间那一块正文区：
///
/// | 面 | 搜索行 | 正文区 | 底排 |
/// | --- | --- | --- | --- |
/// | `.clips`（默认，设计 07） | 有 | 横向卡片条 / 未授权提示 | 有 |
/// | `.letters` / `.symbols` | 只在搜索中有 | 能打字的三排键 | 有 |
///
/// **底排永远在。** 设计 07b 的未授权态也一样——那是这块键盘在没开「完全访问」时
/// 仍然满足 4.4.1 的全部理由，详见 `LetterPlane` 与 `ClipsUnavailableView`。
///
/// 为什么 `.clips` 那一面没有三排键：把 330 拆开算一遍就知道放不下。
/// 上留白 10 + 底排 42 + Home 指示条 40 是固定的，块间距 10，正文区只剩 228；
/// 搜索行 36 + 间距 10 之后是 182，而三排键自己就要 148——两样都要的话卡片条只剩 24pt。
/// 设计 07 画的也正是「没有字母键的卡片条态」。
struct KeyboardRootView: View {
    let scheme: ColorScheme
    /// **宿主通道**：这一套闭包写的是宿主输入框。编辑查询时键位改走 `typingActions`
    /// 里那一套写查询的闭包，但插入卡片内容永远走这一套——
    /// 用户点卡片要的就是把内容送进宿主文稿
    let actions: KeyboardActions
    /// nil = 系统不要求显示地球键（这台设备只装了这一块键盘）
    let globe: GlobeKeyWiring?
    /// 由 UIKit 那侧读好传进来。不在 SwiftUI 里用 `GeometryProxy.safeAreaInsets` 读：
    /// 这棵树整体 `ignoresSafeArea`，那种组合下代理报什么值是实现细节，
    /// 而 `UIViewController.view.safeAreaInsets` 是确定的
    let bottomSafeArea: CGFloat
    /// 只读的共享库。`@Observable`，所以 `state` 变化会自己推到这里，
    /// 不必经过 `KeyboardViewController.refresh()` 换整棵树
    let store: KeyboardClipStore

    /// 左右页边距（设计 07 `padding:10px 8px 0`）
    var horizontalInset: CGFloat = 8
    /// 顶部留白（同上）
    var topInset: CGFloat = 10
    /// 块间距（设计 07 `gap:10`）
    var blockSpacing: CGFloat = 10
    /// 轻提示自己收起前停留多久
    var noticeDuration: Duration = .seconds(2.4)

    @State private var plane: KeyboardPlane = .clips
    /// 查询单独放一个 `@Observable`，理由见 `KeyboardSearch`——**根视图的 `body`
    /// 一个字都不读 `query`**，否则每敲一颗键都会把三排键全部重新求值
    @State private var search = KeyboardSearch()
    /// 长按弹出的预览；nil = 没有
    @State private var preview: KeyboardClip?
    /// 插不进去的那两类（图片、文件）点一下给的轻提示
    @State private var notice: String?

    private var bottomPadding: CGFloat {
        max(0, KeyboardViewController.homeIndicatorStrip - bottomSafeArea)
    }

    var body: some View {
        VStack(spacing: blockSpacing) {
            // 预览浮层只盖到底排**之上**：底排里有地球键，而「随时能切回别的键盘」
            // 是用户在任何时刻都不该被挡住的那一件事。盖住它虽然点一下遮罩就能散开，
            // 但被挡住的那一瞬间人会以为键盘卡死了
            ZStack {
                VStack(spacing: blockSpacing) {
                    if showsSearchRow {
                        KeyboardSearchRow(scheme: scheme,
                                          search: search,
                                          clips: clips,
                                          capturesKeys: isEditingQuery,
                                          onActivate: activateSearch,
                                          onClear: clearSearch)
                    }
                    contentArea
                }
                previewOverlay
                    // 负内距把遮罩顶回键盘框的左右与上边沿。不补这两下，
                    // 页边距那 8pt 与顶部 10pt 会留成一圈没有变暗的边，深色下尤其显眼
                    .padding(.horizontal, -horizontalInset)
                    .padding(.top, -topInset)
            }
            KeyRow(plane: $plane,
                   actions: typingActions,
                   scheme: scheme,
                   globe: globe,
                   submitsSearch: isEditingQuery)
        }
        .padding(.top, topInset)
        .padding(.horizontal, horizontalInset)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CopyoTheme.keyboardBackground(for: scheme))
        .ignoresSafeArea()
        // **键盘是动态字体契约里那个要想一想的例外。** 键帽高被 330 的总高锁死，
        // 字号无上限地跟着放大只会把字母从 42 高的格子里上下切掉——比不放大还难认。
        // 所以夹一个上限：默认到这一档之间照常跟随（放大档位下字确实会变大），
        // 再往上就停住，保证每一颗键上的字仍然是完整的。
        // 卡片条与未授权提示不在这条限制的理由范围内，但它们跟键帽同处一块 330 的框里，
        // 高度一样是借来的，所以一起夹；两处都已经改成「内距 + minHeight」的画法，
        // 夹到这一档之前不会被切字
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .overlay(alignment: .top) { noticeBanner }
        // 只盯 `notice` 一个值：`.animation(_:value:)` 不会把树里别的变化
        // （切面板、换卡片条）一并带上动画
        .animation(CopyoTheme.springAnimation, value: notice)
        .task(id: notice) {
            // `.task(id:)` 会在视图消失或 id 再次变化时自己取消，所以不必另外记一个 Task 句柄；
            // 手工 `Task {}` 在键盘这种随时被摘掉的视图上很容易漏掉取消，
            // 表现是上一条提示在下一次出现时闪一下
            guard notice != nil else { return }
            try? await Task.sleep(for: noticeDuration)
            guard !Task.isCancelled else { return }
            notice = nil
        }
    }

    // MARK: - 正文区

    /// 搜索行什么时候在。
    ///
    /// 搜索进行中一定在——键位敲出来的字进的是它，看不见就是盲打。
    /// 其余时候只有卡片条那一面、而且真读到了库才画：读不到时那一行是句空话
    /// （点下去也搜不出任何东西），而打字面上它只会白占掉 46pt。
    private var showsSearchRow: Bool {
        if search.isActive { return true }
        guard plane == .clips else { return false }
        if case .ready = store.state { return true }
        return false
    }

    @ViewBuilder
    private var contentArea: some View {
        if plane.showsTypingKeys {
            VStack(spacing: 0) {
                // 三排键贴着底排放，手指落点才和系统键盘一致；居中会让整块键盘在视觉上往上飘
                Spacer(minLength: 0)
                LetterPlane(showsSymbols: plane.showsSymbols, actions: typingActions, scheme: scheme)
            }
        } else {
            clipsArea
        }
    }

    @ViewBuilder
    private var clipsArea: some View {
        switch store.state {
        case .loading:
            // `reload()` 是在 `viewWillAppear` 里同步跑完的，这一帧实际上看不到；
            // 画一块透明而不是转圈，是因为转圈在这里只会闪一下，比什么都不画更扎眼
            Color.clear
        case .ready(let loaded):
            ClipStrip(clips: loaded.filter { $0.matches(query: search.query) },
                      scheme: scheme,
                      isFiltered: !search.query.trimmingCharacters(in: .whitespaces).isEmpty,
                      onInsert: insert,
                      onPreview: { preview = $0 })
        case .needsFullAccess:
            ClipsUnavailableView(reason: .needsFullAccess, scheme: scheme)
        case .libraryUnreadable:
            ClipsUnavailableView(reason: .libraryUnreadable, scheme: scheme)
        }
    }

    /// 能筛的全部条目。读不到库时是空数组——搜索行在那种情形下根本不显示
    private var clips: [KeyboardClip] {
        if case .ready(let loaded) = store.state { return loaded }
        return []
    }

    // MARK: - 浮层

    @ViewBuilder
    private var previewOverlay: some View {
        if let preview {
            ClipPreviewOverlay(clip: preview,
                               scheme: scheme,
                               onInsert: {
                                   insert(preview)
                                   self.preview = nil
                               },
                               onDismiss: { self.preview = nil })
        }
    }

    @ViewBuilder
    private var noticeBanner: some View {
        if let notice {
            Text(notice)
                .font(.footnote)
                .foregroundStyle(CopyoTheme.label)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                // 设计 3.4 的轻提示：全圆角、菜单底色。高度不写死，
                // 放大档位下让它自己长高，切字比多占几个点糟得多
                .background(CopyoTheme.menu,
                            in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.toast, style: .continuous))
                .padding(.horizontal, horizontalInset)
                .padding(.top, topInset)
                .transition(.opacity)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    // MARK: - 接线

    /// 键位敲出来的字此刻是不是在写查询。
    ///
    /// **比 `search.isActive` 多一个条件：三排键得真的在屏幕上。**
    /// 按下「搜索」回到卡片条之后这一程还没结束（查询还在、清除按钮还在），
    /// 但正文区已经换回卡片条，只剩底排那几颗键。那时空格与删除若还在改查询，
    /// 用户看着一排能按的键、按下去宿主输入框里什么也不出现，会当成键盘坏了；
    /// 而换行键写着「搜索」、按下去又什么都不变（已经在卡片条上了），是一颗死键。
    /// 所以键位在那一刻交还给宿主，搜索行的 accent 环也跟着灭——三处由这同一个值驱动
    private var isEditingQuery: Bool {
        search.isActive && plane.showsTypingKeys
    }

    /// 键位（三排字符 + 空格 / 删除 / 换行）敲出来的字往哪儿去。
    ///
    /// 正在编辑查询就进查询，其余时候进宿主输入框。**换的是整套闭包，不是在每个按键里判断**：
    /// `LetterPlane` 与 `KeyRow` 因此完全不知道有搜索这回事，
    /// 而键面（换行 / 搜索）与实际行为由同一个 `isEditingQuery` 驱动，不可能各说各话
    private var typingActions: KeyboardActions {
        guard isEditingQuery else { return actions }
        return KeyboardActions(
            insert: { search.query.append($0) },
            deleteBackward: {
                guard !search.query.isEmpty else { return }
                search.query.removeLast()
            },
            space: { search.query.append(" ") },
            // 搜索态下的「换行」键写的是「搜索」，做的就是收起键位去看筛选结果。
            // 查询留着不清：看完结果多半还要接着改关键词
            newline: { plane = .clips }
        )
    }

    /// 点卡片。
    ///
    /// **只走 `actions`（宿主通道），不走 `typingActions`。** 搜索进行中键位写的是查询，
    /// 但卡片内容要的永远是送进宿主文稿——把剪贴内容插进自己的搜索框没有任何意义。
    private func insert(_ clip: KeyboardClip) {
        guard let text = clip.insertion else {
            // 图片与文件插不进去，而且不是本实现偷懒：`textDocumentProxy` 只有
            // `insertText(_:)`，**没有任何 API** 能把图片或带格式的内容塞进宿主文稿。
            // 所以给的是一条说清去哪儿做的提示，不是一次静默的无反应
            notice = clip.kind == .image
                ? String(localized: "Images can only be copied inside Copyo")
                : String(localized: "Files stay on your Mac")
            return
        }
        actions.insert(text)
    }

    private func activateSearch() {
        search.isActive = true
        // 调出键位。已经在打字面上（例如搜索中途翻到数字面）就别把它拨回字母面，
        // 那会把用户正要敲的数字挡掉
        if plane == .clips { plane = .letters }
    }

    private func clearSearch() {
        search.clear()
        plane = .clips
    }
}
