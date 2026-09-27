import SwiftUI

/// 设计 3.6：右上角的 iCloud 状态胶囊。未同步态可点，跳到设置。
struct SyncStatusPill: View {

    /// 设计 3.6 给了三档尺寸：iPhone 40 / iPad 36 / Slide Over 34。
    /// 原来只有一个 `compact: Bool`，iPhone 与 iPad 都传 true，两处用的都是最小的 Slide Over 档。
    ///
    /// 下面这些点数都是**默认字号档**下的设计值，实际用的时候要乘 `typeScale`。
    enum Size {
        case phone
        case pad
        case slideOver

        var height: CGFloat {
            switch self {
            case .phone: CopyoTheme.Metrics.syncPillHeight
            case .pad: 36
            case .slideOver: 34
            }
        }

        var symbolSize: CGFloat {
            switch self {
            case .phone: 18
            case .pad: 17
            case .slideOver: 16
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .phone, .pad: 13
            case .slideOver: 12
            }
        }

        var leading: CGFloat { self == .phone ? 10 : 8 }
        var trailing: CGFloat { self == .phone ? 12 : 10 }
    }

    let status: SyncStatus
    var size: Size = .phone
    var onTapWhenOff: (() -> Void)?

    /// iPad 分栏时同步胶囊由 detail 列容器统一提供，界面自己那份要让位（见 `copyoHidesSyncStatusPill`）
    @Environment(\.copyoHidesSyncStatusPill) private var hidden

    var body: some View {
        if !hidden {
            // 两处调用都把它塞进 `ToolbarItem`（历史页的 topBarTrailing 与 `SplitDetailColumn`），
            // 而导航栏本身只有约 44pt 高。不封顶的话 footnote 在 AX5 是 13→44pt、倍率约 3.4，
            // 高度 / 图标 / 字号同时乘上去，胶囊会变成一百多点高、两百多点宽——要么把整条导航栏
            // 撑得不成样子，要么直接被裁掉半截，两种结果都比字小更难用。
            //
            // 这是一次**有意的无障碍让步**，代价是可控的：同步状态在设置页「同步 → 状态」那一行
            // 有完整文本（还额外给了上次同步时间，以及没开成时的具体原因），那一行**不封顶**、
            // 照常放大到 AX5；而这枚胶囊未同步时点一下就是跳到那里。真正靠放大阅读的用户
            // 不会因为这里封顶而丢掉任何信息。
            //
            // 封顶必须挂在**子视图**上：`@ScaledMetric` 读的是它自己所在视图收到的环境，
            // 写在本视图 body 里只影响更下一层，胶囊自己那份倍率照样不封顶。
            SyncStatusPillBody(status: status, size: size, onTapWhenOff: onTapWhenOff)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }
}

// MARK: - 胶囊本体

/// 拆出来只为一件事：让上面那道 `dynamicTypeSize` 封顶也能管住 `typeScale`（见调用处注释）。
private struct SyncStatusPillBody: View {

    let status: SyncStatus
    let size: SyncStatusPill.Size
    var onTapWhenOff: (() -> Void)?

    /// `Size` 是 `enum`，装不下 `@ScaledMetric`——属性包装器要的是视图的存储。
    /// 所以缩放放在视图这一层：取一个相对 footnote（13pt，正是这枚胶囊的字号）的倍率，
    /// 再乘到三档设计点数上。高度、图标、文字乘的是**同一个**倍率，才会一起长大；
    /// 各自挑各自的样式会出现「字长了、胶囊没长」这种半截效果。
    @ScaledMetric(relativeTo: .footnote) private var typeScale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var symbol: String {
        switch status {
        case .idle: "icloud"
        case .synced: "checkmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .off: "icloud.slash"
        }
    }

    private var title: String { Self.title(for: status) }

    private static func title(for status: SyncStatus) -> String {
        switch status {
        case .idle: "iCloud"
        case .synced: String(localized: "Synced")
        case .syncing: String(localized: "Syncing…")
        case .off: String(localized: "Not synced")
        }
    }

