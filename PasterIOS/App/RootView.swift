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
        }
        .background(PasterTheme.bgGrouped)
    }

    // MARK: - iPhone

    private var tabLayout: some View {
        @Bindable var model = model
        return TabView(selection: $model.selectedTab) {
            Tab(PasterTab.history.title, systemImage: PasterTab.history.symbol, value: PasterTab.history) {
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
        return NavigationSplitView {
            SidebarView(selection: $model.sidebarSelection)
        } detail: {
            NavigationStack {
                detailContent(for: model.sidebarSelection ?? .history(nil))
            }
        }
    }

    @ViewBuilder
    private func detailContent(for selection: SidebarSelection) -> some View {
        switch selection {
        case .history(let kind):
            HistoryScreen(kindFilter: kind)
        case .pinboard(let id):
            // 侧栏存的是 PersistentIdentifier，这里换回对象；对象被删掉时回落到 Pinboard 列表
            if let board = model.modelContext.model(for: id) as? Pinboard {
                PinboardContentScreen(board: board)
            } else {
                PinboardListScreen()
            }
        case .settings:
            SettingsScreen()
        }
    }
}
