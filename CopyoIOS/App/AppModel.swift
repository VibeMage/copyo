import CoreSpotlight
import Observation
import CopyoCore
import SwiftData
import SwiftUI
import UIKit

/// 三个标签。原始值同时当 `-demoScreen` 的落点与 TabView 的 selection。
enum CopyoTab: String, Hashable, CaseIterable {
    case history
    case pinboard
    case settings

    var title: String {
        switch self {
        case .history: String(localized: "History")
        case .pinboard: String(localized: "Pinboard")
        case .settings: String(localized: "Settings")
        }
    }

    var symbol: String {
        switch self {
        case .history: "clock.arrow.circlepath"
        case .pinboard: "pin.fill"
        case .settings: "gearshape.fill"
        }
    }
}

/// iPad 侧栏选中项。`history(nil)` 是「全部历史」，带 kind 时是按类型筛选。
enum SidebarSelection: Hashable {
    case history(ClipKind?)
    case pinboard(PersistentIdentifier)
    case settings
}

/// 全应用共用的状态与动作。所有界面都从 environment 拿它，
/// 复制 / 固定 / 删除的实现只此一份——这几个动作在历史、Pinboard、详情、iPad 网格里都会出现，
/// 分散实现必然会在轻提示、触感、去重标记这些细节上走形。
@MainActor
@Observable
final class AppModel {

    // MARK: - 基础设施

    let container: ModelContainer
    let syncStatus: SyncStatusMonitor
    let toast = ToastCenter()
    let capture: PasteboardCapture
    let launch: LaunchOptions

    var modelContext: ModelContext { container.mainContext }

    // MARK: - 导航

    var selectedTab: CopyoTab = .history
    var sidebarSelection: SidebarSelection? = .history(nil)
    /// 截图模式落到的界面；正常启动为 nil
    let demoRoute: DemoRoute?
    /// 引导是否还要显示（引导代理调 `completeOnboarding()` 关掉）
    var showsOnboarding = false

    /// 要打开详情页的那一条（目前只有系统搜索结果会写它）。
    ///
    /// 详情页是从 `HistoryContent` 私有的 `@State detailItem` 推出来的，应用外面够不着，
    /// 所以沿用截图路由那套形状：外部写状态、界面自己读走并清空。写入方是
    /// `openClipFromSpotlight(_:)`，消费方是 `HistoryContent.openPendingDetailIfNeeded()`。
    var pendingDetailItemID: PersistentIdentifier?

    // MARK: - 历史页共享状态

    /// 顶部搜索框直接绑的关键词。**这一条不做任何延迟**——输入框必须跟手，
    /// 慢半拍用户会以为字没打进去。真正驱动取数的是下面防抖过的 `debouncedSearchText`。
    var searchText = "" {
        didSet { scheduleSearchDebounce(from: oldValue) }
    }

    /// 防抖之后的搜索词（首尾空白已去掉）。历史页的 `@Query` predicate 用它来建：
    /// 直接拿 `searchText` 建的话，条目上万时每敲一个字母就重建一次 predicate 并重扫一遍库，
    /// 打字会明显顿住——ROADMAP 与 docs/ios-plan.md §3.2 记的就是这条缺陷。
    private(set) var debouncedSearchText = ""

    @ObservationIgnored private var searchDebounceTask: Task<Void, Never>?

    /// 防抖窗口。250ms 是分界：再短挡不住连打，再长则按下最后一个字母到列表刷新之间
    /// 会出现肉眼可见的停顿，读起来像卡了一下，而不像「在等你打完」。
    private static let searchDebounceDelay: Duration = .milliseconds(250)

    /// iPad 侧栏搜索框的关键词。regular 宽度下 ⌘F 由侧栏接管，
    /// 输入时同步写进 `searchText`，历史页不必关心关键词是从侧栏还是自己的搜索栏来的。
    var sidebarSearchText = "" {
        didSet { searchText = sidebarSearchText }
    }
    /// 类型筛选（nil = 全部）
    var kindFilter: ClipKind?
    /// 刚插入的条目，历史页据此做一次高亮插入动效
    var highlightedItemID: PersistentIdentifier?

    /// 「新建 Pinboard」Alert 的开关。触发点分散在多处（Pinboard 列表右上的 `+`、空态按钮、
    /// iPad 侧栏 PINBOARD 分组头的 `+`、任意卡片长按菜单里 `PinboardPickerMenu` 的「新建 Pinboard…」），
    /// Alert 本身只由 `RootView` 挂一处——两套布局各挂一个的话，
    /// iPad 上回落到 Pinboard 列表时会有两个宿主绑同一个标志。
    var presentsNewPinboard = false

