import AppIntents
import SwiftUI
import WidgetKit

@main
struct PasterWidgetsBundle: WidgetBundle {
    var body: some Widget {
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
    static let kind = "dev.vibemage.Paster.saveClipboard"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: SaveClipboardIntent()) {
                Label(String(localized: "Save Clipboard"), systemImage: "tray.and.arrow.down.fill")
            }
        }
        .displayName(LocalizedStringResource("Save Clipboard"))
        .description(LocalizedStringResource("Saves what's on the clipboard to Paster."))
    }
}
