import SwiftUI

/// 「不想每次都点允许粘贴？」——历史页顶部的一次性提示卡。
///
/// 「从其他 App 粘贴」默认是「询问」：每读到一次新内容系统就弹一次框，点过「允许粘贴」也不记。
/// 设成「允许」之后回到 Copyo 就是静默保存，维护者真机上的原话是「交互流畅多了」。
/// 但 iOS 既不给读这项设置的 API，也没有直达这一行的深链，所以只能在**确实弹过框之后**告诉用户去哪改：
/// 出现条件在 `AppModel.refreshAllowPasteTip`，弹没弹框靠读取耗时判断（`PasteboardCapture.timedRead`）。
/// 那时系统设置里「设置 › App › Copyo」下的这一行一定已经存在——没弹过框之前它根本不显示，
/// 这正是引导页不再放「前往设置」的原因。
///
/// 外观照设计 3.5 的横幅：白底圆角卡、左侧 24pt 图标、标题 + 副文、右侧动作，与剪贴板横幅同一套。
/// 两者不会同时出现（`HistoryScreen` 里是 `if … else if`）。
struct AllowPasteTip: View {
    var onOpenSettings: () -> Void
    var onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var leadingSymbolSize: CGFloat = 24
    @ScaledMetric(relativeTo: .title2) private var leadingSymbolWidth: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var dismissSymbolSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var dismissDiameter: CGFloat = 28

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 辅助功能字号下不画左侧图标：图标、正文、× 三栏并排时正文只剩窄窄一条，
            // 「去设置」会在字中间断行。图标本来就是装饰（旁白也跳过它）
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "list.clipboard")
                    .font(.system(size: leadingSymbolSize))
                    .foregroundStyle(CopyoTheme.accent)
                    .frame(width: leadingSymbolWidth)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Tired of tapping Allow Paste?"))
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(CopyoTheme.label)
                    Text(String(localized: "In Settings › Apps › Copyo, set Paste from Other Apps to Allow. Copyo then saves new clips without asking."))
                        .font(.caption)
                        .foregroundStyle(CopyoTheme.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                Button {
                    if let url = SettingsLinks.appSettings { openURL(url) }
                    onOpenSettings()
                } label: {
                    InlineActionPill(title: String(localized: "Open Settings"))
                }
                .buttonStyle(.plain)
                // 读屏只听到「打开设置」分不清是 Copyo 的设置页还是系统「设置」
                .accessibilityHint(String(localized: "Open Copyo's Settings"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: dismissSymbolSize, weight: .semibold))
                    .foregroundStyle(CopyoTheme.labelSecondary)
                    .frame(width: dismissDiameter, height: dismissDiameter)
                    .background(CopyoTheme.fill, in: Circle())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Dismiss"))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(CopyoTheme.bgCard, in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.banner, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 1.5, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: CopyoTheme.Radius.banner, style: .continuous)
                .strokeBorder(CopyoTheme.separator.opacity(0.5), lineWidth: 0.5)
        )
        // 最大几档下这张卡会比半屏还高，把历史挤到折叠线以下；封顶在 accessibility3，与同步胶囊同一个思路
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}