    // MARK: - 剪贴板横幅（通道 A 的兜底）

    var pasteBannerVisible = false
    /// 横幅上的粘贴按钮已经存下内容，原位换成「已保存」再收起
    var pasteBannerSaved = false

    // MARK: - 系统搜索索引

    /// 整库重建 / 对账都跑在这一个任务里，起新的之前先取消旧的——与 `searchDebounceTask`、
    /// `ToastCenter.show` 同一套写法。上万条的重建会跨好几帧，不取消就会两份同时写索引。
    @ObservationIgnored private var spotlightTask: Task<Void, Never>?

    /// 上一次对账的时刻。**只存在内存里**，因此每次冷启动都必定对一遍——
    /// 进程不在的这段时间里 CloudKit 可能镜像进来一批新增与删除，而那些变更在应用这一侧
    /// 一个调用点都没有。
    @ObservationIgnored private var lastSpotlightReconcile: Date?

    /// 节流窗口。对账要读一遍整库，每次回前台都跑太重；5 分钟足够跟上
    /// 「在 Mac 上存了几条，拿起手机看看」这种真实节奏。
    private static let spotlightReconcileInterval: TimeInterval = 300

    // MARK: - 生命周期

    init(bootstrap: StoreBootstrap, launch: LaunchOptions = .current) {
        self.container = bootstrap.container
        self.launch = launch
        // 演示 / 截图模式不碰小组件：一轮截图会把应用拉起几十次，每次都发一遍刷新请求，
        // 当天真正需要刷新时配额就没了。合在这里就够——`DemoData.populate` 是直接往上下文里
        // 插对象的，不经过任何一个刷新挂点（`SpotlightIndexer` 那道闸必须更早，
        // 因为一键保存会在建库之后立刻走完整条保存链路）。
        WidgetRefresher.isSuspended = launch.useDemoData
        self.demoRoute = launch.demoRoute
        self.syncStatus = SyncStatusMonitor(cloudKitActive: bootstrap.cloudKitActive,
                                            offReason: bootstrap.offReason)
        self.capture = PasteboardCapture(context: bootstrap.container.mainContext)

        // history-empty 要的是「有样例库但一条都没有」，所以只建内存容器、不灌样例
        if launch.useDemoData, launch.demoRoute != .historyEmpty {
            DemoData.populate(in: bootstrap.container.mainContext)
        }
        showsOnboarding = !(launch.skipOnboarding || IOSSettings.onboardingCompleted)
        if let route = launch.demoRoute {
            applyDemoRoute(route)
        }
        capture.onOutcome = { [weak self] outcome in
            self?.handle(outcome)
        }
        // 通道 C 的截图入口：-simulateQuickSave 在这里预置请求，随后第一次 active 就会消费掉
        QuickSaveCoordinator.primeIfSimulated(launch)
        syncStatus.start()
    }

    /// `-demoScreen` 的分发：只设标签与引导开关这类跨界面状态，
    /// 界面自身的细节状态（打开哪张详情、哪个 sheet）由各界面代理在自己的 View 里读 `demoRoute` 决定。
    private func applyDemoRoute(_ route: DemoRoute) {
        selectedTab = route.tab
        showsOnboarding = route.onboardingPage != nil
        switch route {
        case .historyBanner:
            pasteBannerVisible = true
        case .historySaved:
            toast.show(String(localized: "Saved"))
        case .historyEmpty:
            break
        default:
            break
        }
        switch route.tab {
        case .history:
            sidebarSelection = .history(nil)
        case .pinboard:
            // 一个板都没有时回落到历史，侧栏不会停在空选中上
            if let id = PersistentIdentifier.firstPinboardID(in: modelContext) {
                sidebarSelection = .pinboard(id)
            } else {
                sidebarSelection = .history(nil)
            }
        case .settings:
            sidebarSelection = .settings
        }
    }