    /// 四态的文案都预先排版一遍、叠在一起撑出宽度：胶囊宽度按**当前语言、当前字号**下最长的那个定，
    /// 状态怎么切外框都不动。原来宽度随文案伸缩，「同步中 → 已同步」时整枚胶囊跟着抽一下。
    /// 不写死点数——中文三个字、法语「Non synchronisé」、放大字号，宽度都不一样
    private static let allTitles: [String] = [
        title(for: .idle), title(for: .synced(nil)), title(for: .syncing), title(for: .off(.noAccount)),
    ]

    var body: some View {
        Button {
            if status.isOff { onTapWhenOff?() }
        } label: {
            GlassPill(minHeight: size.height * typeScale,
                      leading: size.leading,
                      trailing: size.trailing) {
                icon
                    .font(.system(size: size.symbolSize * typeScale))
                ZStack(alignment: .leading) {
                    ForEach(Self.allTitles, id: \.self) { candidate in
                        titleText(candidate).hidden()
                    }
                    // 换文案时交叉淡化，不是一帧硬切（`.id` 让新旧两段各是一个视图，才有得淡）
                    titleText(title)
                        .id(title)
                        .transition(.opacity)
                }
                .accessibilityHidden(true)
            }
            .foregroundStyle(CopyoTheme.labelSecondary)
        }
        .buttonStyle(.plain)
        // 只有未同步态可点。不用 `.disabled`：它会把整枚胶囊压淡一档，
        // 「已同步」看上去比设计 01 浅得多，像是失效了。改成不接点按、旁白也不报「按钮」
        .allowsHitTesting(status.isOff)
        .accessibilityRemoveTraits(status.isOff ? [] : .isButton)
        .accessibilityLabel(title)
        // 图标与文案的所有切换都在这一个动画里：状态一变，交叉淡化约 0.25s。
        // 「减弱动态效果」下仍然淡化（那是透明度，不是位移），只是不转
        .animation(.smooth(duration: 0.25), value: status)
    }

    /// 同步中那一态**单独一个视图**，另外两态另一个。
    ///
    /// 原来是一个 `Image(systemName: symbol)` 挂 `.symbolEffect(..., isActive: isSyncing)`：状态一变，
    /// 图标换成 `checkmark.icloud`、`isActive` 变 false，可旋转效果并不停，而是**接着作用在新图标上**——
    /// 带勾的云没有可单独旋转的分层，于是整朵云一直转到下一次回到同步中（TestFlight 构建 7 真机上
    /// 「已同步」时云朵自转，模拟器里来回切状态逐帧复现）。分成两个分支，视图身份不同，
    /// 带效果的那个随状态整个移除，效果没有地方残留。
    ///
    /// 只转云里那两枚循环箭头，云本身不动（`.byLayer`）；约两秒一圈，同步是后台慢慢做的事。
    /// 「减弱动态效果」打开时不转，静止的图标加「同步中」已经把状态说清楚了
    @ViewBuilder
    private var icon: some View {
        if isSyncing {
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .symbolEffect(.rotate.byLayer,
                              options: .repeat(.continuous).speed(0.5),
                              isActive: !reduceMotion)
                .transition(.opacity)
        } else {
            // 另外三态之间换图标走系统的符号替换动画（云 → 带勾的云是一次「长出一个勾」，不是硬切）
            Image(systemName: symbol)
                .contentTransition(.symbolEffect(.replace))
                .transition(.opacity)
        }
    }

    private var isSyncing: Bool {
        if case .syncing = status { return true }
        return false
    }

    private func titleText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: size.fontSize * typeScale, weight: .medium))
            // 胶囊挂在导航栏右上角，宽度由标题挤剩下的地方决定。
            // 法语的「Non synchronisé」在放大档位下折成两行会把整条导航栏撑高，
            // 宁可按房规的 0.8 缩一点
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
