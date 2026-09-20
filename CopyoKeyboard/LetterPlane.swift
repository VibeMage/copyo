import SwiftUI

/// 键盘正文区当前显示哪一面。
///
/// 设计 07 画的是第三种状态——横向剪贴卡片条；它要读 App Group 里的库，属于下一阶段。
/// 本阶段只有能打字的这两面，`KeyRow` 的面板切换键在它们之间来回。
enum KeyboardPlane {
    /// 紧凑 QWERTY
    case letters
    /// 数字与标点
    case symbols

    /// 切到另一面。第三种状态进来时这里要改成显式的状态机，别在这上面继续加 `toggle`
    mutating func toggle() {
        self = self == .letters ? .symbols : .letters
    }

    /// 面板切换键的键面。系统键盘的规矩是**键面写的是去处**，不是现在在哪儿，
    /// 所以字母面上写 `123`、数字面上写 `ABC`——设计 07 画的 `ABC` 正是卡片条那一面该有的样子。
    /// 两个标签都不本地化：iOS 各语言下这两颗键一律是这四个拉丁字符，翻过去反而认不出来
    var switchKeyTitle: String {
        switch self {
        case .letters: "123"
        case .symbols: "ABC"
        }
    }

    var switchKeyAccessibilityLabel: String {
        switch self {
        case .letters: String(localized: "Numbers and punctuation")
        case .symbols: String(localized: "Letters")
        }
    }
}

/// 能真正打字的那三排键——**这是 4.4.1 的合规面，不是锦上添花。**
///
/// 审核指南 4.4.1 要求键盘扩展「提供键盘输入功能（例如输入字符）」，并且「在没有完全网络访问、
/// 也没有开启完全访问的情况下仍然可用」。设计 07 的底排只有空格与换行，一个字母、一个数字都打不出来；
/// 未授权态连卡片条都没有，整块键盘什么都输入不了。照着画出来就是一次必然的 4.4.1 拒绝。
/// 这三排键不碰 App Group、不碰网络，
/// 于是第二条也一并满足——没开「允许完全访问」时，这块键盘退化成一块普通的拉丁键盘，仍然能用。
///
/// **范围：只有拉丁 / ASCII。** 在这里塞一个中文输入法不在讨论范围内。
/// 由此留下一个真实的缺口：将来键盘自己的搜索框只能输入拉丁字符，而它要搜的内容大量是中文——
/// 这需要一个产品决定（例如搜索时改走宿主键盘、或只按来源与类型筛选），不是能在代码里糊过去的事。
struct LetterPlane: View {
    let plane: KeyboardPlane
    let actions: KeyboardActions
    /// 外观。理由见 `CopyoTheme.keyCap(for:)`
    let scheme: ColorScheme

    /// 键间距（设计 01f 里系统键盘的 `gap:6`）
    var spacing: CGFloat = 6
    /// 排间距（设计 01f `gap:11`）
    var rowSpacing: CGFloat = 11
    /// 键高（设计 07 / 01f 全部 42）
    var keyHeight: CGFloat = 42
    /// 字母键的**上限**宽度（设计 01f 的键帽 36 × 42）
    var maxKeyWidth: CGFloat = 36
    /// 功能键宽（设计 01f / 07 的 46 × 42）
    var functionWidth: CGFloat = 46

    /// 一排最多几颗字母键。宽度按它等分，第二三排再按同一个宽度居中，
    /// 这样三排的键帽是同一个宽度、指位与系统键盘对得上
    private let keysPerRow = 10

    @State private var isShifted = false

