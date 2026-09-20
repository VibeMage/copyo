import Foundation
import Observation

/// 搜索行的查询状态。
///
/// **它单独是一个引用类型，不是根视图里的两个 `@State`，理由只有一个：把「每敲一个字符
/// 要重画什么」限制到最小。** 查询放在根视图上的话，每按一颗字母键都会让根视图的 `body`
/// 重跑；而根视图每跑一次就给三排键里的每一颗 `KeyCap` 发一组**新的** action 闭包，
/// 闭包不可比较，SwiftUI 只能把三十来颗键全部重新求值——正是
/// `KeyboardViewController.refresh()` 那道 `Inputs` 闸门在挡的同一件事，
/// 只不过那边挡的是宿主变化，这边是自己打字。
///
/// 放成 `@Observable` 之后，打字时重画的只有那 36pt 的搜索行。
///
/// **但根视图的 `body` 并非完全不读 `query`**：`.clips` 那一面要拿 `query` 去筛卡片条
/// （`KeyboardRootView.clipsArea`），所以那一面挂着的时候，根视图确实订阅了这个值。
/// 之所以不出问题，是因为 `isEditingQuery` 要求 `plane.showsTypingKeys`——
/// 卡片条上没有字符键，`query` 在那一面**不可能被改**，订阅了也永远不会被触发。
/// 也就是说这条性能保证是由「卡片条上改不了查询」撑着的，不是由「根视图不读」撑着的。
/// 哪天让查询在卡片条上也能变（比如做一个不收起卡片条的搜索、或进场时恢复上次的查询），
/// 每敲一颗键就会把整棵树连同三十来颗 `KeyCap` 一起重新求值——那时候就得把筛选结果
/// 挪出根视图的 `body`（例如让 `ClipStrip` 自己读 `query`）。
@MainActor
@Observable
final class KeyboardSearch {

    /// 当前查询。空串 = 没有筛选
    var query = ""

    /// 键位敲出来的字正在进 `query` 而不是进宿主输入框。
    /// **和 `query` 非空不是一回事**：搜索刚激活时查询还是空的，键位却已经改了去向，
    /// 这一点必须让用户看得见（搜索行会描一圈 accent），否则他会以为字打进了消息里
    var isActive = false

    /// 清空并退出搜索
    func clear() {
        query = ""
        isActive = false
    }
}
