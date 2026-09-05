import PasterCore
import SwiftData
import SwiftUI

// MARK: - 侧栏选中项 ↔ 标签

extension SidebarSelection {

    /// 这一项在紧凑宽度下对应哪个标签。
    /// 分栏与标签栏来回切换时靠它把选中状态带过去，用户不会因为转屏就回到历史页。
    var tab: PasterTab {
        switch self {
        case .history: .history
        case .pinboard: .pinboard
        case .settings: .settings
        }
    }

    /// 这一项对应的类型筛选（只有历史分类有）
    var kindFilter: ClipKind? {
        if case .history(let kind) = self { return kind }
        return nil
    }
}

// MARK: - `-demoSidebar` 的取值

/// 截图用：直接选中侧栏的某一项。`pinboard` 落到第一个板。
enum DemoSidebarItem: String, CaseIterable {
    case history
    case text
    case link
    case image
    case color
    case file
    case pinboard
    case settings

    /// 分类项对应的 ClipKind；`history` / `pinboard` / `settings` 为 nil
    var kind: ClipKind? {
        switch self {
        case .text: .text
        case .link: .link
        case .image: .image
        case .color: .color
        case .file: .file
        case .history, .pinboard, .settings: nil
        }
    }
}

// MARK: - 侧栏与标签栏的状态同步

extension AppModel {

    /// 第一个 Pinboard；一个板都没有时返回 nil
    var firstPinboardSelection: SidebarSelection? {
        guard let board = pinboards().first else { return nil }
        return .pinboard(board.persistentModelID)
    }

    /// 选中侧栏的一项，同时把类型筛选同步给历史页——
    /// 这样切回紧凑宽度时，chips 上还是同一个筛选。
    func selectSidebar(_ selection: SidebarSelection) {
        sidebarSelection = selection
        kindFilter = selection.kindFilter
        selectedTab = selection.tab
    }

    /// 分栏出现时对齐两套导航状态：
    /// 用户可能刚在紧凑宽度下切过标签（转屏、退出 Slide Over），侧栏要落到同一处。
    func syncSidebarSelectionWithTab() {
        guard sidebarSelection?.tab != selectedTab else { return }
        switch selectedTab {
        case .history:
            sidebarSelection = .history(kindFilter)
        case .pinboard:
            sidebarSelection = firstPinboardSelection ?? .history(kindFilter)
        case .settings:
            sidebarSelection = .settings
        }
    }

    /// `-demoSidebar` 指定的侧栏项。没给这个参数就什么都不做。
    /// 返回值告诉调用方要不要跳过上面的标签同步。
    @discardableResult
    func applyDemoSidebarSelection() -> Bool {
        guard let item = launch.demoSidebar else { return false }
        switch item {
        case .pinboard:
            selectSidebar(firstPinboardSelection ?? .history(nil))
        case .settings:
            selectSidebar(.settings)
        default:
            selectSidebar(.history(item.kind))
        }
        return true
    }
}

// MARK: - 排序

/// detail 列导航栏右侧排序按钮的取值。存在 App Group 的 UserDefaults 里，
/// 历史与 Pinboard 网格接上后直接读同一个键即可，不必再多一份状态。
enum ClipSortOrder: String, CaseIterable {
    case time
    case kind
    case source

    /// 与 `IOSSettings.Key` 同一个 suite；等集成时可以把它挪进 `IOSSettings.Key`
    static let storageKey = "clipSortOrder"

    var title: String {
        switch self {
        case .time: String(localized: "By Time")
        case .kind: String(localized: "By Type")
        case .source: String(localized: "By Source")
        }
    }

    var symbol: String {
        switch self {
        case .time: "clock"
        case .kind: "square.grid.2x2"
        case .source: "app.badge"
        }
    }

    /// 排序结果。同一维度内永远以时间倒序收尾，避免同类条目的相对位置每次刷新都变。
    func sorted(_ items: [ClipItem]) -> [ClipItem] {
        switch self {
        case .time:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .kind:
            return items.sorted {
                $0.kindRaw == $1.kindRaw ? $0.createdAt > $1.createdAt : $0.kindRaw < $1.kindRaw
            }
        case .source:
            return items.sorted {
                let lhs = $0.sourceDisplayName
                let rhs = $1.sourceDisplayName
                return lhs == rhs ? $0.createdAt > $1.createdAt : lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
        }
    }
}

// MARK: - 顶部状态的归属

private struct HidesSyncStatusPillKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// iPad 分栏时，同步胶囊由 detail 列容器（`SplitDetailColumn`）统一放在导航栏右侧。
    /// 各界面自己那份 `SyncStatusPill` 读到 true 就不画，免得右上角出现两个胶囊。
    /// 只有分栏的 detail 列会把它设成 true，iPhone 的标签栏布局不受影响。
    var pasterHidesSyncStatusPill: Bool {
        get { self[HidesSyncStatusPillKey.self] }
        set { self[HidesSyncStatusPillKey.self] = newValue }
    }
}
