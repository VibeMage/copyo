import SwiftUI

/// 设计 3.6：右上角的 iCloud 状态胶囊。未同步态可点，跳到设置。
struct SyncStatusPill: View {

    /// 设计 3.6 给了三档尺寸：iPhone 40 / iPad 36 / Slide Over 34。
    /// 原来只有一个 `compact: Bool`，iPhone 与 iPad 都传 true，两处用的都是最小的 Slide Over 档。
    enum Size {
        case phone
        case pad
        case slideOver

        var height: CGFloat {
            switch self {
            case .phone: PasterTheme.Metrics.syncPillHeight
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

    @State private var spinning = false
    /// iPad 分栏时同步胶囊由 detail 列容器统一提供，界面自己那份要让位（见 `pasterHidesSyncStatusPill`）
    @Environment(\.pasterHidesSyncStatusPill) private var hidden

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
        if !hidden { pill }
    }

    private var pill: some View {
        Button {
            if status.isOff { onTapWhenOff?() }
        } label: {
            GlassPill(height: size.height,
                      leading: size.leading,
                      trailing: size.trailing) {
                Image(systemName: symbol)
                    .font(.system(size: size.symbolSize))
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                Text(title)
                    .font(.system(size: size.fontSize, weight: .medium))
            }
            .foregroundStyle(PasterTheme.labelSecondary)
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
