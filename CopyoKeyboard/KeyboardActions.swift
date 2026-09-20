import Foundation

/// SwiftUI 键盘界面**唯一**能碰到宿主输入框的通道。
///
/// 存在的理由是隔离：`textDocumentProxy` 挂在 `UIInputViewController` 上，
/// 一旦让 `KeyRow` / `LetterPlane` 直接持有那个 controller，它们顺手就能调到
/// `dismissKeyboard()`、`advanceToNextInputMode()` 这些会改变整个进程状态的方法，
/// 而且 SwiftUI 预览再也起不来——预览里没有宿主，没有 controller。
/// 这里把能做的事收窄成四个闭包：视图层只知道「插入一个字符」，不知道插到哪儿去。
///
/// **地球键不在其中。** 它长按要弹出系统的键盘列表，那条 API 要一个真实的 `UIEvent`，
/// 闭包传不了事件对象，所以那一颗键单独走 `GlobeKey` 直接接到 controller 上，
/// 完整理由写在 `GlobeKey` 的文档注释里。
struct KeyboardActions {

    /// 插入一个字符。字母、数字、标点都走这里
    var insert: (String) -> Void

    /// 退格一次。长按连发由 `KeyCap` 自己按固定节奏重复调用它，这里只管删一个
    var deleteBackward: () -> Void

    /// 空格。刻意与 `insert(" ")` 分开：设计 07 把它画成一颗独立的功能键，
    /// 「连按两下空格补句号」这类**只属于空格键**的行为将来落在这里，
    /// 混进字符插入的话每个字母键都要跟着判断一遍
    var space: () -> Void

    /// 换行（设计 07 的 `换行` 键）
    var newline: () -> Void
}
