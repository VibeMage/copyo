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

    @State private var spinning = false

    private var symbol: String {
        switch status {
        case .synced: "checkmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .off: "icloud.slash"
        }
    }

    private var title: String {
        switch status {
        case .synced: String(localized: "Synced")
        case .syncing: String(localized: "Syncing…")
        case .off: String(localized: "Not synced")
        }
    }

    var body: some View {
        Button {
            if status.isOff { onTapWhenOff?() }
        } label: {
            GlassPill(minHeight: size.height * typeScale,
                      leading: size.leading,
                      trailing: size.trailing) {
                Image(systemName: symbol)
                    .font(.system(size: size.symbolSize * typeScale))
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                Text(title)
                    .font(.system(size: size.fontSize * typeScale, weight: .medium))
                    // 胶囊挂在导航栏右上角，宽度由标题挤剩下的地方决定。
                    // 法语的「Non synchronisé」在放大档位下折成两行会把整条导航栏撑高，
                    // 宁可按房规的 0.8 缩一点
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(CopyoTheme.labelSecondary)
        }
        .buttonStyle(.plain)
        .disabled(!status.isOff)
        .onChange(of: isSyncing, initial: true) { _, syncing in
            // 图标 1s 转一圈；iOS 26 有 .symbolEffect(.rotate)，这里用旋转动画保证 iOS 18 一致
            if syncing {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { spinning = true }
            } else {
                spinning = false
            }
        }
        .accessibilityLabel(title)
    }

    private var isSyncing: Bool {
        if case .syncing = status { return true }
        return false
    }
}