    /// 场景回到前台：先消费扩展进程留下的那两条明确请求（一键保存、小组件点按复制），
    /// 再做通道 A 的例行检查。顺序不能反——那两条都是用户亲手按下的动作，
    /// 即使用户关了「回到前台自动读取」也要照做。
    ///
    /// 一键保存**排在演示模式的短路之前**：`-simulateQuickSave` 就是靠它在模拟器上走通整条链路，
    /// 这时数据落在内存容器里（见 StoreBootstrap），仍然不会碰真实库。
    func handleScenePhaseActive() {
        // 账号状态与本次激活走哪条采集通道无关，放在最前面，
        // 免得被一键保存的提前 return 顺带跳过（那次激活的胶囊会停在上一次的状态）
        if !launch.useDemoData {
            Task {
                await syncStatus.refreshAccountStatus()
                refreshWidgetSyncStateIfResolved()
            }
        }
        if consumePendingQuickSave() { return }
        // 小组件的「点按复制」与一键保存都是用户明确按下的动作，一样排在演示短路与通道 A 之前。
        // 两者实际上不可能同时待办（用户不会在同一次激活前既按控件又点小组件），
        // 先后顺序只是为了让每一次激活至多被一条明确动作接管。
        if consumePendingWidgetCopy() { return }
        guard !launch.useDemoData else { return }
        // 被一键保存接管的那次激活（上面那行 return）会跳过对账。无所谓：一键保存自己那条
        // 已经在保存时索引过了，而对账本来就是节流的例行维护，下一次激活会补上。
        reconcileSpotlightIfNeeded()
        refreshWidgetsIfLibraryChanged()
        // 引导还盖在屏幕上时不做通道 A 的采集：用户还没看到「Copyo 会读剪贴板」这句话，
        // 这时弹系统「想从 X 粘贴」既突兀又可能把不相干的内容（验证码、口令）直接存进历史。
        // 一键保存是用户明确按下的动作，所以排在这条门禁之前。
        guard !showsOnboarding else { return }
        capture.checkOnForeground()
    }

