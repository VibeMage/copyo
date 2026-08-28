import SwiftUI

@main
struct PasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 应用以菜单栏常驻方式运行（LSUIElement），不需要常规窗口场景
        Settings {
            EmptyView()
        }
    }
}
