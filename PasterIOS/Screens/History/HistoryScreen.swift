import PasterCore
import SwiftData
import SwiftUI

/// 历史主屏（设计 01 / 01b–01g，以及 09 的网格部分）。
///
/// 一个界面同时服务 iPhone 双列与 iPad 三列：列数、内边距、是否显示筛选 chips、
/// 是否接硬件键盘全部由「当前布局是不是 regular」这一条推出来，不再分两套视图——
/// 两套视图迟早会在卡片手势这类细节上走形。
///
/// 外部只依赖 `HistoryScreen(kindFilter:)`：iPad 侧栏选中某个类型时把它传进来。
struct HistoryScreen: View {

    /// iPad 侧栏传入的类型筛选；nil 表示由页内 chips 决定
    var kindFilter: ClipKind?

    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// 分栏 detail 列会把它设成 true。不能只看自己有多宽：
    /// iPad Pro 11 竖屏的 detail 列只有约 545pt，「宽 ≥ 600」在那台机器上恒为假，
    /// 于是筛选 chips 与侧栏分类会同时出现且互相矛盾、⌘F 双重注册、三列网格与快捷键提示条都不生效。
    @Environment(\.pasterIsSplitDetail) private var isSplitDetail

    @Query(sort: \ClipItem.createdAt, order: .reverse) private var items: [ClipItem]
    @Query(sort: [SortDescriptor(\Pinboard.sortIndex), SortDescriptor(\Pinboard.createdAt)])
    private var boards: [Pinboard]

    /// iPad detail 列导航栏右侧的排序菜单写的就是这个键；
    /// iPhone 上没有排序入口，值恒为默认的「按时间」，与 @Query 的顺序一致。
    @AppStorage(ClipSortOrder.storageKey, store: IOSSettings.defaults)
    private var sortRaw = ClipSortOrder.time.rawValue

    /// 卡片 → 详情的 zoom 转场源
    @Namespace private var zoomNamespace

    /// 滚动视图的可见尺寸，用来推列数与卡片宽度
    @State private var viewportSize: CGSize = .zero
    /// 硬件键盘焦点所在的条目
    @State private var focusedItemID: PersistentIdentifier?
    /// 刚插入的条目短暂带焦点环（设计 01d，0.8s 后消失）
    @State private var highlightRingID: PersistentIdentifier?
    @State private var detailItem: ClipItem?
    @State private var previewItem: ClipItem?
    /// 正在被拖走的条目：原位留一张 35% 的影子（设计 09 的 ghost 卡）
    @State private var draggingItemID: PersistentIdentifier?
    /// 一个 Pinboard 都没有时，右滑固定 / 菜单新建都会先弹这个输入框（设计 03c 的形态）
    @State private var showsNewBoardAlert = false
    @State private var newBoardName = ""
    @State private var pendingPinItem: ClipItem?
    @State private var didApplyDemoRoute = false

    @FocusState private var searchFocused: Bool
    @FocusState private var gridFocused: Bool

