import Observation
import PasterCore
import SwiftData
import SwiftUI
import UIKit

/// 三个标签。原始值同时当 `-demoScreen` 的落点与 TabView 的 selection。
enum PasterTab: String, Hashable, CaseIterable {
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

    var selectedTab: PasterTab = .history
    var sidebarSelection: SidebarSelection? = .history(nil)
    /// 截图模式落到的界面；正常启动为 nil
    let demoRoute: DemoRoute?
    /// 引导是否还要显示（引导代理调 `completeOnboarding()` 关掉）
    var showsOnboarding = false

    // MARK: - 历史页共享状态

    /// 顶部搜索词
    var searchText = ""
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
    /// 任意卡片长按菜单里 `PinboardPickerMenu` 的「新建 Pinboard…」），Alert 本身只由
    /// `PinboardListScreen` 挂一处，免得同一时刻弹出两个。
    var presentsNewPinboard = false

    // MARK: - 剪贴板横幅（通道 A 的兜底）

    var pasteBannerVisible = false
    /// 横幅上的粘贴按钮已经存下内容，原位换成「已保存」再收起
    var pasteBannerSaved = false

    // MARK: - 模态

    /// 「新建 Pinboard」输入框是否弹出。放在 model 上是因为触发点不止一处：
    /// iPad 侧栏的 PINBOARD 分组头、Pinboard 列表页的 + 都要能拉起同一个 Alert。
    var presentsNewPinboardAlert = false

    // MARK: - 生命周期

    init(bootstrap: StoreBootstrap, launch: LaunchOptions = .current) {
        self.container = bootstrap.container
        self.launch = launch
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

    /// 场景回到前台：先消费一键保存，再做通道 A 的例行检查。
    /// 顺序不能反——一键保存是用户明确的动作，即使用户关了自动读取也要存。
    ///
    /// 一键保存**排在演示模式的短路之前**：`-simulateQuickSave` 就是靠它在模拟器上走通整条链路，
    /// 这时数据落在内存容器里（见 StoreBootstrap），仍然不会碰真实库。
    func handleScenePhaseActive() {
        if consumePendingQuickSave() { return }
        guard !launch.useDemoData else { return }
        capture.checkOnForeground()
        Task { await syncStatus.refreshAccountStatus() }
    }

    /// 通道 C：SaveClipboardIntent 在 App Group 里留了个时间戳，主应用激活时消费它。
    /// 具体规则（有效期、为什么忽略自动读取开关）在 `QuickSaveCoordinator`。
    @discardableResult
    func consumePendingQuickSave() -> Bool {
        QuickSaveCoordinator.consume(with: capture)
    }

    // MARK: - 采集结果 → 提示

    private func handle(_ outcome: PasteboardCapture.Outcome) {
        switch outcome {
        case .saved(let item):
            highlightedItemID = item.persistentModelID
            pasteBannerVisible = false
            toast.show(String(localized: "Saved"))
            feedback(.success)
        case .duplicate(let item):
            highlightedItemID = item.persistentModelID
            pasteBannerVisible = false
        case .needsBanner:
            pasteBannerVisible = true
            pasteBannerSaved = false
        case .failed:
            toast.show(String(localized: "Couldn't save"), symbol: "exclamationmark.triangle.fill")
        case .unchanged, .empty:
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
                withAnimation(PasterTheme.springAnimation) {
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
        withAnimation(PasterTheme.springAnimation) { pasteBannerVisible = false }
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
        toast.show(String(localized: "Unpinned"), symbol: "pin.slash")
    }

    func delete(_ item: ClipItem) {
        ImageMetadataCache.shared.invalidate(item)
        modelContext.delete(item)
        save()
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
        // 关系是 nullify：删板不删条目，条目回到历史
        modelContext.delete(board)
        save()
    }

    // MARK: - 设置

    func completeOnboarding() {
        IOSSettings.onboardingCompleted = true
        withAnimation(PasterTheme.springAnimation) { showsOnboarding = false }
    }

    /// 用户在设置里调小历史上限后立刻生效，不必等下一次采集
    func applyHistoryLimit(_ limit: Int) {
        IOSSettings.historyLimit = limit
        try? ClipSaver.enforceHistoryLimit(limit, in: modelContext)
    }

    // MARK: - 内部

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
