import Foundation
import PasterCore
import SwiftUI

/// 两个排序偏好的存储键。写在 App Group 的 suite 里（`IOSSettings.defaults`），
/// 与其它设置同一处，不落 standard。
enum PinboardPreferences {
    static let listSort = "pinboardListSort"
    static let contentSort = "pinboardContentSort"
}

/// Pinboard 列表的排序（设计 03 右上 `arrow.up.arrow.down`）。
enum PinboardListSort: String, CaseIterable, Identifiable {
    case created
    case name
    case count

    var id: String { rawValue }

    var title: String {
        switch self {
        case .created: String(localized: "By Date Created")
        case .name: String(localized: "By Name")
        case .count: String(localized: "By Item Count")
        }
    }

    /// `@Query` 已经按 sortIndex 取回来了，这里只重排显示顺序，不写库。
    /// 每种排序都以 sortIndex 收尾，值相同时（比如样例数据里四个板同一毫秒建出来）顺序才是稳定的。
    func sort(_ boards: [Pinboard]) -> [Pinboard] {
        switch self {
        case .created:
            boards.sorted {
                $0.createdAt == $1.createdAt ? $0.sortIndex < $1.sortIndex : $0.createdAt < $1.createdAt
            }
        case .name:
            boards.sorted {
                let order = $0.name.localizedStandardCompare($1.name)
                return order == .orderedSame ? $0.sortIndex < $1.sortIndex : order == .orderedAscending
            }
        case .count:
            boards.sorted {
                let left = $0.items?.count ?? 0
                let right = $1.items?.count ?? 0
                return left == right ? $0.sortIndex < $1.sortIndex : left > right
            }
        }
    }
}

/// Pinboard 内容页的排序（设计 03b 标题菜单「排序方式」，副行显示当前值）。
enum PinboardContentSort: String, CaseIterable, Identifiable {
    case pinnedTime
    case kind
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pinnedTime: String(localized: "By Pin Time")
        case .kind: String(localized: "By Type")
        case .name: String(localized: "By Name")
        }
    }

    func sort(_ items: [ClipItem]) -> [ClipItem] {
        switch self {
        case .pinnedTime:
            // 模型里没有「固定时间」字段，用 createdAt 近似（见交接说明的 issues）
            items.sorted { $0.createdAt > $1.createdAt }
        case .kind:
            items.sorted {
                $0.kindRaw == $1.kindRaw ? $0.createdAt > $1.createdAt : $0.kindRaw < $1.kindRaw
            }
        case .name:
            items.sorted {
                let order = $0.displayTitleLocalized.localizedStandardCompare($1.displayTitleLocalized)
                return order == .orderedSame ? $0.createdAt > $1.createdAt : order == .orderedAscending
            }
        }
    }
}