    var body: some View {
        @Bindable var model = model
        // 一次 body 里 visibleItems 会被读到三四次，每次都是一遍 filter + filter + sort。
        // 求值一次往下传，别让它跟着 body 反复跑。
        let visible = visibleItems
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isRegularLayout {
                    // 设计 09 的内容区标题：28 Bold 画在内容里，不是导航栏的 34pt 大标题
                    Text(columnTitle)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(PasterTheme.label)
                        .padding(.top, 4)
                }
                if showsFilterChips {
                    HistoryFilterChips(selection: $model.kindFilter)
                        .padding(.top, 12)
                }
                if model.pasteBannerVisible {
                    PasteBanner(saved: model.pasteBannerSaved,
                                onPaste: { model.handlePasteControl(itemProviders: $0) },
                                onDismiss: { model.dismissPasteBanner() })
                    .padding(.top, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                if isSearching {
                    Text(resultCountText(visible))
                        .font(PasterTheme.Fonts.footnote)
                        .foregroundStyle(PasterTheme.labelSecondary)
                        .padding(.top, 14)
                }
                content(visible)
                    .padding(.top, 16)
            }
            .padding(.horizontal, pageInset)
            .padding(.bottom, isRegularLayout ? 0 : 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PasterTheme.bgGrouped)
        // 设计 3.12 的 fade：列表底部 140pt 渐隐到 92% 背景色，
        // 让最后一张卡片是「淡出」而不是被标签栏硬切一刀。iPad 分栏的设计 09 里没有这一层。
        .overlay(alignment: .bottom) {
            if !isRegularLayout {
                LinearGradient(colors: [PasterTheme.bgGrouped.opacity(0), PasterTheme.bgGrouped.opacity(0.92)],
                               startPoint: .top,
                               endPoint: .bottom)
                    .frame(height: 140)
                    .allowsHitTesting(false)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { viewportSize = $0 }
        // 焦点挂在滚动视图上：硬件键盘的方向键 / ↵ / 空格 / ⌫ 都要先有焦点才收得到
        .focusable()
        .focusEffectDisabled()
        .focused($gridFocused)
        .onKeyPress(phases: .down) { handleKeyPress($0) }
        .background(alignment: .topLeading) { commandShortcuts }
        // regular 布局下标题自绘在内容里（上面那一行 28 Bold），导航栏只留工具栏
        .navigationTitle(isRegularLayout ? "" : PasterTab.history.title)
        .navigationBarTitleDisplayMode(isRegularLayout ? .inline : .large)
        // 搜索框只在 compact 出现：设计 09 的搜索在侧栏，且侧栏那条已经带 ⌘F 提示。
        // 关键词由 AppModel.sidebarSearchText 喂进 searchText，过滤逻辑两边共用。
        .modifier(HistorySearchable(enabled: !isRegularLayout,
                                    text: $model.searchText,
                                    focus: $searchFocused))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SyncStatusPill(status: model.syncStatus.status, size: .phone) {
                    goToSettings()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isRegularLayout {
                HistoryShortcutHints()
            }
        }
        .navigationDestination(item: $detailItem) { item in
            ClipDetailScreen(item: item)
                .navigationTransition(.zoom(sourceID: item.persistentModelID, in: zoomNamespace))
        }
        .sheet(item: $previewItem) { item in
            ClipPreviewSheet(item: item)
        }
        .alert(String(localized: "New Pinboard"), isPresented: $showsNewBoardAlert) {
            TextField(String(localized: "Name"), text: $newBoardName)
            Button(String(localized: "Cancel"), role: .cancel) { pendingPinItem = nil }
            Button(String(localized: "Create")) { createBoardAndPin() }
        } message: {
            Text(String(localized: "It syncs to the Pinboard tab on your Mac."))
        }
        .animation(PasterTheme.springAnimation, value: model.pasteBannerVisible)
        .animation(PasterTheme.springAnimation, value: model.pasteBannerSaved)
        .onChange(of: model.highlightedItemID, initial: true) { _, id in
            showHighlightRing(for: id)
        }
        .onChange(of: isRegularLayout, initial: true) { _, regular in
            // iPad / 外接键盘：宽度一够就把焦点收下来，用户不必先点一下卡片。
            // 用 onChange 而不是 onAppear：首次布局时还没量到宽度，那会儿判断一定是 false。
            if regular { gridFocused = true }
        }
        .task { await applyDemoRouteIfNeeded() }
    }

    // MARK: - 布局

    /// regular 宽度（iPad 全屏 / 1-2 分屏）。Slide Over 与 1/3 分屏宽度不足，按 iPhone 走。
    private var isRegularLayout: Bool {
        horizontalSizeClass == .regular
            && (isSplitDetail || viewportSize.width >= PasterTheme.Metrics.compactWidthThreshold)
    }

    /// 内容区标题：侧栏选了某个分类就显示分类名，否则是「历史」
    private var columnTitle: String {
        guard let kind = kindFilter else { return PasterTab.history.title }
        return KindPresentation.label(kind)
    }

    private var pageInset: CGFloat {
        isRegularLayout ? PasterTheme.Metrics.pageInsetPad : PasterTheme.Metrics.pageInset
    }

    /// iPhone 双列、iPad 三列；搜索态在窄屏退化为单列（设计 01f）
    private var columns: Int {
        if isRegularLayout { return 3 }
        return isSearching ? 1 : 2
    }

    private var columnWidth: CGFloat {
        let available = viewportSize.width > 0 ? viewportSize.width : 390
        let inner = available - pageInset * 2 - PasterTheme.Metrics.gridGap * CGFloat(columns - 1)
        return max(80, inner / CGFloat(columns))
    }

    /// 分类 chips 只在窄屏出现；iPad 上分类由侧栏承担（设计 09 的内容区没有 chips）
    private var showsFilterChips: Bool {
        !isRegularLayout && !items.isEmpty
    }

    // MARK: - 数据

    /// 侧栏传进来的筛选优先，否则用页内 chips 选的
    private var activeKind: ClipKind? { kindFilter ?? model.kindFilter }

    private var searchQuery: String {
        model.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !searchQuery.isEmpty }

    /// 过滤在内存里做：历史条数有上限（设置里最多 1000 条），
    /// 而 predicate 里写不了「富文本算进文本」这种跨字段规则，两处口径必须一致才用同一个 KindPresentation。
    private var visibleItems: [ClipItem] {
        let byKind = items.filter { KindPresentation.matches($0, filter: activeKind) }
        let matched = isSearching
            ? byKind.filter { $0.searchHaystack.localizedCaseInsensitiveContains(searchQuery) }
            : byKind
        return sortOrder.sorted(matched)
    }

    private var sortOrder: ClipSortOrder {
        ClipSortOrder(rawValue: sortRaw) ?? .time
    }

    /// 「N 条结果」。英文要分单复数，所以给两个 key；中文两条译文一样。
    private func resultCountText(_ list: [ClipItem]) -> String {
        let count = list.count
        let format = count == 1 ? String(localized: "%lld result") : String(localized: "%lld results")
        return String(format: format, count)
    }

    // MARK: - 内容

    @ViewBuilder
    private func content(_ visible: [ClipItem]) -> some View {
        if items.isEmpty {
            HistoryEmptyState(onEnableSync: { goToSettings() },
                              onHowToSave: { goToSettings() })
            .frame(maxWidth: .infinity)
            // 设计 01b：空态在搜索栏与标签栏之间居中。
            // 用 containerRelativeFrame 拿滚动视图的可见高度，比自己减安全区准。
            .containerRelativeFrame(.vertical, alignment: .center) { height, _ in
                max(240, height)
            }
        } else if visible.isEmpty {
            EmptyState(symbol: "magnifyingglass",
                       title: String(localized: "No results"),
                       message: String(localized: "Try another keyword or filter."))
            .padding(.top, 60)
        } else {
            grid(visible)
        }
    }

    private func grid(_ visible: [ClipItem]) -> some View {
        MasonryGrid(items: visible,
                    columns: columns,
                    estimatedHeight: { ClipCard.estimatedHeight(for: $0, width: columnWidth, dense: false) }) { item in
            SwipeableCard(onDelete: { delete(item) },
                          onPin: { pinToDefault(item) },
                          pinEnabled: item.pinboard == nil) {
                HistoryCardView(item: item,
                                boards: boards,
                                namespace: zoomNamespace,
                                previewWidth: columnWidth,
                                isFocused: isFocusRing(item),
                                isHighlighted: model.highlightedItemID == item.persistentModelID,
                                isGhost: draggingItemID == item.persistentModelID,
                                allowsDrag: isRegularLayout,
                                onDragChanged: { dragging in
                                    withAnimation(PasterTheme.springAnimation) {
                                        draggingItemID = dragging ? item.persistentModelID : nil
                                    }
                                },
                                onCopy: { copy(item) },
                                onCopyPlainText: { model.copyPlainText(item) },
                                onPin: { model.pin(item, to: $0) },
                                onUnpin: { model.unpin(item) },
                                onCreatePinboard: { promptNewPinboard(pinning: item) },
                                onDelete: { delete(item) })
            }
        }
    }

    private func isFocusRing(_ item: ClipItem) -> Bool {
        let id = item.persistentModelID
        return focusedItemID == id || highlightRingID == id
    }

    // MARK: - 动作

    private func copy(_ item: ClipItem) {
        focusedItemID = item.persistentModelID
        model.copy(item)
    }

    private func delete(_ item: ClipItem) {
        if focusedItemID == item.persistentModelID {
            focusedItemID = neighbourID(of: item)
        }
        withAnimation(PasterTheme.springAnimation) { model.delete(item) }
    }

    /// 删掉焦点所在的条目后，焦点落到它的下一个邻居上，不要凭空消失
    private func neighbourID(of item: ClipItem) -> PersistentIdentifier? {
        let list = visibleItems
        guard let index = list.firstIndex(where: { $0.persistentModelID == item.persistentModelID }) else { return nil }
        if list.indices.contains(index + 1) { return list[index + 1].persistentModelID }
        if list.indices.contains(index - 1) { return list[index - 1].persistentModelID }
        return nil
    }

    /// 右滑固定：一个板都没有时不静默造一个，先问名字（设计 03c 的 Alert）
    private func pinToDefault(_ item: ClipItem) {
        guard !boards.isEmpty else {
            promptNewPinboard(pinning: item)
            return
        }
        model.pinToDefault(item)
    }

    private func promptNewPinboard(pinning item: ClipItem?) {
        pendingPinItem = item
        newBoardName = ""
        showsNewBoardAlert = true
    }

    private func createBoardAndPin() {
        let trimmed = newBoardName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? String(localized: "Pinboard") : trimmed
        let board = model.createPinboard(named: name)
        if let item = pendingPinItem {
            model.pin(item, to: board)
        }
        pendingPinItem = nil
        newBoardName = ""
    }

    private func goToSettings() {
        model.selectedTab = .settings
        model.sidebarSelection = .settings
    }

    /// 新条目的焦点环只亮 0.8s（设计 01d），之后回到普通卡片
    private func showHighlightRing(for id: PersistentIdentifier?) {
        guard let id else { return }
        highlightRingID = id
        // 截图路由要的就是这一帧，别让它自己灭掉
        guard model.demoRoute != .historySaved else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard highlightRingID == id else { return }
            withAnimation(PasterTheme.springAnimation) { highlightRingID = nil }
        }
    }

    // MARK: - 硬件键盘

    /// ⌘F / ⌘P 走 keyboardShortcut（带修饰键的组合交给系统匹配更稳），
    /// 方向键、↵、空格、⌫ 走 onKeyPress。两边不重叠，免得一次按键触发两回。
    private var commandShortcuts: some View {
        ZStack {
            // regular 宽度下 ⌘F 由 iPad 侧栏的搜索框接管；两处都注册的话谁生效不确定
            if !isRegularLayout {
                Button(String(localized: "Search")) { searchFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
            }
            Button(String(localized: "Pin")) {
                if let item = focusedItem() { pinToDefault(item) }
            }
            .keyboardShortcut("p", modifiers: .command)
        }
        .frame(width: 1, height: 1)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func focusedItem() -> ClipItem? {
        guard let focusedItemID else { return nil }
        return visibleItems.first { $0.persistentModelID == focusedItemID }
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        guard !visibleItems.isEmpty else { return .ignored }
        switch press.key {
        case .upArrow:
            moveFocus(by: -columns)
            return .handled
        case .downArrow:
            moveFocus(by: columns)
            return .handled
        case .leftArrow:
            moveFocus(by: -1)
            return .handled
        case .rightArrow:
            moveFocus(by: 1)
            return .handled
        case .return:
            guard let item = focusedItem() else { return .ignored }
            if press.modifiers.contains(.shift) {
                model.copyPlainText(item)
            } else {
                model.copy(item)
            }
            return .handled
        case .space:
            guard let item = focusedItem() else { return .ignored }
            previewItem = item
            return .handled
        case .delete, .deleteForward:
            guard let item = focusedItem() else { return .ignored }
            delete(item)
            return .handled
        default:
            return .ignored
        }
    }

    /// 焦点按扁平顺序移动：↑↓ 跨一行（±列数）、←→ 跨一张。
    /// 瀑布流的视觉位置与数组下标并不严格对应（贪心分列会打乱），但方向感是对的。
    private func moveFocus(by delta: Int) {
        let list = visibleItems
        guard !list.isEmpty else { return }
        guard let current = focusedItemID,
              let index = list.firstIndex(where: { $0.persistentModelID == current }) else {
            focusedItemID = list.first?.persistentModelID
            return
        }
        let target = min(max(index + delta, 0), list.count - 1)
        focusedItemID = list[target].persistentModelID
    }

    // MARK: - 截图路由

    /// `-demoScreen` 里属于历史页的细节状态。只在 `-demoData`（内存库）下生效，
    /// 任何情况下都不会写用户的真实数据库。
    private func applyDemoRouteIfNeeded() async {
        guard !didApplyDemoRoute, let route = model.demoRoute, model.launch.useDemoData else { return }
        didApplyDemoRoute = true
        // 等搜索栏自己装好再写搜索词：`.searchable` 在首次布局时会把绑定回写成空串，
        // 在那之前设的值会被吞掉。
        try? await Task.sleep(for: .milliseconds(400))
        switch route {
        case .historySearch:
            model.searchText = HistoryDemoContent.searchQuery
        case .historySaved:
            insertDemoSavedItem()
        case .detailText, .detailRich, .detailColor, .detailImage, .detailLink, .detailFile:
            detailItem = demoDetailItem(for: route)
        default:
            break
        }
    }

    /// 设计 01d 的 `savedItem`：一键保存后新插进历史顶部的那条。样例数据里没有，现场造一条。
    private func insertDemoSavedItem() {
        let item = ClipItem(kind: .text, plainText: HistoryDemoContent.savedText)
        item.createdAt = Date()
        model.modelContext.insert(item)
        try? model.modelContext.save()
        model.highlightedItemID = item.persistentModelID
        // 真实链路里这条提示由 AppModel 在存下内容时给；截图路由是直接插数据，得自己补上
        model.toast.show(String(localized: "Saved"))
    }

    private func demoDetailItem(for route: DemoRoute) -> ClipItem? {
        switch route {
        // detail-text 对应设计 02 的长文本条目（有来源 App 的那条），不是本机的验证码短文本
        case .detailText: items.first { $0.kind == .text && $0.sourceAppName != nil && !$0.isMono }
        case .detailRich: items.first { $0.kind == .richText }
        case .detailColor: items.first { $0.kind == .color }
        case .detailImage: items.first { $0.kind == .image }
        case .detailLink: items.first { $0.kind == .link }
        case .detailFile: items.first { $0.kind == .file }
        default: nil
        }
    }
}

// MARK: - 条件搜索栏

/// `.searchable` 只在 compact 布局挂上。写成 ViewModifier 是因为条件修饰符会改变视图类型，
/// 在 body 里直接 `if` 包不住整条链。
private struct HistorySearchable: ViewModifier {
    let enabled: Bool
    @Binding var text: String
    var focus: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        if enabled {
            content
                .searchable(text: $text,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: Text(String(localized: "Search history")))
                .searchFocused(focus)
        } else {
            content
        }
    }
}

// MARK: - 搜索匹配

private extension ClipItem {
    /// 搜索命中的范围：正文为主，链接与文件另带上标题（域名 / 文件名），
    /// 否则搜 "developer.apple.com" 找不到那条链接。
    var searchHaystack: String {
        switch kind {
        case .link, .file: "\(plainText ?? "")\n\(displayTitle)"
        default: plainText ?? ""
        }
    }
}

// MARK: - 截图样例文案

/// 只服务 `-demoScreen`，不进本地化目录：这些是样例内容，不是界面文案。
private enum HistoryDemoContent {
    private static var isEnglish: Bool {
        Locale.current.language.languageCode?.identifier != "zh"
    }

    /// 设计 01f 的搜索词。样例数据两种语言的正文不同，各挑一个能命中的词。
    static var searchQuery: String {
        isEnglish ? "Q4" : "会议"
    }

    static var savedText: String {
        isEnglish
            ? "Order SF1364 0027 8891 arrives today before 6 PM. Please keep your phone nearby."
            : "订单号 SF1364 0027 8891，预计今天 18:00 前送达，请保持电话畅通。"
    }
}
