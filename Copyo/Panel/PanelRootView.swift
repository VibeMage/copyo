import AppKit
import CopyoCore
import SwiftData
import SwiftUI

/// 悬浮面板主视图（v2 画板 Main / A-search / A-empty / A-pinboard-* / A-menu）。
///
/// 纵向骨架合计 332：内距 16 + 搜索行 32 + 10 + 筛选行 26 + 12 + 卡片轨道 184 + 12 + 提示条 24 + 内距 16。
/// 历史为空时不画筛选行，空态区 220（第八节第 4 条），合计仍是 332——面板高度在任何状态下都不变。
///
/// 键盘是**单焦点模型**（第 18 条）：文字输入恒进搜索框，← → 恒移卡片，⇥ / ⇧⇥ 切筛选。
/// 所以键盘处理挂在搜索框上；唯一的例外是新建 Pinboard 时胶囊原地变成的输入框（第 20 条）。
struct PanelRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Query(sort: \ClipItem.createdAt, order: .reverse) private var allItems: [ClipItem]
    @Query(sort: \Pinboard.sortIndex) private var pinboards: [Pinboard]

    let actions: PanelActions

    // 截图辅助：-demoSearch <词> 预置搜索词；-demoPreview 启动即打开预览
    static let initialSearch: String = {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-demoSearch"), args.indices.contains(i + 1) {
            return args[i + 1]
        }
        return ""
    }()
    static let initialPreview = ProcessInfo.processInfo.arguments.contains("-demoPreview")

    /// 筛选范围：六项类型筛选与 Pinboard 互斥（选了某个 Pinboard，类型胶囊一个都不亮）
    enum Scope: Equatable {
        case kind(ClipKind?)
        case pinboard(PersistentIdentifier)
    }

    private enum Field: Hashable {
        case search
        case newPinboard
    }

    /// 筛选行的六项（design-spec 7.4.3：两端统一为 全部 / 文本 / 链接 / 图片 / 颜色 / 文件）
    private static let kindFilters: [ClipKind?] = [nil, .text, .link, .image, .color, .file]

    @State private var search = Self.initialSearch
    @State private var scope: Scope = .kind(nil)
    @State private var selectedIndex = 0
    /// 这次选中变化来自 ← → / Home / End（见 `selectFromKeyboard`）。只有键盘移动才把当前卡滚到可视中央（§01）；
    /// 单击、删除后的下标调整、换筛选等只做最小滚动，保证当前卡露出来即可
    @State private var centerOnSelect = false
    @State private var previewOpen = Self.initialPreview
    @State private var editingPinboard = false
    @State private var newPinboardName = ""
    /// 从卡片菜单 / ⌘P 发起「新建 Pinboard」时，建好后要固定进去的那张卡
    @State private var pendingPinItem: ClipItem?
    @State private var syncIndicator: SyncIndicator = .hidden
    @State private var pinboardChipFrame: CGRect = .zero
    @State private var currentCardFrame: CGRect = .zero
    @State private var searchHovering = false
    /// 面板唤出时那一轮首屏预热（7.5.5）。再次唤出、擦除时撤掉，排队中还没开跑的随之取消
    @State private var warmUp: Task<Void, Never>?
    @FocusState private var focus: Field?

    /// meta 一档的颜色：增强对比度时提到 label（第八节第 24 条）
    private var metaColor: Color { contrast == .increased ? CopyoTheme.label : CopyoTheme.labelMeta }

    // MARK: - 派生数据

    private var visibleItems: [ClipItem] {
        let query = search
        let scope = scope
        // 单次遍历完成分组 + 搜索过滤；localizedCaseInsensitiveContains 避免为每条记录分配小写副本
        return allItems.filter { item in
            switch scope {
            case .kind(let kind):
                guard KindPresentation.matches(item, filter: kind) else { return false }
            case .pinboard(let id):
                guard item.pinboard?.persistentModelID == id else { return false }
            }
            guard !query.isEmpty else { return true }
            if item.plainText?.localizedCaseInsensitiveContains(query) == true { return true }
            if item.sourceAppName?.localizedCaseInsensitiveContains(query) == true { return true }
            return item.filePaths.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var selectedPinboard: Pinboard? {
        guard case .pinboard(let id) = scope else { return nil }
        return pinboards.first { $0.persistentModelID == id }
    }

    /// 整个历史一条都没有（与筛选、搜索无关）：走「历史为空」的整版空态，不画筛选行
    private var historyIsEmpty: Bool { allItems.isEmpty }

    // MARK: - 视图

    var body: some View {
        let items = visibleItems
        return VStack(spacing: 0) {
            topRow(resultCount: items.count)
            if historyIsEmpty {
                Spacer().frame(height: 12)
                historyEmptyState
                    .frame(height: 220)
            } else {
                Spacer().frame(height: 10)
                filterRow
                Spacer().frame(height: 12)
                middle(items)
                    .frame(height: CopyoTheme.Dense.cardHeight)
            }
            Spacer().frame(height: 12)
            hintBar
        }
        .padding(CopyoTheme.Dense.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Dense.panelRadius, style: .continuous))
        .onAppear { resetForShow() }
        .onReceive(NotificationCenter.default.publisher(for: .copyoPanelDidShow)) { _ in resetForShow() }
        .onReceive(NotificationCenter.default.publisher(for: .copyoDidEraseAll)) { _ in
            // 宿主视图与进程同寿命，擦除后要自己把指向已删对象的瞬时状态清掉
            warmUp?.cancel()
            warmUp = nil
            scope = .kind(nil)
            search = ""
            selectedIndex = 0
            previewOpen = false
            cancelNewPinboard()
        }
        .onChange(of: search) { _, _ in selectedIndex = 0 }
        .onChange(of: items.count) { _, count in
            // 列表不只在 delete() 里变短：在 Pinboard 里取消固定、菜单栏清空历史、同步导入都会让它缩，
            // 当前卡落在末尾时索引会越界，↩ / 空格 / ⌘P 全部静默失效
            if selectedIndex >= count { selectedIndex = max(0, count - 1) }
        }
        .onChange(of: scope) { _, _ in selectedIndex = 0 }
        .onChange(of: focus) { _, newFocus in
            // 新建 Pinboard 期间焦点离开了那个输入框（点了卡片、点了搜索框）：视为放弃，
            // 否则提示条还写着「↩ 创建 / esc 取消」，按键却已经在别处生效
            if editingPinboard && newFocus != .newPinboard {
                cancelNewPinboard()
                return
            }
            // 单焦点：点卡片、点胶囊都会让搜索框失焦，没有焦点时按键就没人接了。
            // 这不是三区模型里要删的那个「抢回焦点」循环——这里本来就只有一个可聚焦的地方。
            if newFocus == nil {
                Task { @MainActor in focus = .search }
            }
        }
        .onChange(of: previewTarget(items)) { _, _ in syncPreview(items) }
        .onChange(of: previewOpen) { _, _ in syncPreview(items) }
    }

    @ViewBuilder
    private var panelBackground: some View {
        // 截图辅助：-opaquePanel 用纯色底替代毛玻璃（无背景捕获时毛玻璃会渲染成灰条）
        if ProcessInfo.processInfo.arguments.contains("-opaquePanel") {
            CopyoTheme.bgGrouped
        } else {
            GlassBackground(cornerRadius: CopyoTheme.Dense.panelRadius)
        }
    }

    // MARK: 顶栏

    private func topRow(resultCount: Int) -> some View {
        HStack(spacing: 8) {
            searchField(resultCount: resultCount)
            if syncIndicator != .hidden {
                PanelIconButton(help: syncIndicator.help, action: { actions.openSettings(.sync) }) {
                    SyncIndicatorIcon(state: syncIndicator)
                }
            }
            // 两种构建风味都显示齿轮（第 15 条）：直接分发版此前只能右键菜单栏图标进设置。
            // 画板 GEAR_I 17pt、线宽 1.5 → .regular（第八节第 25 条；5.2 表「设置」行；gen_v2.py:185）
            PanelIconButton(help: String(localized: "Settings"), action: { actions.openSettings(nil) }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(CopyoTheme.labelSecondary)
            }
        }
        .frame(height: CopyoTheme.Dense.searchHeight)
    }

    private func searchField(resultCount: Int) -> some View {
        HStack(spacing: 6) {
            // 画板 SEARCH_I 14pt、线宽 1.6 → .medium（5.2 表「搜索」行；gen_v2.py:200）
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CopyoTheme.labelSecondary)
            TextField(String(localized: "Search History"), text: $search)
                .textFieldStyle(.plain)
                .font(CopyoTheme.Dense.Font.search)
                .focused($focus, equals: .search)
                .onKeyPress(phases: .down) { press in handleKeyPress(press) }
            // 「N 条结果」在搜索框右侧（第 5 条）：轨道高度因此恒为 184，打字时卡片不会跳
            if !search.isEmpty && resultCount > 0 {
                Text("\(resultCount) results")
                    .font(.system(size: 11))
                    .foregroundStyle(metaColor)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 10)
        .frame(height: CopyoTheme.Dense.searchHeight)
        // 悬停 fill → fill2 只在没有搜索词时：有词时画焦点环、底色回 fill，悬停也不变（4.3；第八节第 7 条）
        .background((searchHovering && search.isEmpty) ? CopyoTheme.fill2 : CopyoTheme.fill,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { searchHovering = $0 }
        .overlay {
            // 有搜索词时亮焦点环（01c）：告诉用户此刻的按键都在改这个词
            if !search.isEmpty {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(CopyoTheme.accent, lineWidth: 2)
                    .padding(-2)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(CopyoTheme.accent.opacity(0.28), lineWidth: 4)
                        .padding(-4))
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: 筛选行

    private var filterRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Self.kindFilters, id: \.self) { kind in
                    FilterChip(title: filterTitle(kind), isOn: scope == .kind(kind)) {
                        scope = .kind(kind)
                    }
                }
            }
            Spacer(minLength: 8)
            pinboardChip
        }
        .frame(height: CopyoTheme.Dense.chipHeight)
    }

    private func filterTitle(_ kind: ClipKind?) -> String {
        kind.map(KindPresentation.label) ?? String(localized: "All")
    }

    @ViewBuilder
    private var pinboardChip: some View {
        if editingPinboard {
            newPinboardField
        } else {
            FilterChip(title: selectedPinboard?.name ?? String(localized: "Pinboard"),
                       isOn: selectedPinboard != nil,
                       showsChevron: true) {
                showPinboardChipMenu()
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { pinboardChipFrame = $0 }
        }
    }

    /// 新建 Pinboard：胶囊原地变成输入框（第 20 条）。↩ 创建（从卡片发起时顺带固定那张卡），esc 取消。
    /// 这是单焦点模型里唯一的例外——编辑期间文字进这个框。它不是 alert，不会抢走 key window，
    /// 于是此前那套 suppressAutoHide / makePanelKey 补丁整个删掉了。
    private var newPinboardField: some View {
        HStack(spacing: 6) {
            // 画板 PIN_I 12pt、线宽 1.5 → .regular（5.2 表「新建 Pinboard 内联输入框的前导图钉」行；gen_v2.py:208）
            Image(systemName: "pin")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(CopyoTheme.accent)
            TextField(String(localized: "New Pinboard Name"), text: $newPinboardName)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($focus, equals: .newPinboard)
                .onKeyPress(phases: .down) { press in
                    if Self.isComposingText { return .ignored }
                    if press.modifiers.contains(.command), press.characters.lowercased() == "f" {
                        cancelNewPinboard()
                        return .handled
                    }
                    switch press.key {
                    case .return:
                        createPinboard()
                        return .handled
                    case .escape:
                        cancelNewPinboard()
                        return .handled
                    default:
                        return .ignored
                    }
                }
        }
        .padding(.horizontal, 9)
        .frame(width: 188, height: CopyoTheme.Dense.chipHeight)
        .background(CopyoTheme.bgCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(CopyoTheme.accent, lineWidth: 2)
            .padding(-2)
            // 设计稿的外圈光晕：0 0 0 5px rgba(10,132,255,.25)
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(CopyoTheme.accent.opacity(0.25), lineWidth: 3)
                .padding(-3.5))
            .allowsHitTesting(false))
    }

    // MARK: 中段

    @ViewBuilder
    private func middle(_ items: [ClipItem]) -> some View {
        if !items.isEmpty {
            cardStrip(items)
        } else if !search.isEmpty {
            // 搜索无结果：一行字，不用插画——用户在连续打字，不该每打一个字就跳出一张插画（第 3 条）
            centeredLine(String(localized: "Nothing matches “\(search)”"))
        } else if selectedPinboard != nil {
            emptyIllustration(title: String(localized: "This Pinboard is empty"),
                              body: String(localized: "Right-click a card and choose Pin to Pinboard to keep the clips you use most here."),
                              showsHotkey: false)
        } else {
            centeredLine(String(localized: "Nothing of this kind yet"))
        }
    }

    private func centeredLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(CopyoTheme.labelSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 探测出全局快捷键按下去 Copyo 收不到时，不再教用户按它（7.5.1，与菜单栏「打开 Copyo」一致）
    private var historyEmptyState: some View {
        emptyIllustration(title: String(localized: "Nothing here yet"),
                          body: String(localized: "Anything you copy shows up here. Copyo records it in the background — there is nothing you need to do."),
                          showsHotkey: (AppDelegate.shared?.hotkeyStatus ?? .active) == .active)
    }

    private func emptyIllustration(title: String, body: String, showsHotkey: Bool) -> some View {
        HStack(spacing: 24) {
            EmptyPlate()
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(CopyoTheme.Dense.Font.emptyTitle)
                    .foregroundStyle(CopyoTheme.label)
                Text(body)
                    .font(.system(size: 12))
                    .lineSpacing(3)   // 12/17
                    .foregroundStyle(metaColor)
                    .fixedSize(horizontal: false, vertical: true)
                if showsHotkey {
                    // 提示行逐字是「keycap + 随时按 ⇧⌘V 唤出这个面板」，句子里也印组合（§01d；gen_v2.py:316-317）。
                    // keycap 与句子都印当前保存的组合；改键后是否随之改印 §01d 标为设计未定，先跟着改
                    let combo = HotkeyConfig.load().displayString
                    HStack(spacing: 6) {
                        KeyCap(text: combo)
                        Text("Press \(combo) anytime to bring up this panel")
                            .font(.system(size: 11))
                            .foregroundStyle(CopyoTheme.labelSecondary)
                    }
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: 420, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 卡片轨道

    private func cardStrip(_ items: [ClipItem]) -> some View {
        let panelIsKey = controlActiveState == .key || controlActiveState == .active
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                // 每分钟重画一次，卡片上的「3 分钟前」才不会冻住（7.5.4）
                TimelineView(.everyMinute) { timeline in
                    LazyHStack(alignment: .top, spacing: CopyoTheme.Dense.cardGap) {
                        ForEach(Array(items.enumerated()), id: \.element.persistentModelID) { index, item in
                            card(item, index: index, in: items, now: timeline.date,
                                 state: index != selectedIndex ? .normal : (panelIsKey ? .current : .currentInactive))
                        }
                    }
                    // 当前卡的焦点光晕向外扩 7pt：轨道上下左右各留出这一圈，不让 ScrollView 把它裁掉
                    .padding(.vertical, 7)
                    .padding(.horizontal, CopyoTheme.Dense.panelPadding)
                }
            }
            .padding(.vertical, -7)
            .padding(.horizontal, -CopyoTheme.Dense.panelPadding)
            // ← → 移动当前卡时把它滚到可视中央（§01「← → 移动当前卡时」、4.6「当前卡滚动跟随」）；减弱动态时同样居中，只是不包动画。
            // 其余来源（单击、⌘⌫ 后的下标调整、换筛选归零）只滚到刚好露出来：单击可视区里偏右的卡时若整轨平移到中央，
            // 用户在原处接着双击，复制到的是邻卡，而面板随即收起，看不到复制错了。§01 与 4.7「单击卡片」都没写单击要居中
            .onChange(of: selectedIndex) { _, newIndex in
                let anchor: UnitPoint? = centerOnSelect ? .center : nil
                centerOnSelect = false
                guard let id = items[safe: newIndex]?.persistentModelID else { return }
                if reduceMotion {
                    proxy.scrollTo(id, anchor: anchor)
                } else {
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: anchor) }
                }
            }
        }
    }

    private func card(_ item: ClipItem, index: Int, in items: [ClipItem], now: Date, state: CardState) -> some View {
        // 这张卡在屏上期间，替左右各两张预热缩略图与来源图标（7.5.5）；卡片离屏时 task 被取消，
        // 排队中还没开跑的预热随之撤掉。邻居是在 body 里拆好的 Sendable 值，task 里不碰 ClipItem
        let neighbors = ClipPrefetcher.neighbors(of: index, in: items)
        return ClipCardView(item: item,
                     state: state,
                     onPinButton: { togglePin(item, at: nil) },
                     onDelete: { delete(item) },
                     now: now,
                     highlight: search,
                     // 与右键菜单 cardMenu 同序同名（4.7.2、4.4.1）：复制 / 纯文本复制 / 固定（已固定时为取消固定）/ 预览 / 删除。
                     // 「固定到 Pinboard」固定到哪个 Pinboard 与 ⌘P、动作簇图钉是同一处设计空白（4.1.6），沿用图钉按钮的行为
                     accessibilityActions: [
                        CardAccessibilityAction(name: String(localized: "Copy")) { actions.copy(item, false) },
                        CardAccessibilityAction(name: String(localized: "Copy as Plain Text")) { actions.copy(item, true) },
                        CardAccessibilityAction(name: item.pinboard != nil
                                                ? String(localized: "Unpin")
                                                : String(localized: "Pin to Pinboard")) { togglePin(item, at: nil) },
                        CardAccessibilityAction(name: String(localized: "Preview")) {
                            selectedIndex = index
                            previewOpen = true
                        },
                        CardAccessibilityAction(name: String(localized: "Delete")) { delete(item) },
                     ])
            .id(item.persistentModelID)
            .onTapGesture(count: 2) { actions.copy(item, false) }
            .onTapGesture { selectedIndex = index }
            // 拖出按 kind 注册多种表示、多文件卡交出全部文件（§4.5.2、§4.5.3），见 ClipDragSource
            .modifier(ClipDragSource(item: item))
            // macOS 的右键菜单默认只显示 Label 的文字；第 22 条要求菜单项带 SF Symbol，必须显式要图标
            .contextMenu { cardMenu(item, index: index).labelStyle(.titleAndIcon) }
            .modifier(TrackFrame(active: index == selectedIndex, frame: $currentCardFrame))
            .task(id: neighbors.map(\.id)) { await ClipPrefetcher.warm(neighbors) }
    }

    /// 卡片右键菜单（第 22 条）：复制 / 纯文本复制 / ─ / 固定到 Pinboard ▸（已固定时为取消固定）/ 预览 / ─ / 删除。
    /// 「分享」顺延 1.2；面板空白处不再有右键菜单。
    @ViewBuilder
    private func cardMenu(_ item: ClipItem, index: Int) -> some View {
        Button { actions.copy(item, false) } label: { Label("Copy", systemImage: "doc.on.doc") }
        Button { actions.copy(item, true) } label: { Label("Copy as Plain Text", systemImage: "doc.plaintext") }
        Divider()
        if item.pinboard != nil {
            Button { unpin(item) } label: { Label("Unpin", systemImage: "pin.slash") }
        } else {
            Menu {
                // 每行前一枚 10 × 10、圆角 3 的色点（4.4.1 序 3；gen_v2.py:356-361），见 PinboardSwatch
                ForEach(pinboards) { pinboard in
                    Button { pin(item, to: pinboard) } label: {
                        Label {
                            Text(verbatim: pinboard.name)
                        } icon: {
                            Image(nsImage: PinboardSwatch.image(colorHex: pinboard.colorHex))
                        }
                    }
                }
                if !pinboards.isEmpty { Divider() }
                Button("New Pinboard…") { beginNewPinboard(pinning: item) }
            } label: {
                Label("Pin to Pinboard", systemImage: "pin")
            }
        }
        Button {
            selectedIndex = index
            previewOpen = true
        } label: {
            Label("Preview", systemImage: "eye")
        }
        Divider()
        Button(role: .destructive) { delete(item) } label: { Label("Delete", systemImage: "trash") }
    }

    // MARK: 提示条

    private var hintBar: some View {
        HStack(spacing: 14) {
            if editingPinboard {
                KeyHint(keys: "↩", label: pendingPinItem == nil ? String(localized: "Create") : String(localized: "Create and Pin"))
                KeyHint(keys: "esc", label: String(localized: "Cancel"))
            } else {
                KeyHint(keys: "↩", label: String(localized: "Copy"))
                KeyHint(keys: String(localized: "Space"), label: String(localized: "Preview"))
                KeyHint(keys: "⌘P", label: String(localized: "Pin"))
                KeyHint(keys: "⌘⌫", label: String(localized: "Delete"))
            }
            Spacer(minLength: 8)
            Text(hintBarTrailing)
                .font(.system(size: 11))
                .foregroundStyle(CopyoTheme.labelSecondary)
                .lineLimit(1)
        }
        .frame(height: CopyoTheme.Dense.hintHeight)
    }

    private var hintBarTrailing: String {
        if editingPinboard {
            return pendingPinItem == nil ? "" : String(localized: "The current card is pinned to it once it’s created")
        }
        if !search.isEmpty { return String(localized: "Esc clears the search · press again to close") }
        if historyIsEmpty || (selectedPinboard != nil && visibleItems.isEmpty) {
            return String(localized: "Esc to close")
        }
        return String(localized: "Back in your app after copying, press ⌘V to paste")
    }

    // MARK: - 键盘

    /// 输入法正在组字（拼音、日文候选还没上屏）时，↩ / 空格 / esc 属于输入法。
    /// 此前 ↩ 走 onSubmit，组字时不会触发；改成 onKeyPress 之后必须自己让路，
    /// 否则用拼音打搜索词时按 ↩ 选字，会直接把当前卡复制走、面板收起。
    private static var isComposingText: Bool {
        (NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() ?? false
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        if Self.isComposingText { return .ignored }
        let items = visibleItems
        let command = press.modifiers.contains(.command)

        if command, let digit = Int(press.characters), (1...9).contains(digit) {
            // ⌘1–9：直接复制第 N 张并收起（第 18(c) 条）
            if let item = items[safe: digit - 1] { actions.copy(item, false) }
            return .handled
        }
        if command {
            switch press.characters.lowercased() {
            case "f":
                // 单焦点下搜索框本来就有焦点；⌘F 的意义是从任何状态回到这里，并全选方便重打
                cancelNewPinboard()
                focus = .search
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                return .handled
            case "p":
                if let item = items[safe: selectedIndex] { togglePin(item, at: currentCardFrame) }
                return .handled
            case "y":
                if items[safe: selectedIndex] != nil { previewOpen.toggle() }
                return .handled
            default:
                break
            }
        }

        switch press.key {
        case .leftArrow:
            moveSelection(-1, count: items.count)
            return .handled
        case .rightArrow:
            moveSelection(1, count: items.count)
            return .handled
        case .home:
            selectFromKeyboard(0)
            return .handled
        case .end:
            selectFromKeyboard(max(0, items.count - 1))
            return .handled
        case .upArrow, .downArrow:
            // 有意吞掉（第 18(b) 条）：面板是单行横轨，↑↓ 没有含义；
            // 不吞的话会把搜索框的光标甩到行首行尾
            return .handled
        case .tab, Self.backTab:
            // ⇧⇥ 在 AppKit 里来的是 back-tab（U+0019），不是带 shift 的 .tab
            if !historyIsEmpty {
                cycleFilter(backward: press.key == Self.backTab || press.modifiers.contains(.shift))
            }
            return .handled
        case .escape:
            handleEscape()
            return .handled
        case .space where search.isEmpty:
            // 搜索框有字时空格就是空格（第 18(d) 条）；那时要预览用 ⌘Y
            if items[safe: selectedIndex] != nil { previewOpen.toggle() }
            return .handled
        case .delete where command, Self.backspace where command:
            // 真实键盘上 ⌘⌫ 来的是 U+007F，而 KeyEquivalent.delete 是 U+0008——只认后者的话按键落回文本框，
            // 变成「删到行首」（1.1 就是这样，⌘⌫ 从来没删掉过卡片）
            if let item = items[safe: selectedIndex] { delete(item) }
            return .handled
        case .return:
            guard let item = items[safe: selectedIndex] else { return .handled }
            // ⇧↩ 纯文本复制（第 17 条）。⌥↩ 是 1.1 及以前的键位，保留一个版本作隐藏别名，界面上只印 ⇧↩
            let plain = press.modifiers.contains(.shift) || press.modifiers.contains(.option)
            actions.copy(item, plain)
            return .handled
        default:
            return .ignored
        }
    }

    private static let backTab = KeyEquivalent("\u{19}")
    private static let backspace = KeyEquivalent("\u{7F}")

    private func moveSelection(_ delta: Int, count: Int) {
        guard count > 0 else { return }
        selectFromKeyboard(min(max(0, selectedIndex + delta), count - 1))
    }

    /// 键盘移动当前卡：记下来源，`onChange(of: selectedIndex)` 据此滚到可视中央。
    /// 下标没变（已在两端再按）时不置标记，免得它残留到下一次单击上
    private func selectFromKeyboard(_ index: Int) {
        guard index != selectedIndex else { return }
        centerOnSelect = true
        selectedIndex = index
    }

    /// ⇥ / ⇧⇥ 在六项类型筛选间循环（第 18(a) 条）；停在某个 Pinboard 时 ⇥ 回到「全部」
    private func cycleFilter(backward: Bool) {
        let filters = Self.kindFilters
        let count = filters.count
        let current: Int
        if case .kind(let kind) = scope, let index = filters.firstIndex(of: kind) {
            current = index
        } else {
            scope = .kind(nil)
            return
        }
        let next = (current + (backward ? count - 1 : 1)) % count
        scope = .kind(filters[next])
    }

    /// esc 多级：关预览 → 清搜索 → 关面板
    private func handleEscape() {
        if previewOpen {
            previewOpen = false
        } else if !search.isEmpty {
            search = ""
        } else {
            actions.close()
        }
    }

    // MARK: - 预览

    /// 预览开着时要跟着当前卡走；这里给 onChange 一个可比较的键
    private func previewTarget(_ items: [ClipItem]) -> PersistentIdentifier? {
        items[safe: selectedIndex]?.persistentModelID
    }

    private func syncPreview(_ items: [ClipItem]) {
        guard previewOpen, let item = items[safe: selectedIndex] else {
            if previewOpen && items.isEmpty { previewOpen = false }
            actions.preview(nil)
            return
        }
        actions.preview(item)
    }

    // MARK: - Pinboard

    /// 图钉按钮与 ⌘P：已固定就取消固定，否则在卡片旁弹出 Pinboard 列表
    private func togglePin(_ item: ClipItem, at anchor: CGRect?) {
        if item.pinboard != nil {
            unpin(item)
            return
        }
        var entries: [PopupMenu.Entry] = pinboards.map { pinboard in
            .item(title: pinboard.name, action: { pin(item, to: pinboard) })
        }
        if !entries.isEmpty { entries.append(.separator) }
        entries.append(.item(title: String(localized: "New Pinboard…"), symbol: "plus",
                             action: { beginNewPinboard(pinning: item) }))
        let point: NSPoint
        if let anchor, anchor != .zero {
            point = actions.toScreen(CGPoint(x: anchor.minX + 12, y: anchor.minY + 36))
        } else {
            point = NSEvent.mouseLocation
        }
        PopupMenu.show(entries, at: point)
    }

    private func showPinboardChipMenu() {
        var entries: [PopupMenu.Entry] = []
        if let current = selectedPinboard {
            entries.append(.item(title: String(localized: "Show All History"), symbol: "clock",
                                 action: { scope = .kind(nil) }))
            entries.append(.separator)
            entries += pinboards.map { pinboard in
                .item(title: pinboard.name, checked: pinboard.persistentModelID == current.persistentModelID,
                      action: { scope = .pinboard(pinboard.persistentModelID) })
            }
            entries.append(.separator)
            entries.append(.item(title: String(localized: "New Pinboard…"), symbol: "plus",
                                 action: { beginNewPinboard(pinning: nil) }))
            entries.append(.item(title: String(localized: "Delete Pinboard “\(current.name)”"), symbol: "trash",
                                 destructive: true, action: { deletePinboard(current) }))
        } else {
            entries += pinboards.map { pinboard in
                .item(title: pinboard.name, action: { scope = .pinboard(pinboard.persistentModelID) })
            }
            if !entries.isEmpty { entries.append(.separator) }
            entries.append(.item(title: String(localized: "New Pinboard…"), symbol: "plus",
                                 action: { beginNewPinboard(pinning: nil) }))
        }
        let frame = pinboardChipFrame
        PopupMenu.show(entries, at: actions.toScreen(CGPoint(x: frame.minX, y: frame.maxY + 4)))
    }

    private func beginNewPinboard(pinning item: ClipItem?) {
        pendingPinItem = item
        newPinboardName = ""
        editingPinboard = true
        previewOpen = false
        Task { @MainActor in focus = .newPinboard }
    }

    private func cancelNewPinboard() {
        guard editingPinboard else { return }
        editingPinboard = false
        pendingPinItem = nil
        newPinboardName = ""
        focus = .search
    }

    private func createPinboard() {
        let name = newPinboardName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            cancelNewPinboard()
            return
        }
        let pinboard = Pinboard(name: name, sortIndex: (pinboards.last?.sortIndex ?? -1) + 1)
        modelContext.insert(pinboard)
        // 从卡片发起时，建好顺带把那张卡固定进去（第 20 条）
        pendingPinItem?.pinboard = pinboard
        saveContext()
        cancelNewPinboard()
    }

    private func pin(_ item: ClipItem, to pinboard: Pinboard) {
        item.pinboard = pinboard
        saveContext()
    }

    private func unpin(_ item: ClipItem) {
        item.pinboard = nil
        saveContext()
    }

    private func deletePinboard(_ pinboard: Pinboard) {
        if case .pinboard(let id) = scope, id == pinboard.persistentModelID {
            scope = .kind(nil)
        }
        modelContext.delete(pinboard)
        saveContext()
    }

    // MARK: - 其他操作

    private func resetForShow() {
        // 面板每次呼出时重置瞬时状态（截图模式下重置到注入的演示状态）；筛选范围保留
        search = Self.initialSearch
        selectedIndex = 0
        previewOpen = Self.initialPreview
        editingPinboard = false
        pendingPinItem = nil
        newPinboardName = ""
        syncIndicator = SyncIndicator.current()
        if case .pinboard(let id) = scope, !pinboards.contains(where: { $0.persistentModelID == id }) {
            scope = .kind(nil)
        }
        // 历史为空时筛选行是藏起来的，别让一个看不见的筛选挡住第一条真实剪贴
        if historyIsEmpty { scope = .kind(nil) }
        focus = .search
        // 面板唤出：首屏与紧随其后的几张先排进后台加载（7.5.5）。面板还在淡入，卡片上屏时多半已经是真图；
        // 已经在缓存里的直接命中，不会重复读盘
        warmUp?.cancel()
        let targets = ClipPrefetcher.firstScreen(of: visibleItems)
        warmUp = Task { await ClipPrefetcher.warm(targets) }
        // previewOpen 可能本来就是这个值（-demoPreview），onChange 不会触发；
        // 等这一轮跑完、面板已经上屏，再主动同步一次预览窗
        Task { @MainActor in syncPreview(visibleItems) }
    }

    private func saveContext() {
        // 面板挂在 LSUIElement 应用里，autosave 时机不可靠，操作后显式落盘
        try? modelContext.save()
    }

    private func delete(_ item: ClipItem) {
        // 先记下删之前的数量：@Query 要到下一次渲染才反映删除，删完立刻数会把被删的那条也算进去
        let countBefore = visibleItems.count
        modelContext.delete(item)
        saveContext()
        if selectedIndex >= countBefore - 1 {
            selectedIndex = max(0, countBefore - 2)
        }
    }
}

/// 只给当前卡记下它在窗口里的位置（⌘P 的 Pinboard 菜单要弹在它旁边）。
/// 修饰符恒定挂在每张卡上、只有当前卡产出值：若按 active 在两个分支间切换，视图身份会变，
/// 换卡时新旧两张都被整棵重建——焦点环的 spring 动画播不出来，悬停态也会被清零。
private struct TrackFrame: ViewModifier {
    let active: Bool
    @Binding var frame: CGRect

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect?.self) { active ? $0.frame(in: .global) : nil } action: { newFrame in
            if let newFrame { frame = newFrame }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
