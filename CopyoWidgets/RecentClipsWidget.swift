import SwiftUI
import WidgetKit

/// 主屏小组件「最近」：小尺寸一条、中尺寸四条（设计 08）。
///
/// 两个尺寸共用**一个 kind**，靠 `context.family` 分取数条数、靠 `@Environment(\.widgetFamily)`
/// 分布局。拆成两个 kind 的话每次库变动都要发两次 `reloadTimelines`，
/// 而 WidgetKit 对后台发起的刷新一天只给四五十次；用户在画廊里也会看到两个名字近乎一样的条目。
struct RecentClipsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetRefresher.recentClipsKind,
                               intent: RecentClipsConfiguration.self,
                               provider: RecentClipsProvider()) { entry in
            RecentClipsView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("Recent Clips"))
        .description(LocalizedStringResource("The clips you copied most recently. Tap one to copy it again."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
