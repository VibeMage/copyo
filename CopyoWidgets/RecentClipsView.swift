import SwiftUI
import WidgetKit

/// 「最近」小组件的外壳：头部 + 按尺寸分派的内容。
/// 空态与「库打不开」在这里统一处理，两个尺寸的视图因此只需要管有内容的情况。
struct RecentClipsView: View {
    let entry: RecentClipsEntry

    @Environment(\.widgetFamily) private var family

    /// 头部与内容之间的间距（设计 3.16 的 gap 8）
    var gap: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            WidgetHeader(trailing: headerTrailing)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // iOS 17 起小组件的底色**必须**走 `containerBackground`：不给的话系统不会退回旧的
        // 整块背景，而是直接画一张空白小组件。外圈内距同样交给系统的 container margins，
        // 不自己加 padding——系统会按机型微调那个值，我们写死 14 会和同一排的系统小组件对不齐。
        .containerBackground(CopyoTheme.bgCard, for: .widget)
    }

    /// 头部右侧那一格：中尺寸放同步状态（设计 08 的「已同步」），小尺寸放这一条的相对时间。
    /// 同步状态可能是未知的（主应用还没抄过、或那份快照已经过期），这时干脆不显示。
    private var headerTrailing: String? {
        if family == .systemMedium {
            return entry.syncState.map(Self.syncLabel)
        }
        return entry.snapshots.first?.relativeTime(at: entry.date)
    }

    private static func syncLabel(_ state: WidgetSyncState) -> String {
        switch state {
        case .synced: String(localized: "Synced")
        case .syncing: String(localized: "Syncing…")
        case .off: String(localized: "Not synced")
        }
    }

    @ViewBuilder
    private var content: some View {
        if entry.isLibraryUnavailable {
            // App Group 还没真正展开时会走到这里，是真机上 entitlement 生效之前的预期状态。
            // 借 `ClipIngest.IngestError.storeUnavailable` 的那句话：三份目录里都已经有它。
            message(String(localized: "Copyo can't open its library right now."))
        } else if let snapshot = entry.snapshots.first {
            if family == .systemMedium {
                MediumClipsView(snapshots: entry.snapshots, date: entry.date)
            } else {
                SmallClipView(snapshot: snapshot, date: entry.date)
            }
        } else {
            message(String(localized: "No clips yet"))
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(CopyoTheme.labelSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
