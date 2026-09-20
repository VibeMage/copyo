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
/// 放成 `@Observable` 之后，读 `query` 的只有搜索行自己（连命中条数也在它那儿算），
/// 根视图的 `body` 一个字都不读，于是打字时只有那 36pt 的一行在重画。
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
