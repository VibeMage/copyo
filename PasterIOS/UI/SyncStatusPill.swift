import SwiftUI

/// 设计 3.6：右上角的 iCloud 状态胶囊。未同步态可点，跳到设置。
struct SyncStatusPill: View {
    let status: SyncStatus
    var compact: Bool = false
    var onTapWhenOff: (() -> Void)?

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
            GlassPill(height: compact ? 34 : PasterTheme.Metrics.syncPillHeight,
                      leading: compact ? 8 : 10,
                      trailing: compact ? 10 : 12) {
                Image(systemName: symbol)
                    .font(.system(size: compact ? 16 : 18))
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                Text(title)
                    .font(.system(size: compact ? 12 : 13, weight: .medium))
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
