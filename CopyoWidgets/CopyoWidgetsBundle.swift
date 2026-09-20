import AppIntents
import SwiftUI
import WidgetKit

/// 一个 bundle 同时装主屏小组件与控件。
/// `ControlWidget` 并不 refine `Widget`，但 `WidgetBundleBuilder` 有一个专门适配它的
/// `buildExpression` 重载，所以两种东西可以并排写在这里，不必再开一个扩展 target。
@main
struct CopyoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RecentClipsWidget()
        SaveClipboardControl()
    }
}

/// 控制中心 / 锁屏 / 操作按钮共用的同一个控件（design-spec 08、3.16）。
/// iOS 18 起这三个入口都认 ControlWidget，一次实现三处入口。
///
/// 按下只是留个时间戳并把主应用拉到前台（见 `SaveClipboardIntent`）：
/// 控件跑在扩展进程里，读不到剪贴板。
struct SaveClipboardControl: ControlWidget {
    /// 已经发布过的 kind 不能改：改了等于换了一个控件，用户在控制中心里配好的按钮会消失。
    static let kind = "dev.vibemage.Copyo.saveClipboard"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: SaveClipboardIntent()) {
                Label(String(localized: "Save Clipboard"), systemImage: "tray.and.arrow.down.fill")
            }
        }
        .displayName(LocalizedStringResource("Save Clipboard"))
        .description(LocalizedStringResource("Saves what's on the clipboard to Copyo."))
    }
}
