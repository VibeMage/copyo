import PasterCore
import SwiftData
import SwiftUI

@main
struct PasterIOSApp: App {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    private let launch: LaunchOptions

    init() {
        // 默认值要先注册：建库时就会读 cloudSyncEnabled
        IOSSettings.registerDefaults()
        let launch = LaunchOptions.current
        self.launch = launch
        _model = State(initialValue: AppModel(bootstrap: StoreBootstrap.make(launch: launch), launch: launch))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(model.container)
                .preferredColorScheme(launch.demoColorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            // 通道 A：只有回到前台才有机会读剪贴板，iOS 不给后台监听
            if phase == .active { model.handleScenePhaseActive() }
        }
    }
}
