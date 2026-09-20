import CopyoCore
import SwiftData
import SwiftUI

/// 历史主屏（设计 01 / 01b–01g，以及 09 的网格部分）。
/// 外部只依赖 `HistoryScreen(kindFilter:)`：iPad 侧栏选中某个类型时把它传进来。
///
/// 这一层只做一件事：把筛选条件（类型、防抖后的关键词、排序）从 environment 里取出来，
/// 交给 `HistoryContent` 的 init。拆两层是被 `@Query` 逼的——动态 predicate 只能在 init 里建，
/// 而 init 里读不到 environment。
///
/// 关键词一路上有两个值，别弄混：输入框绑的是 `model.searchText`，真正驱动取数的是防抖 250ms
/// 之后的 `model.debouncedSearchText`（见 `AppModel.scheduleSearchDebounce`）。打字时两层 body
/// **都不重跑**——`HistoryContent.body` 只用 `$model.searchText` 组一个 Binding，而 `@Bindable`
/// 的投影从不**读**值，也就登记不了观察；这一层更是从头到尾没碰过 `searchText`。重跑的只有
/// 搜索框自己。防抖落地时重跑的反而是**这一层**（只有它读 `debouncedSearchText`），把新的
/// `query` 传下去，顺带让 `HistoryContent.init` 重建一次 `@Query`。
/// 所以「不会每个字母重建一次 `@Query`」是防抖挡下来的，不是拆两层挡下来的。
struct HistoryScreen: View {

    /// iPad 侧栏传入的类型筛选；nil 表示由页内 chips 决定
    var kindFilter: ClipKind?

    @Environment(AppModel.self) private var model

    /// iPad detail 列导航栏右侧的排序菜单写的就是这个键；
    /// iPhone 上没有排序入口，值恒为默认的「按时间」，与 @Query 的顺序一致。
    @AppStorage(ClipSortOrder.storageKey, store: IOSSettings.defaults)
    private var sortRaw = ClipSortOrder.time.rawValue

    var body: some View {
        HistoryContent(kindFilter: kindFilter,
                       activeKind: kindFilter ?? model.kindFilter,
                       query: model.debouncedSearchText,
                       sortOrder: ClipSortOrder(rawValue: sortRaw) ?? .time)
    }
}

// MARK: - 正文

/// 一个界面同时服务 iPhone 双列与 iPad 三列：列数、内边距、是否显示筛选 chips、
/// 是否接硬件键盘全部由「当前布局是不是 regular」这一条推出来，不再分两套视图——
/// 两套视图迟早会在卡片手势这类细节上走形。
private struct HistoryContent: View {

    /// iPad 侧栏传入的类型筛选。只用来决定内容区标题——实际筛选看 `activeKind`
    let kindFilter: ClipKind?
    /// 真正生效的类型筛选：侧栏传进来的优先，否则是页内 chips 选的
    let activeKind: ClipKind?
    /// 防抖之后的搜索词（已 trim）。`@Query` 的 predicate 就是用它建的，
    /// 与输入框绑的 `model.searchText` 不是同一个值
    let query: String
    let sortOrder: ClipSortOrder

    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// 分栏 detail 列会把它设成 true。不能只看自己有多宽：
    /// iPad Pro 11 竖屏的 detail 列只有约 545pt，「宽 ≥ 600」在那台机器上恒为假，
    /// 于是筛选 chips 与侧栏分类会同时出现且互相矛盾、⌘F 双重注册、三列网格与快捷键提示条都不生效。
    @Environment(\.copyoIsSplitDetail) private var isSplitDetail

    /// 已经按类型与关键词筛过的条目，顺序是时间倒序
    @Query private var items: [ClipItem]
    /// 只为「整库是不是一条都没有」而存在的探针，取 1 条就够。
    /// 不能拿 `items.isEmpty` 判——它是筛过的，搜不到东西时也会空，
    /// 那时候该出「无结果」，不是「还没有任何内容」的引导空态。
    @Query private var libraryProbe: [ClipItem]
    @Query(sort: [SortDescriptor(\Pinboard.sortIndex), SortDescriptor(\Pinboard.createdAt)])
    private var boards: [Pinboard]

    /// 当前动态字体相对默认档的倍率，传给 `ClipCard.estimatedHeight` 用。
    /// 不传的话放大档位下每张卡都被低估同一个比例，瀑布流两列会明显错开。
    @ScaledMetric(relativeTo: .subheadline) private var typeScale: CGFloat = 1

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

