import AppIntents

/// 「最近」小组件的配置意图。**现在一个参数都没有，仍然走 `AppIntentConfiguration`。**
///
/// 理由是迁移方向：`StaticConfiguration` → `AppIntentConfiguration` 是已发布的 kind 上
/// 那条出了名难走的路（老的配置读不回来，用户得把小组件删掉重摆），反过来则毫无代价。
/// 而这里明摆着有一个迟早要加的参数——**显示哪一个 Pinboard**：`Pinboard` 已经在库里，
/// `ClipIngest.boardOptions(in:)` 返回的 `ShareBoardOption` 又正好是 `AppEntity` 要的
/// 值类型形状（`id` / `name` / `iconName` / `colorHex`，`Sendable`），
/// 加参数那天基本只剩把它包成 `AppEntity` 这一步。
///
/// 没有参数时系统不会给小组件显示「编辑小组件」入口，用户看不出和静态配置的区别。
struct RecentClipsConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Recent Clips"
    static let description = IntentDescription("The clips you copied most recently. Tap one to copy it again.")
}