    /// 扩展进程按下按钮与主应用激活**没有定序保证**：Intent 的 perform 可能晚于这次 active 才落地，
    /// 那一按就会被静默丢弃。场景激活后再补一次消费兜住这个竞态
    /// （30 秒有效期由 `QuickSaveCoordinator` 保证补读不会读到一次很久以前的按下）。
    ///
    /// 名字只提了一键保存，实际上小组件的「点按复制」也走同一条补读——它有同一个竞态。
    /// 改名要连带改 `CopyoIOSApp` 里的调用点，不在本次改动范围内。
    func retryPendingQuickSaveShortly() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            if consumePendingQuickSave() { return }
            consumePendingWidgetCopy()
        }
    }

    /// 通道 C：SaveClipboardIntent 在 App Group 里留了个时间戳，主应用激活时消费它。
    /// 具体规则（有效期、为什么忽略自动读取开关）在 `QuickSaveCoordinator`。
    @discardableResult
    func consumePendingQuickSave() -> Bool {
        QuickSaveCoordinator.consume(with: capture)
    }

    /// 小组件「点按复制」：`CopyClipIntent` 只在 App Group 里留了条目标识符，真正的写剪贴板在这里。
    ///
    /// 必须走 `copy(_:)` 而不是直接写 `UIPasteboard`——它会顺手 `capture.markSeen()`。
    /// 少了那一步，下次回前台通道 A 会把刚写出去的内容再入库一遍，命中去重的 `.refreshed` 分支
    /// 并原地改 `createdAt`，这条内容就会在历史里往上跳一格。完整推演见 `CopyClipIntent`。
    ///
    /// 演示 / 截图模式一律不消费：小组件写的是真实 suite，而这一轮跑的是内存容器里的样例数据，
    /// 标识符对不上，真去复制只会得到一句「这条不在了」的轻提示落进截图里。
    @discardableResult
    func consumePendingWidgetCopy() -> Bool {
        guard !launch.useDemoData else { return false }
        guard let clipID = QuickSaveCoordinator.consumeCopyRequest() else { return false }
        // 解不开或库里已经没有：都是「小组件上那一格已经过期了」，给一句话，不要静默什么都不做
        guard let id = SpotlightIndexer.modelID(from: clipID), let item = clip(with: id) else {
            toast.show(String(localized: "That clip is no longer in Copyo."), symbol: "questionmark.circle")
            return true
        }
        copy(item)
        return true
    }

    // MARK: - 搜索防抖

    /// 程序写入关键词的场景（`-demoScreen history-search` 写完下一帧就截图）走这条：
    /// 写完立刻生效，不能让截图撞上一个还没落地的防抖任务、拍到筛选前的满屏列表。
    func applySearchText(_ text: String) {
        searchText = text
        // 上一行的 didSet 已经排了一次防抖，这里把它取消掉再直接落值
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
        debouncedSearchText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 取消上一个再起一个——与 `ToastCenter.show` 同一套写法。
    private func scheduleSearchDebounce(from oldValue: String) {
        guard searchText != oldValue else { return }
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        // 只补了空格、或者防抖值本来就等于它：别惊动界面，那是一次白重建 @Query
        guard trimmed != debouncedSearchText else { return }
        // 清空必须**立刻**生效：点了搜索框上的 ✕ 就是要马上看回整个列表，
        // 这一下再压 250ms 会被读成卡顿，而不是防抖。
        guard !trimmed.isEmpty else {
            debouncedSearchText = ""
            return
        }
        searchDebounceTask = Task { [trimmed] in
            try? await Task.sleep(for: Self.searchDebounceDelay)
            guard !Task.isCancelled else { return }
            self.debouncedSearchText = trimmed
        }
    }

    // MARK: - 采集结果 → 提示

    private func handle(_ outcome: PasteboardCapture.Outcome) {
        switch outcome {
        case .saved(let item):
            highlightedItemID = item.persistentModelID
            pasteBannerVisible = false
            // 通道 A、通道 C、横幅粘贴三条路的入库都会走到这里（`PasteboardCapture.finish`
            // 把每一次结果都回调上来），所以小组件的刷新挂在这一处就够，
            // 不必像 Spotlight 那样在 `PasteboardCapture` 的两个保存出口各挂一次——
            // 而且只有这里拿得到 `syncStatus`，那份状态要和内容同一时刻抄过去（见 `refreshWidgets`）。
            // 带上 `createdAt`：刚存下的这条就是最新的那条，记下来下次回前台才不会重刷一遍
            refreshWidgets(newestClipAt: item.createdAt)
            toast.show(String(localized: "Saved"))
            feedback(.success)
        case .duplicate(let item):
            highlightedItemID = item.persistentModelID
            pasteBannerVisible = false
            // 去重命中也要刷：`ClipSaver` 的 `.refreshed` 分支原地把 `createdAt` 改成了现在，
            // 这条内容刚刚跳到了历史最前面，小组件上那一格跟着换人
            refreshWidgets(newestClipAt: item.createdAt)
            // 用户按了一键保存却发现内容早就在库里：高亮环可能在可视区外，
            // 不给一句提示的话这一按看起来像是什么都没发生
            if capture.lastOutcomeWasExplicit {
                toast.show(String(localized: "Already saved"), symbol: "checkmark.circle.fill")
            }
        case .needsBanner:
            pasteBannerVisible = true
            pasteBannerSaved = false
        case .failed:
            toast.show(String(localized: "Couldn't save"), symbol: "exclamationmark.triangle.fill")
        case .empty:
            // 通道 A 的例行采集不吭声；一键保存这条路必须有反馈
            if capture.lastOutcomeWasExplicit {
                toast.show(String(localized: "Nothing to save"), symbol: "doc.on.clipboard")
            }
        case .unchanged:
            break
        }
    }

    // MARK: - 横幅

    /// 横幅里的系统粘贴按钮交回来的内容。走这条路不需要「从其他 App 粘贴」的授权。
    func handlePasteControl(itemProviders: [NSItemProvider]) {
        Task {
            let outcome = await capture.save(itemProviders: itemProviders)
            switch outcome {
            case .saved, .duplicate:
                // 设计 01c：原位换成「已保存」，0.4s 后收起
                pasteBannerSaved = true
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation(CopyoTheme.springAnimation) {
                    pasteBannerVisible = false
                    pasteBannerSaved = false
                }
            default:
                break
            }
        }
    }

    func dismissPasteBanner() {
        // 用户手动关掉横幅 = 这份内容不想要了，记下 changeCount 免得下次回前台又弹一次
        capture.markSeen()
        withAnimation(CopyoTheme.springAnimation) { pasteBannerVisible = false }
    }

    // MARK: - 条目动作

    func copy(_ item: ClipItem) {
        switch ClipboardWriter.write(item) {
        case .written:
            capture.markSeen()
            toast.show(String(localized: "Copied"))
            feedback(.success)
        case .unsupported:
            toast.show(String(localized: "Mac only"), symbol: "desktopcomputer")
        case .empty:
            break
        }
    }

    func copyPlainText(_ item: ClipItem) {
        switch ClipboardWriter.writePlainText(item) {
        case .written:
            capture.markSeen()
            toast.show(String(localized: "Copied as plain text"))
            feedback(.success)
        case .unsupported:
            toast.show(String(localized: "Mac only"), symbol: "desktopcomputer")
        case .empty:
            break
        }
    }

    /// Pinboard 内容页的「全部复制为纯文本」：多条拼成一段写进剪贴板。
    /// 走 AppModel 而不是界面直接写 `UIPasteboard`，才能顺带 `markSeen()`——
    /// 少了这一步，下次回前台会把自己刚写进去的内容再存一遍。
    func copyAllAsPlainText(_ items: [ClipItem]) {
        let text = items
            .compactMap { item -> String? in
                let body = (item.plainText ?? item.displayTitle).trimmingCharacters(in: .whitespacesAndNewlines)
                return body.isEmpty ? nil : body
            }
            .joined(separator: "\n\n")
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        capture.markSeen()
        toast.show(String(localized: "Copied as plain text"))
        feedback(.success)
    }

    func pin(_ item: ClipItem, to board: Pinboard) {
        item.pinboard = board
        save()
        // 板名是索引关键词之一（见 `SpotlightIndexer.keywords`），归属一变就得重写那一条
        SpotlightIndexer.index(item)
        // 固定与否只在小尺寸小组件那一格（最新一条）的图钉上看得见，所以这次刷新多半画面不变。
        // 仍然照发：要判断「这一条是不是最近的那一条」本身就得再查一次库，而固定 / 取消固定
        // 是低频的手动动作，白发几次远好过让那枚图钉一直停在旧状态上。`unpin` 同理。
        refreshWidgets()
        toast.show(String(localized: "Pinned"), symbol: "pin.fill")
        feedback(.success)
    }

    /// 右滑固定：没指定目标时进默认 Pinboard，没有默认就进第一个，一个都没有就现建一个。
    func pinToDefault(_ item: ClipItem) {
        let board = defaultPinboard() ?? createPinboard(named: String(localized: "Pinboard"))
        pin(item, to: board)
    }

    func unpin(_ item: ClipItem) {
        item.pinboard = nil
        save()
        SpotlightIndexer.index(item)
        refreshWidgets()
        toast.show(String(localized: "Unpinned"), symbol: "pin.slash")
    }

    func delete(_ item: ClipItem) {
        // 标识符要在 delete 之前取：save 之后 `persistentModelID` 再也拿不回来，
        // 系统索引里那一条就成了孤儿，点开只剩一句「这条不在了」
        let id = item.persistentModelID
        ImageMetadataCache.shared.invalidate(item)
        modelContext.delete(item)
        save()
        SpotlightIndexer.remove([id])
        refreshWidgets()
        toast.show(String(localized: "Deleted"), symbol: "trash.fill")
        feedback(.success)
    }

    func shareItems(for item: ClipItem) -> [Any] {
        ClipboardWriter.shareItems(for: item)
    }

    // MARK: - Pinboard

    func pinboards() -> [Pinboard] {
        let descriptor = FetchDescriptor<Pinboard>(sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func defaultPinboard() -> Pinboard? {
        let boards = pinboards()
        if let name = IOSSettings.defaultPinboardName,
           let match = boards.first(where: { $0.name == name }) {
            return match
        }
        return boards.first
    }

    @discardableResult
    func createPinboard(named name: String, iconName: String? = nil, colorHex: String? = nil) -> Pinboard {
        let nextIndex = (pinboards().map(\.sortIndex).max() ?? -1) + 1
        let board = Pinboard(name: name, sortIndex: nextIndex, iconName: iconName, colorHex: colorHex)
        modelContext.insert(board)
        save()
        return board
    }

    /// 任意界面的「新建 Pinboard…」：先切到 Pinboard 标签，再让列表把 Alert 弹出来。
    /// iPhone 上这样点完就能看到输入框；iPad 侧栏没有「列表」这个选中项，
    /// Alert 会等到用户下次打开 Pinboard 列表时才出现。
    func requestNewPinboard() {
        selectedTab = .pinboard
        presentsNewPinboard = true
    }

    func delete(_ board: Pinboard) {
        let id = board.persistentModelID
        // 默认板设置存的是名字，删掉后不清就会匹配到别的同名板
        if let name = IOSSettings.defaultPinboardName, name == board.name {
            IOSSettings.defaultPinboardName = nil
        }
        // 关系是 nullify：删板不删条目，条目回到历史。
        // 所以这里**不能**把它们从索引里删掉，要反过来重索引一遍：索引里记着板名
        // （见 `SpotlightIndexer.keywords`），板没了那几条的关键词就是错的。
        // 名单要在删板之前收好，删完 `board.items` 就没了。
        let released = board.items ?? []
        modelContext.delete(board)
        save()
        SpotlightIndexer.index(released)
        // 小组件那一份取的是「不带任何条件的最新 N 条」，固定与否本来就都在里面，
        // 而 nullify 既不删条目也不改 `createdAt`，所以**换不了人**。
        // 要刷是因为 `ClipSnapshot.isPinned` 变了——小尺寸上那枚图钉该没了。
        refreshWidgets()
        // iPad 分栏：侧栏还选着这个板的话，detail 列会继续拿着一个已失效的模型对象重算 body，
        // 读 name / items 时命中 SwiftData 的「model instance was invalidated」。复位到历史。
        if sidebarSelection == .pinboard(id) {
            sidebarSelection = .history(nil)
            selectedTab = .history
        }
    }

    // MARK: - 设置

    func completeOnboarding() {
        IOSSettings.onboardingCompleted = true
        withAnimation(CopyoTheme.springAnimation) { showsOnboarding = false }
    }

    /// 用户在设置里调小历史上限后立刻生效，不必等下一次采集
    func applyHistoryLimit(_ limit: Int) {
        IOSSettings.historyLimit = limit
        let evicted = (try? ClipSaver.enforceHistoryLimit(limit, in: modelContext)) ?? []
        SpotlightIndexer.remove(evicted)
        // 这里**故意不刷新小组件**：上限清理删的永远是最旧的那一批，而上限的可选值最小是 100
        //（见 `IOSSettings.historyLimitOptions`），小组件显示的最近 1 / 4 条一条都动不到。
        // 发一次注定画面不变的刷新，白占 WidgetKit 每天那四五十次的配额。
    }

    /// 设置页的系统搜索开关。
    ///
    /// 开 → 把现有历史整库写进索引（对账那条路自己会判断出「账本是空的，该整库重建」）；
    /// 关 → **立刻**清空索引。「以后不再加」不等于「现在看不到」，用户按下这一下要的是后者。
    func applySpotlightIndexing(_ enabled: Bool) {
        spotlightTask?.cancel()
        spotlightTask = nil
        // 演示 / 截图模式一律不碰真实索引（`SpotlightIndexer.isSuspended` 也挡了一道，
        // 这里再挡是为了连轻提示都不要出现在截图里）
        guard !launch.useDemoData else { return }
        guard enabled else {
            SpotlightIndexer.disable()
            lastSpotlightReconcile = nil
            toast.show(String(localized: "Removed from system search"), symbol: "magnifyingglass")
            return
        }
        toast.show(String(localized: "Adding clips to system search"), symbol: "magnifyingglass")
        spotlightTask = Task { @MainActor in
            // 只有跑完整趟才记时刻：中途被取消（用户又把开关拨回去、或回前台触发了新一轮）
            // 时账本没写全，记成功会让下面那道 5 分钟节流把没建完的那一截一直挡在外面。
            if await SpotlightIndexer.reconcile(in: modelContext) {
                lastSpotlightReconcile = Date()
            }
        }
    }

    // MARK: - 系统搜索

    /// Spotlight 结果被点开。`NSUserActivity` 里带的就是我们写进索引的那个 `uniqueIdentifier`。
    ///
    /// 历史页的 `@Query` 现在是**带条件**的（类型 + 搜索词），用户点进来的那一条很可能
    /// 根本不在 `items` 里，所以不能去可见列表里找它——由 `clip(with:)` 走上下文取回。
    /// 顺手把筛选与搜索词清掉：否则从详情页退回来是一张搜不到这条内容的列表，看着像数据丢了。
    ///
    /// `selectSidebar` 一次对齐标签、侧栏选中与类型筛选三者。iPad 上只写 `selectedTab`
    /// 是不够的——`delete(_ board:)` 记着的正是「侧栏停在失效选中上」引发的
    /// 「model instance was invalidated」，这里同样要求两套导航状态一致。
    func openClipFromSpotlight(_ activity: NSUserActivity) {
        guard let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let id = SpotlightIndexer.modelID(from: raw) else { return }
        selectSidebar(.history(nil))
        // iPad 的搜索框绑在侧栏上，只清 searchText 的话侧栏里那行字还在
        sidebarSearchText = ""
        // 立刻落防抖值：这一帧之后界面就要按「无筛选」重建 @Query，不能再等 250ms
        applySearchText("")
        pendingDetailItemID = id
    }

    /// 按标识符取回条目。取不到就是真的没有了（已删除，或换过 store 文件）。
    ///
    /// **不能用 `modelContext.model(for:)`**：它返回的是非可选值，条目已删时给的是一个失效实例
    /// 而不是 nil，详情页一读属性就撞上 SwiftData 的「model instance was invalidated」——
    /// `SplitDetailColumn` 对 Pinboard 记的是同一条教训。
    func clip(with id: PersistentIdentifier) -> ClipItem? {
        var descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        if let match = try? modelContext.fetch(descriptor).first { return match }
        // 兜底整库扫一遍：按标识符建的 predicate 一旦翻译不出来就是「一条都不匹配」，
        // 静默退化成「这条不见了」。这一支只在上面没命中时才跑，而没命中本来就是少数情况。
        let all = (try? modelContext.fetch(FetchDescriptor<ClipItem>())) ?? []
        return all.first { $0.persistentModelID == id }
    }

    // MARK: - 主屏小组件

    /// 库变了：让小组件重取一次时间线，并把**此刻**的同步状态抄进 App Group。
    ///
    /// 状态要顺路抄过去，是因为小组件进程问不出来——`CopyoWidgets.entitlements` 里只有 App Group，
    /// 没有 iCloud 容器也没有 `aps-environment`，`CKContainer` 在那边一句都问不了。
    /// 抄在这一刻而不是另起一条对 `syncStatus` 的订阅：小组件马上就要按这一刻的库内容重画，
    /// 两个值取自同一个瞬间，它头上那句「已同步」说的才是这批内容的状态。
    ///
    /// 代价写明白：分享扩展与 `SaveContentIntent` 写库时主应用没有运行，那两条路只刷新时间线、
    /// 抄不了状态。所以 `CopyoAppGroup.widgetSyncState` 自带有效期，过期就返回 nil、
    /// 小组件干脆不显示那一格。
    /// - Parameter newestClipAt: 这次变更之后最新条目的时刻，知道就传——
    ///   传了 `refreshWidgetsIfLibraryChanged` 下次回前台才不会把同一份变更当成新的再刷一遍。
    private func refreshWidgets(newestClipAt: Date? = nil) {
        // 演示 / 截图模式在这里**必须再挡一道**：`WidgetRefresher.isSuspended` 只拦刷新请求，
        // 拦不住下面那行写 UserDefaults。而它写的是 `CopyoAppGroup.defaults`（真实 suite），
        // 不是 `-demoData` 换过的那个一次性演示 suite——截图跑的往往是 `-localOnly`，
        // 一路写下来就把开发者本人的小组件钉在「未同步」上，而且要钉满一个有效期。
        // LaunchOptions 承诺的是「全部只影响演示状态、不改任何持久化设置」。
        //
        // `-localOnly` 要**单独挡**：它和 `-demoData` 是两个互不相干的开关，
        // 离线冒烟与没有 iCloud 账号的 CI 跑的正是「只加 -localOnly」这一种。
        // 那种启动下 `currentWidgetSyncState` 会算出 `.off` 并写进真实 suite，
        // 开发者本人主屏上的小组件就被钉在「未同步」，还要钉满 24 小时的有效期。
        guard !launch.useDemoData, !launch.localOnly else { return }
        if let newestClipAt { lastWidgetNewestClipAt = newestClipAt }
        CopyoAppGroup.widgetSyncState = currentWidgetSyncState
        WidgetRefresher.reloadRecentClips()
    }

    /// 上一次刷新小组件时，库里最新那条的时刻。**只存在内存里**，所以每次冷启动都会对一次——
    /// 进程不在的这段时间里正是最可能有东西镜像进来的时候。
    @ObservationIgnored private var lastWidgetNewestClipAt: Date?

    /// 回前台时补一次刷新。
    ///
    /// **这是 Mac 上复制的内容进入小组件的唯一通路。** 那些条目是 CloudKit 镜像进来的，
    /// 在应用这一侧一个调用点都没有——`SpotlightIndexer.reconcile` 记的是同一件事。
    /// 少了这一步，「Mac 剪贴板随身带着」这条主线上的内容永远进不了主屏那一格：
    /// 用户在 Mac 上复制、拿起手机，小组件还停在上次自己在手机上存的那条上。
    ///
    /// 先查一次最新条目再决定发不发。`fetchLimit = 1` 的查询比一次注定画面不变的刷新便宜得多，
    /// 而回前台是个高频事件，无条件刷会把 WidgetKit 每天那四五十次配额直接吃光。
    ///
    /// 只看「最新那条变没变」，所以 Mac 上删掉一条**不是最新的**内容时，中尺寸上那一格会留到
    /// 下一次真正的变更为止。要做全也只能像 `SpotlightIndexer.reconcile` 那样整库对账，
    /// 而那是为了「删掉的验证码不能留在锁屏搜索里」才值得的代价，这里没有那个量级的风险。
    private func refreshWidgetsIfLibraryChanged() {
        var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        let newest = (try? modelContext.fetch(descriptor))?.first?.createdAt
        guard newest != lastWidgetNewestClipAt else { return }
        lastWidgetNewestClipAt = newest
        refreshWidgets()
    }

    /// 账号状态解析回来之后补抄一次同步状态。
    ///
    /// `SyncStatusMonitor.init` 在账号查询回来之前一律给「同步中」——那是一次异步查询，
    /// 而同一次激活里 `refreshWidgetsIfLibraryChanged()` 是**同步**跑完的：冷启动时
    /// `lastWidgetNewestClipAt` 还是 nil，只要库非空就必定刷一次，于是抄进 App Group 的
    /// 正是那个还没落定的「同步中」。此后只有本机库发生变更才会再抄一次，
    /// 而「只在 Mac 上复制、手机只用来看」恰恰是这个小组件最主要的用法，那条路上
    /// 一次本机变更都没有——不补这一下，同步一切正常的用户在中尺寸小组件上
    /// 永远看到「同步中…」，直到 24 小时有效期把那一格整个抹掉。
    ///
    /// 只在值真的变了才写并重取时间线：回前台是高频事件，WidgetKit 每天那四五十次
    /// 后台刷新配额经不起每次激活都花一次。
    private func refreshWidgetSyncStateIfResolved() {
        guard !launch.useDemoData, !launch.localOnly else { return }
        let resolved = currentWidgetSyncState
        guard CopyoAppGroup.widgetSyncState != resolved else { return }
        CopyoAppGroup.widgetSyncState = resolved
        WidgetRefresher.reloadRecentClips()
    }

    /// 胶囊的三态压成小组件那一格放得下的三个词。`.off` 的具体原因（没登录 / 关了开关 /
    /// 这份构建没签 entitlement）在小组件上摆不下，一律并成「未同步」。
    private var currentWidgetSyncState: WidgetSyncState {
        switch syncStatus.status {
        case .synced: .synced
        case .syncing: .syncing
        case .off: .off
        }
    }

    // MARK: - 内部

    /// 对账：拿库里的实际内容和账本对一遍，补上 CloudKit 镜像带来的新增与删除——
    /// 那两类变更在应用这一侧没有任何调用点可挂（见 `SpotlightIndexer.reconcile`）。
    private func reconcileSpotlightIfNeeded() {
        guard SpotlightIndexer.isEnabled else { return }
        if let last = lastSpotlightReconcile,
           Date().timeIntervalSince(last) < Self.spotlightReconcileInterval { return }
        spotlightTask?.cancel()
        spotlightTask = Task { @MainActor in
            // 同上：没跑完就不记，让下一次回前台重来一趟
            if await SpotlightIndexer.reconcile(in: modelContext) {
                lastSpotlightReconcile = Date()
            }
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            toast.show(String(localized: "Couldn't save"), symbol: "exclamationmark.triangle.fill")
        }
    }

    private func feedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        // 演示 / 截图时不震，模拟器上也没有触感引擎
        guard !launch.useDemoData else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

private extension PersistentIdentifier {
    /// `-demoScreen pinboard-content` 需要一个具体的板；样例数据刚灌完，取第一个即可。
    /// 一个板都没有时返回 nil，调用方回落到历史。
    static func firstPinboardID(in context: ModelContext) -> PersistentIdentifier? {
        var descriptor = FetchDescriptor<Pinboard>(sortBy: [SortDescriptor(\.sortIndex)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.persistentModelID
    }
}