    init(kindFilter: ClipKind?, activeKind: ClipKind?, query: String, sortOrder: ClipSortOrder) {
        self.kindFilter = kindFilter
        self.activeKind = activeKind
        self.query = query
        self.sortOrder = sortOrder
        // 排序一律交给库：`.kind` / `.source` 之后再在内存里重排一次（见 `visibleItems`），
        // 但先按时间取回来能保证同一维度内的相对顺序稳定，不会每次刷新都跳。
        _items = Query(filter: ClipQuery.predicate(kind: activeKind, query: query),
                       sort: \ClipItem.createdAt,
                       order: .reverse)
        var probe = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\ClipItem.createdAt, order: .reverse)])
        probe.fetchLimit = 1
        _libraryProbe = Query(probe)
    }

    var body: some View {
        @Bindable var model = model
        // 求值一次往下传：键盘处理、焦点移动、删除后找邻居都要这份列表，
        // 各自再算一遍就是每次按键重跑一遍 filter + sort。
        let visible = visibleItems
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isRegularLayout {
                    // 设计 09 的内容区标题：28 Bold 画在内容里，不是导航栏的 34pt 大标题
                    Text(columnTitle)
                        .font(.system(.title, weight: .bold))
                        .foregroundStyle(CopyoTheme.label)
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
                        .font(CopyoTheme.Fonts.footnote)
                        .foregroundStyle(CopyoTheme.labelSecondary)
                        .padding(.top, 14)
                }
                content(visible)
                    .padding(.top, 16)
            }
            .padding(.horizontal, pageInset)
            .padding(.bottom, isRegularLayout ? 0 : 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(CopyoTheme.bgGrouped)
        // 设计 3.12 的 fade：列表底部 140pt 渐隐到 92% 背景色，
        // 让最后一张卡片是「淡出」而不是被标签栏硬切一刀。iPad 分栏的设计 09 里没有这一层。
        .overlay(alignment: .bottom) {
            if !isRegularLayout {
                LinearGradient(colors: [CopyoTheme.bgGrouped.opacity(0), CopyoTheme.bgGrouped.opacity(0.92)],
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
        .onKeyPress(phases: .down) { handleKeyPress($0, in: visible) }
        .background(alignment: .topLeading) { commandShortcuts(visible) }
        // regular 布局下标题自绘在内容里（上面那一行 28 Bold），导航栏只留工具栏
        .navigationTitle(isRegularLayout ? "" : CopyoTab.history.title)
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
        .animation(CopyoTheme.springAnimation, value: model.pasteBannerVisible)
        .animation(CopyoTheme.springAnimation, value: model.pasteBannerSaved)
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
            && (isSplitDetail || viewportSize.width >= CopyoTheme.Metrics.compactWidthThreshold)
    }

    /// 内容区标题：侧栏选了某个分类就显示分类名，否则是「历史」
    private var columnTitle: String {
        guard let kind = kindFilter else { return CopyoTab.history.title }
        return KindPresentation.label(kind)
    }

    private var pageInset: CGFloat {
        isRegularLayout ? CopyoTheme.Metrics.pageInsetPad : CopyoTheme.Metrics.pageInset
    }

    /// iPhone 双列、iPad 三列；搜索态在窄屏退化为单列（设计 01f）
    private var columns: Int {
        if isRegularLayout { return 3 }
        return isSearching ? 1 : 2
    }

    private var columnWidth: CGFloat {
        let available = viewportSize.width > 0 ? viewportSize.width : 390
        let inner = available - pageInset * 2 - CopyoTheme.Metrics.gridGap * CGFloat(columns - 1)
        return max(80, inner / CGFloat(columns))
    }

    /// 分类 chips 只在窄屏出现；iPad 上分类由侧栏承担（设计 09 的内容区没有 chips）。
    /// 判据是整库空不空，不是当前结果空不空——筛到一条不剩时 chips 还得在，
    /// 否则用户没有任何入口切回「全部」。
    private var showsFilterChips: Bool {
        !isRegularLayout && !isLibraryEmpty
    }

    // MARK: - 数据

    private var isLibraryEmpty: Bool { libraryProbe.isEmpty }

    private var isSearching: Bool { !query.isEmpty }

    /// 类型与关键词已经由 `@Query` 的 predicate 在库里筛完（见 `ClipQuery`），
    /// 这里只补两件 SQL 表达不了的事：`.file` 的文件名匹配，和按来源排序。
    ///
    /// `.time` 的顺序库里已经排好，不再重排一遍——默认档位下这是最常走的分支，
    /// 而它原本每次 body 都要对整库做一次 O(n log n)。
    private var visibleItems: [ClipItem] {
        let matched = ClipQuery.refine(items, query: query)
        return sortOrder == .time ? matched : sortOrder.sorted(matched)
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
        if isLibraryEmpty {
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
                    estimatedHeight: {
                        ClipCard.estimatedHeight(for: $0,
                                                 width: columnWidth,
                                                 dense: false,
                                                 typeScale: typeScale)
                    }) { item in
            SwipeableCard(onDelete: { delete(item, in: visible) },
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
                                    withAnimation(CopyoTheme.springAnimation) {
                                        draggingItemID = dragging ? item.persistentModelID : nil
                                    }
                                },
                                onCopy: { copy(item) },
                                onCopyPlainText: { model.copyPlainText(item) },
                                onPin: { model.pin(item, to: $0) },
                                onUnpin: { model.unpin(item) },
                                onCreatePinboard: { promptNewPinboard(pinning: item) },
                                onDelete: { delete(item, in: visible) },
                                // 旁白的「打开详情」落到屏幕这一层的 `navigationDestination(item:)`：
                                // 卡片在 `LazyVStack` 里，自带一份目的地会被回收掉，动作就哑了
                                onOpenDetail: { detailItem = item })
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

    private func delete(_ item: ClipItem, in list: [ClipItem]) {
        if focusedItemID == item.persistentModelID {
            focusedItemID = neighbourID(of: item, in: list)
        }
        withAnimation(CopyoTheme.springAnimation) { model.delete(item) }
    }

    /// 删掉焦点所在的条目后，焦点落到它的下一个邻居上，不要凭空消失
    private func neighbourID(of item: ClipItem, in list: [ClipItem]) -> PersistentIdentifier? {
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
            withAnimation(CopyoTheme.springAnimation) { highlightRingID = nil }
        }
    }

    // MARK: - 硬件键盘

    /// ⌘F / ⌘P 走 keyboardShortcut（带修饰键的组合交给系统匹配更稳），
    /// 方向键、↵、空格、⌫ 走 onKeyPress。两边不重叠，免得一次按键触发两回。
    ///
    /// 收 `visible` 而不是自己去读 `visibleItems`：那份列表 body 已经算好了。
    private func commandShortcuts(_ visible: [ClipItem]) -> some View {
        ZStack {
            // regular 宽度下 ⌘F 由 iPad 侧栏的搜索框接管；两处都注册的话谁生效不确定
            if !isRegularLayout {
                Button(String(localized: "Search")) { searchFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
            }
            Button(String(localized: "Pin")) {
                if let item = focusedItem(in: visible) { pinToDefault(item) }
            }
            .keyboardShortcut("p", modifiers: .command)
        }
        .frame(width: 1, height: 1)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func focusedItem(in list: [ClipItem]) -> ClipItem? {
        guard let focusedItemID else { return nil }
        return list.first { $0.persistentModelID == focusedItemID }
    }

    /// 硬件键盘按下一次就会走一遍这里。原来它每次都重算一遍 `visibleItems`，
    /// 长按方向键连发时等于每帧对整库做一次 filter + sort——列表用的那份直接传进来。
    private func handleKeyPress(_ press: KeyPress, in list: [ClipItem]) -> KeyPress.Result {
        guard !list.isEmpty else { return .ignored }
        switch press.key {
        case .upArrow:
            moveFocus(by: -columns, in: list)
            return .handled
        case .downArrow:
            moveFocus(by: columns, in: list)
            return .handled
        case .leftArrow:
            moveFocus(by: -1, in: list)
            return .handled
        case .rightArrow:
            moveFocus(by: 1, in: list)
            return .handled
        case .return:
            guard let item = focusedItem(in: list) else { return .ignored }
            if press.modifiers.contains(.shift) {
                model.copyPlainText(item)
            } else {
                model.copy(item)
            }
            return .handled
        case .space:
            guard let item = focusedItem(in: list) else { return .ignored }
            previewItem = item
            return .handled
        case .delete, .deleteForward:
            guard let item = focusedItem(in: list) else { return .ignored }
            delete(item, in: list)
            return .handled
        default:
            return .ignored
        }
    }

    /// 焦点按扁平顺序移动：↑↓ 跨一行（±列数）、←→ 跨一张。
    /// 瀑布流的视觉位置与数组下标并不严格对应（贪心分列会打乱），但方向感是对的。
    private func moveFocus(by delta: Int, in list: [ClipItem]) {
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
            // 走 applySearchText 而不是直接写 searchText：截图就在下一帧，
            // 等 250ms 防抖的话拍到的是还没筛过的满屏列表
            model.applySearchText(HistoryDemoContent.searchQuery)
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
        // 不用 `items`：它带着当前的类型与关键词条件，`-demoSidebar` 叠上来就会把要找的那条筛掉，
        // 截图静默变成一张空详情页。样例库一共十几条，现取一遍整库最省心。
        let all = demoItems()
        switch route {
        // detail-text 对应设计 02 的长文本条目（有来源 App 的那条），不是本机的验证码短文本
        case .detailText: return all.first { $0.kind == .text && $0.sourceAppName != nil && !$0.isMono }
        case .detailRich: return all.first { $0.kind == .richText }
        case .detailColor: return all.first { $0.kind == .color }
        case .detailImage: return all.first { $0.kind == .image }
        case .detailLink: return all.first { $0.kind == .link }
        case .detailFile: return all.first { $0.kind == .file }
        default: return nil
        }
    }

    private func demoItems() -> [ClipItem] {
        let descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\ClipItem.createdAt, order: .reverse)])
        return (try? model.modelContext.fetch(descriptor)) ?? []
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

// MARK: - 取数条件

/// 历史页的 `@Query` 与 iPad 侧栏的分类计数共用的库内条件。
///
/// 两边必须同源：侧栏说「文本 128」而历史页只列出 96 条，用户会认为数据丢了。
/// 口径与 `KindPresentation.matches` 一一对应——「富文本算进文本」在库里就是
/// `kindRaw == "text" || kindRaw == "richText"`，因为 `kind` 背后是存下来的 `kindRaw`。
///
/// **文件名进不了 predicate，这里是一次有意的妥协。** `.file` 的文件名来自 `displayTitle`
/// （`filePaths` 的末段），它不是 `plainText` 的子串，SQL 判不了；只写 `plainText` 的条件会把
/// 文件名命中悄悄丢掉。正规做法是给 `ClipItem` 加一列去规范化的搜索文本，但那是一次
/// CloudKit schema 变更：`iCloud.dev.vibemage.Copyo` 的 Production schema 已于 2026-09-20 部署，
/// Mac 1.0 正拿它在审核中（见 docs/appstore-submission.md §二十一），这时候改表会让
/// 已上架版本与新版本对不上。所以选择把便宜且区分度高的那半边（类型 + `plainText`）压进库里，
/// 搜索时对 `.file` **整类放行**，再由 `refine(_:query:)` 在内存里逐条补判文件名——
/// 文件类条目本来就是少数，这一小段遍历不值一提。
///
/// 链接不需要这条后路：域名是 URL 串去掉 "www." 的一段，永远是 `plainText` 的子串。
enum ClipQuery {

    /// `nil` 表示「整库，不必带条件」——比塞一个恒真表达式给 SwiftData 去翻译干净。
    static func predicate(kind: ClipKind?, query: String) -> Predicate<ClipItem>? {
        let textRaw = ClipKind.text.rawValue
        let richTextRaw = ClipKind.richText.rawValue
        let fileRaw = ClipKind.file.rawValue

        guard !query.isEmpty else {
            switch kind {
            case .none:
                return nil
            case .some(.text):
                return #Predicate<ClipItem> { $0.kindRaw == textRaw || $0.kindRaw == richTextRaw }
            case .some(let one):
                let raw = one.rawValue
                return #Predicate<ClipItem> { $0.kindRaw == raw }
            }
        }

        // 大小写用 `localizedStandardContains`：`localizedCaseInsensitiveContains` 进不了 `#Predicate`。
        // 它比原来的内存匹配更宽松（连变音符号与全半角一起忽略），只会多命中、不会漏。
        switch kind {
        case .none:
            return #Predicate<ClipItem> {
                $0.kindRaw == fileRaw || ($0.plainText?.localizedStandardContains(query) ?? false)
            }
        case .some(.text):
            return #Predicate<ClipItem> {
                ($0.kindRaw == textRaw || $0.kindRaw == richTextRaw)
                    && ($0.plainText?.localizedStandardContains(query) ?? false)
            }
        case .some(.file):
            return #Predicate<ClipItem> { $0.kindRaw == fileRaw }
        case .some(let one):
            let raw = one.rawValue
            return #Predicate<ClipItem> {
                $0.kindRaw == raw && ($0.plainText?.localizedStandardContains(query) ?? false)
            }
        }
    }

    /// 补判 predicate 整类放行的 `.file`。其他类型库里已经判完，原样通过。
    static func refine(_ items: [ClipItem], query: String) -> [ClipItem] {
        guard !query.isEmpty else { return items }
        return items.filter { item in
            guard item.kind == .file else { return true }
            return item.searchHaystack.localizedStandardContains(query)
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
