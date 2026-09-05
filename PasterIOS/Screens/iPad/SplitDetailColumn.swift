import PasterCore
import SwiftData
import SwiftUI

/// 分栏右侧的内容列（设计 09 的内容区）。
///
/// 只做两件事：按侧栏选中项分发界面，以及在导航栏右侧放同步胶囊与排序按钮——
/// 后两者是 iPad 独有的顶部状态，放在这里各界面就不必分别为 iPad 再写一遍工具栏。
struct SplitDetailColumn: View {
    let selection: SidebarSelection

    @Environment(AppModel.self) private var model
    @AppStorage(ClipSortOrder.storageKey, store: IOSSettings.defaults)
    private var sortRaw = ClipSortOrder.time.rawValue

    var body: some View {
        // 环境值设在 content 上、工具栏加在外面：界面自己的胶囊被压掉，这里这一个照常显示
        content
            .environment(\.pasterHidesSyncStatusPill, true)
            // 界面据此判断自己在 regular 布局里，不再靠「自己宽 ≥ 600」猜
            // （iPad Pro 11 竖屏的 detail 列只有约 545pt，那条判据在那台机器上恒为假）
            .environment(\.pasterIsSplitDetail, true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusPill(status: model.syncStatus.status, size: .pad) {
                        model.selectSidebar(.settings)
                    }
                    .environment(\.pasterHidesSyncStatusPill, false)
                }
                if showsSort {
                    ToolbarItem(placement: .topBarTrailing) { sortMenu }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .history(let kind):
            HistoryScreen(kindFilter: kind)
        case .pinboard(let id):
            // 侧栏存的是 PersistentIdentifier，这里换回对象。
            // **不能**用 `modelContext.model(for:)`：它返回的是非可选的 any PersistentModel，
            // 已删除的对象拿到的是失效实例而不是 nil，`as? Pinboard` 一定成功，
            // 于是 detail 列会继续渲染一个已删除的板并在读 name / items 时崩溃。
            // 从现有集合里查，取不到才是真的没有。
            if let board = model.pinboards().first(where: { $0.persistentModelID == id }) {
                PinboardContentScreen(board: board)
            } else {
                PinboardListScreen()
            }
        case .settings:
            SettingsScreen()
        }
    }

    /// 只有历史用这颗排序按钮。设置页没有可排序的内容；
    /// Pinboard 内容页在自己的标题菜单里已经有一套「排序方式」（设计 03b），
    /// 再放一颗会出现两个互不相干的排序入口。
    private var showsSort: Bool {
        if case .history = selection { return true }
        return false
    }

    private var sortMenu: some View {
        Menu {
            Picker(String(localized: "Sort"), selection: $sortRaw) {
                ForEach(ClipSortOrder.allCases, id: \.self) { order in
                    Label(order.title, systemImage: order.symbol).tag(order.rawValue)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel(String(localized: "Sort"))
    }
}
