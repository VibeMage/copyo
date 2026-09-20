import Foundation

/// 键盘正文区当前显示哪一面。
///
/// 三档，由底排那一颗面板切换键**轮转**：`剪贴条 → 字母 → 数字 → 剪贴条`。
///
/// 上一阶段把这颗键留成了两档并记下「三种状态时一颗键表达不了两件事，需要一个决定」。
/// 决定是轮转，理由是这块键盘上**只有这一个可用的键位**：设计 07 底排五颗（地球 / 面板 /
/// 空格 / 删除 / 换行）已经排满，字母面第三排右边那 46pt 空位是留给 `zxcvbnm` 对齐的
/// （见 `LetterPlane.bottomRow`），占掉它会让所有人打字时手指落偏，而且那正是系统键盘放
/// 删除键的位置，摆一颗别的键进去等于诱导误触。
///
/// 轮转本身不难用的原因是**键面写的是去处**，不是现在在哪儿——这是系统键盘自己的规矩，
/// 上一阶段已经按它把设计稿那颗没有定义行为的 `↑` 改成了 `123` / `ABC`。
/// 代价是「从字母回剪贴条」要按两下（经过数字面）。搜索进行中不必受这个代价：
/// 那时换行键是「搜索」，一下就回到筛选后的卡片条，见 `KeyRow.submitsSearch`。
enum KeyboardPlane {
    /// 设计 07 的正常态：搜索行 + 横向剪贴卡片条。键盘的默认面
    case clips
    /// 紧凑 QWERTY
    case letters
    /// 数字与标点
    case symbols

    /// 轮到下一面
    mutating func advance() {
        self = next
    }

    /// 按下面板切换键会落到哪一面。键面与旁白标签都由它派生，
    /// 三者不可能各说各话——这正是「键面写去处」这条规矩要的东西
    var next: KeyboardPlane {
        switch self {
        case .clips: .letters
        case .letters: .symbols
        case .symbols: .clips
        }
    }

    /// 面板切换键的键面。
    ///
    /// `ABC` 与 `123` 刻意**不本地化**：iOS 各语言下这两颗键一律是这四个拉丁字符，
    /// 翻过去反而认不出来。回剪贴条那一档没有对应的拉丁缩写，用符号——
    /// 取 design-spec 第五节「横幅」那一格的 `doc.on.clipboard`，
    /// 它在这套设计里就是「剪贴板内容」的图形。
    enum SwitchKeyLabel: Equatable {
        case text(String)
        case symbol(String)
    }

    var switchKeyLabel: SwitchKeyLabel {
        switch next {
        case .clips: .symbol("doc.on.clipboard")
        case .letters: .text("ABC")
        case .symbols: .text("123")
        }
    }

    /// 旁白读的是去处，与键面同一个口径
    var switchKeyAccessibilityLabel: String {
        switch next {
        case .clips: String(localized: "History")
        case .letters: String(localized: "Letters")
        case .symbols: String(localized: "Numbers and punctuation")
        }
    }

    /// 这一面要不要画能打字的三排键
    var showsTypingKeys: Bool {
        self != .clips
    }

    /// 打字面里的哪一档（`LetterPlane` 只认这一个布尔，它不该知道还有剪贴条这回事）
    var showsSymbols: Bool {
        self == .symbols
    }
}
