import SwiftUI

/// 能真正打字的那三排键——**这是 4.4.1 的合规面，不是锦上添花。**
///
/// 审核指南 4.4.1 要求键盘扩展「提供键盘输入功能（例如输入字符）」，并且「在没有完全网络访问、
/// 也没有开启完全访问的情况下仍然可用」。设计 07 的底排只有空格与换行，一个字母、一个数字都打不出来；
/// 未授权态连卡片条都没有，整块键盘什么都输入不了。照着画出来就是一次必然的 4.4.1 拒绝。
/// 这三排键不碰 App Group、不碰网络，
/// 于是第二条也一并满足——没开「允许完全访问」时，这块键盘退化成一块普通的拉丁键盘，仍然能用。
///
/// **范围：只有拉丁 / ASCII。** 在这里塞一个中文输入法不在讨论范围内。
/// 由此留下的缺口现在已经是实打实的了：搜索行的查询就是由这三排键敲出来的
/// （见 `KeyboardRootView.typingActions`），而库里的内容大量是中文——
/// 中文条目只能靠它里面夹带的拉丁字符与数字被搜到（验证码、命令行、域名恰好都是），
/// 纯中文的那几条在这块键盘上**搜不出来**。这需要一个产品决定
/// （例如搜索时改走宿主键盘、或只按来源与类型筛选），不是能在代码里糊过去的事。
///
/// 字符落到哪儿由调用方决定：根视图在搜索进行中会换一套写进查询的 `KeyboardActions`，
/// 本视图对此一无所知——它只知道「插入一个字符」。
struct LetterPlane: View {
    /// true = 数字与标点面，false = 字母面。
    ///
    /// 刻意**不收 `KeyboardPlane`**：那个枚举有第三档（剪贴卡片条），而本视图在那一档
    /// 根本不会被渲染。收枚举就得在两处 `switch` 里各写一个永远走不到的分支，
    /// 而写不出真话的分支正是注释开始说谎的地方。
    let showsSymbols: Bool
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
                bottomRow(keyWidth: keyWidth, width: proxy.size.width)
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
    private func bottomRow(keyWidth: CGFloat, width: CGFloat) -> some View {
        // 底排的键数与上面两排不同（字母面 7、数字面 5），而传进来的 `keyWidth` 是按上面那排的
        // 10 颗算出来的，两端还各有一颗 46 的功能位。直接套用就会溢出：440 机身上 9 颗字符键
        // 需要 46×2 + 9×36 + 10×6 = 476，而可用宽只有 424。
        // 溢出不是「挤一点」——`VStack` 没有 `clipped()`，这一排会居中后从两边各探出去二三十点，
        // 而 UIKit 的命中测试**不越过父视图边界**，最外侧那两颗于是画得出来、点不到。
        // 所以按本排实际占用重算一次上限：放不下就整排一起缩，宁可窄也不要有点不到的键。
        let capped = bottomKeyWidth(keyWidth, count: rows.bottom.count, width: width)
        return HStack(spacing: spacing) {
            if showsSymbols {
                // 数字面没有上档可言，但左右两个空位要留着，`.,?!'` 那一排才落在中间
                Color.clear.frame(width: functionWidth, height: keyHeight)
            } else {
                KeyCap(width: functionWidth,
                       height: keyHeight,
                       fill: .function,
                       scheme: scheme,
                       action: { isShifted.toggle() }) {
                    Image(systemName: isShifted ? "shift.fill" : "shift")
                        .font(.title3)
                }
                .accessibilityLabel(String(localized: "Shift"))
            }

            ForEach(rows.bottom, id: \.self) { key in
                characterKey(key, keyWidth: capped)
            }

            Color.clear.frame(width: functionWidth, height: keyHeight)
        }
    }

    /// 底排放得下的键宽上限。两端的功能位与每个间隙都是固定开销，先扣掉再按键数等分。
    private func bottomKeyWidth(_ keyWidth: CGFloat, count: Int, width: CGFloat) -> CGFloat {
        guard count > 0 else { return keyWidth }
        let fixed = functionWidth * 2 + spacing * CGFloat(count + 1)
        return min(keyWidth, max(0, (width - fixed) / CGFloat(count)))
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
        if showsSymbols {
            return (top: characters("1234567890"),
                    middle: ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
                    bottom: [".", ",", "?", "!", "'"])
        }
        return (top: characters("qwertyuiop"),
                middle: characters("asdfghjkl"),
                bottom: characters("zxcvbnm"))
    }

    private func characters(_ string: String) -> [String] {
        string.map(String.init)
    }
}
