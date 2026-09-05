import PasterCore
import SwiftData
import SwiftUI

/// 应用根视图：决定 iPhone 的浮动标签栏还是 iPad 的侧栏 + 内容，
/// 并在最上层叠轻提示。引导流程盖住全部内容。
///
/// 布局判定同时看 size class 与实际宽度：iPad 上 Slide Over 与 1/3 分屏的 size class 是 compact，
/// 但 1/2 分屏是 regular 而宽度只有 507pt，双栏会挤成两条缝——所以宽度也要判一次。
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// 侧栏可见性；侧栏标题右侧的 sidebar.left 按钮要能收起分栏
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var model = model
        GeometryReader { proxy in
            let compact = horizontalSizeClass == .compact
                || proxy.size.width < PasterTheme.Metrics.compactWidthThreshold
            Group {
                if compact {
                    tabLayout
                } else {
                    splitLayout
                }
            }
            .overlay(alignment: .top) {
                ToastOverlay(toast: model.toast.current)
            }
            .fullScreenCover(isPresented: $model.showsOnboarding) {
                OnboardingFlow(startPage: model.demoRoute?.onboardingPage ?? 0) {
                    model.completeOnboarding()
                }
            }
            // 只在 `-demoScreen share` 下出现：主应用里挂分享扩展那份 ShareView，用来核对设计 06
            .shareDemoOverlay()
            // 「新建 Pinboard」Alert 全应用只此一处：触发点有 Pinboard 列表的 +、空态按钮、
            // iPad 侧栏的分组头 +、卡片长按菜单里的「新建 Pinboard…」。
            // 挂在根视图而不是各界面，两套布局才不会出现两个宿主绑同一个标志。
            .newPinboardAlert(isPresented: $model.presentsNewPinboard) { name in
                createPinboard(named: name)
            }
        }
        .background(PasterTheme.bgGrouped)
    }

    // MARK: - 新建 Pinboard

    /// 建板后顺手选中它：iPad 上用户点侧栏的 + 建完就想看到新板，
    /// iPhone 上写 sidebarSelection 没有可见影响，等转屏成分栏时也落在同一处。
    private func createPinboard(named name: String) {
        let board = model.createPinboard(
            named: name,
            iconName: PinboardAppearance.defaultSymbol,
            colorHex: PinboardAppearance.nextColorHex(existingCount: model.pinboards().count)
        )
        model.selectSidebar(.pinboard(board.persistentModelID))
        model.toast.show(String(localized: "Pinboard created"), symbol: "pin.fill")
    }

    // MARK: - iPhone

    private var tabLayout: some View {
        @Bindable var model = model
        return TabView(selection: $model.selectedTab) {
            Tab(PasterTab.history.title, systemImage: PasterTab.history.symbol, value: PasterTab.history) {
                // `-demoScreen detail-*` 的详情推入在 HistoryScreen 自己的 navigationDestination 里
                NavigationStack { HistoryScreen() }
            }
            Tab(PasterTab.pinboard.title, systemImage: PasterTab.pinboard.symbol, value: PasterTab.pinboard) {
                NavigationStack { PinboardListScreen() }
            }
            Tab(PasterTab.settings.title, systemImage: PasterTab.settings.symbol, value: PasterTab.settings) {
                NavigationStack { SettingsScreen() }
            }
        }
    }

    // MARK: - iPad

    private var splitLayout: some View {
        @Bindable var model = model
        return NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $model.sidebarSelection, columnVisibility: $columnVisibility)
        } detail: {
            NavigationStack {
                // 内容分发与 iPad 顶部状态（同步胶囊 + 排序）都在 SplitDetailColumn 里
                SplitDetailColumn(selection: model.sidebarSelection ?? .history(nil))
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