    var body: some View {
        GeometryReader { proxy in
            // 设计给的 36 是 6.9 英寸机身（内屏 440）上的值：440 - 8 × 2 = 424，
            // 10 × 36 + 9 × 6 = 414，正好放得下。**但窄机身放不下**——
            // iPhone SE 只有 375，减去左右 8 只剩 359，写死 36 会让最后一列直接出屏幕。
            // 所以 36 只当上限，实际按可用宽度等分；反过来在 iPad 上也不让键帽摊成一条
            let available = proxy.size.width - spacing * CGFloat(keysPerRow - 1)
            let keyWidth = min(maxKeyWidth, available / CGFloat(keysPerRow))

            VStack(spacing: rowSpacing) {
                row(rows.top, keyWidth: keyWidth)
                row(rows.middle, keyWidth: keyWidth)
                bottomRow(keyWidth: keyWidth)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: keyHeight * 3 + rowSpacing * 2)
    }

    // MARK: - 排

    private func row(_ keys: [String], keyWidth: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(keys, id: \.self) { key in
                characterKey(key, keyWidth: keyWidth)
            }
        }
    }

    /// 第三排：左边一颗功能键、中间字符、右边一个同宽的空位。
    ///
    /// 右边留空而不是再放一颗删除键：设计 07 已经把删除放在底排功能排了，
    /// 同一块键盘上出现两颗删除键，人会先花一秒钟猜它们是不是不一样的东西。
    /// 空位仍然占满 46，是为了让 `zxcvbnm` 的落点与系统键盘第三排一致——
    /// 去掉它这一排会整体右移半颗键，打字的人立刻会打错。
    private func bottomRow(keyWidth: CGFloat) -> some View {
        HStack(spacing: spacing) {
            switch plane {
            case .letters:
                KeyCap(width: functionWidth,
                       height: keyHeight,
                       fill: .function,
                       scheme: scheme,
                       action: { isShifted.toggle() }) {
                    Image(systemName: isShifted ? "shift.fill" : "shift")
                        .font(.title3)
                }
                .accessibilityLabel(String(localized: "Shift"))
            case .symbols:
                // 数字面没有上档可言，但左右两个空位要留着，`.,?!'` 那一排才落在中间
                Color.clear.frame(width: functionWidth, height: keyHeight)
            }

            ForEach(rows.bottom, id: \.self) { key in
                characterKey(key, keyWidth: keyWidth)
            }

            Color.clear.frame(width: functionWidth, height: keyHeight)
        }
    }

    private func characterKey(_ key: String, keyWidth: CGFloat) -> some View {
        KeyCap(width: keyWidth,
               height: keyHeight,
               fill: .cap,
               scheme: scheme,
               action: { insert(key) }) {
            Text(displayed(key))
                // 设计 01f 的键帽字号 22 → 动态字体契约里的 `.title2`，默认档位下逐像素一致。
                // 这里要的是常规字重，不走 `CopyoTheme.Fonts.title2`（那一档是加粗的标题字）
                .font(.title2)
        }
    }

    // MARK: - 字符

    private func displayed(_ key: String) -> String {
        isShifted ? key.uppercased() : key
    }

    private func insert(_ key: String) {
        actions.insert(displayed(key))
        // 一次性上档：打完一个大写字母就自动落回小写，与系统键盘一致。
        // 连续大写（双击上档锁定）没有做，需要时在这里加，别改成「按一次一直锁着」——
        // 那会让所有人打出 `HELLO` 才发现
        if isShifted { isShifted = false }
    }

    /// 三排的字符表。
    ///
    /// 数字面没有做系统那种 `#+=` 第三面，而是把它常用的几个符号并进第三排——
    /// 多一面就要多一颗切换键，而底排五颗键的位置已经被设计 07 占满了。
    private var rows: (top: [String], middle: [String], bottom: [String]) {
        switch plane {
        case .letters:
            (top: characters("qwertyuiop"),
             middle: characters("asdfghjkl"),
             bottom: characters("zxcvbnm"))
        case .symbols:
            (top: characters("1234567890"),
             middle: ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
             bottom: [".", ",", "?", "!", "'", "\"", "#", "%", "+"])
        }
    }

    private func characters(_ string: String) -> [String] {
        string.map(String.init)
    }
}
