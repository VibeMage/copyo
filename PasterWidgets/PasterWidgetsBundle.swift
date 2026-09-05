import AppIntents
import SwiftUI
import WidgetKit

@main
struct PasterWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SaveClipboardControl()
    }
}

/// 控制中心 / 锁屏 / 操作按钮共用的同一个控件。
struct SaveClipboardControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "dev.vibemage.Paster.saveClipboard") {
            ControlWidgetButton(action: SaveClipboardIntent()) {
                Label(String(localized: "保存剪贴板"), systemImage: "tray.and.arrow.down.fill")
            }
        }
    }
}
