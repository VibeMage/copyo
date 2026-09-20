import CoreSpotlight
import CopyoCore
import SwiftData
import SwiftUI

@main
struct CopyoIOSApp: App {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    private let launch: LaunchOptions

    init() {
        // 默认值要先注册：建库时就会读 cloudSyncEnabled
        IOSSettings.registerDefaults()
        let launch = LaunchOptions.current
        self.launch = launch
        // 演示 / 截图模式的总闸要在**建库之前**合上：`-simulateQuickSave` 会在第一次 active
        // 就走完整条保存链路，晚一步样例条目（包括那条验证码）就进了开发者本人的
        // Spotlight 索引，而且截图进程退出后还留在那儿。
        SpotlightIndexer.isSuspended = launch.useDemoData
        _model = State(initialValue: AppModel(bootstrap: StoreBootstrap.make(launch: launch), launch: launch))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(model.container)
                .preferredColorScheme(launch.demoColorScheme)
                // 系统搜索结果被点开。冷启动时系统也是把这条 activity 交到这里，
                // 所以冷启、热启、以及「当前停在别的标签上」三种情况共用同一条路径；
                // 真正的导航落点由 `HistoryContent` 消费 `model.pendingDetailItemID` 完成。
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    model.openClipFromSpotlight(activity)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // 通道 A：只有回到前台才有机会读剪贴板，iOS 不给后台监听
            if phase == .active {
                model.handleScenePhaseActive()
                // 通道 C 的补读：控件的 perform 可能晚于这次激活才把请求写进 App Group
                model.retryPendingQuickSaveShortly()
            }
        }
    }
}
