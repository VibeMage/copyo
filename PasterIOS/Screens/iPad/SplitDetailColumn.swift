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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusPill(status: model.syncStatus.status, compact: true) {
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

    /// 设置页没有可排序的内容
    private var showsSort: Bool {
        if case .settings = selection { return false }
        return true
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
