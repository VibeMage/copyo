import Foundation
import SwiftUI

/// 截图与自动化用的启动参数。全部只影响演示状态，不改任何持久化设置。
///
/// 用法：
///   `-demoData`            用内存容器 + 设计稿样例数据（不碰真实数据库）
///   `-skipOnboarding`      跳过首启动引导
///   `-localOnly`           本次启动不挂 CloudKit（离线截图、无账号的 CI）
///   `-demoScreen <route>`  直接落到某个界面状态，取值见 `DemoRoute`
///   `-demoSidebar <item>`  iPad 分栏时选中某个侧栏项，取值见 `DemoSidebarItem`
///   `-demoTheme light|dark` 强制配色
///   `-simulateQuickSave`  启动时预置一次「一键保存」请求（模拟器里按不到控制中心的按钮）
struct LaunchOptions {
    var useDemoData = false
    var skipOnboarding = false
    var localOnly = false
    var simulateQuickSave = false
    var demoRoute: DemoRoute?
    var demoSidebar: DemoSidebarItem?
    var demoColorScheme: ColorScheme?

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init() {}

    init(arguments: [String]) {
        useDemoData = arguments.contains("-demoData")
        skipOnboarding = arguments.contains("-skipOnboarding")
        localOnly = arguments.contains("-localOnly")
        simulateQuickSave = arguments.contains("-simulateQuickSave")
        if let value = Self.value(of: "-demoScreen", in: arguments) {
            demoRoute = DemoRoute(rawValue: value)
        }
        if let value = Self.value(of: "-demoSidebar", in: arguments) {
            demoSidebar = DemoSidebarItem(rawValue: value)
        }
        switch Self.value(of: "-demoTheme", in: arguments) {
        case "light": demoColorScheme = .light
        case "dark": demoColorScheme = .dark
        default: demoColorScheme = nil
        }
    }

    private static func value(of flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        let value = arguments[index + 1]
        // 下一个参数又是个开关时说明这个 flag 后面漏了值
        return value.hasPrefix("-") ? nil : value
    }
}

/// `-demoScreen` 的取值。每个界面代理负责让自己那几个 route 落到正确状态，
/// 分发在 `AppModel.applyDemoRoute()` 与 `RootView`。
enum DemoRoute: String, CaseIterable {
    case history
    case historyEmpty = "history-empty"
    case historyBanner = "history-banner"
    case historySaved = "history-saved"
    case historyMenu = "history-menu"
    case historySearch = "history-search"
    case detailText = "detail-text"
    case detailRich = "detail-rich"
    case detailColor = "detail-color"
    case detailImage = "detail-image"
    case detailLink = "detail-link"
    case detailFile = "detail-file"
    case pinboards
    case pinboardContent = "pinboard-content"
    case pinboardNew = "pinboard-new"
    case settings
    case settingsQuickSave = "settings-quicksave"
    case settingsHowTo = "settings-howto"
    case settingsPaste = "settings-paste"
    case onboarding1 = "onboarding-1"
    case onboarding2 = "onboarding-2"
    case onboarding3 = "onboarding-3"
    /// 分享扩展是独立进程，App 内只打开一个宿主预览页（桩）
    case share

    /// 这个 route 属于哪个标签
    var tab: PasterTab {
        switch self {
        case .history, .historyEmpty, .historyBanner, .historySaved, .historyMenu, .historySearch,
             .detailText, .detailRich, .detailColor, .detailImage, .detailLink, .detailFile, .share:
            return .history
        case .pinboards, .pinboardContent, .pinboardNew:
            return .pinboard
        case .settings, .settingsQuickSave, .settingsHowTo, .settingsPaste:
            return .settings
        case .onboarding1, .onboarding2, .onboarding3:
            return .history
        }
    }

    /// 引导流程的第几页（非引导 route 为 nil）
    var onboardingPage: Int? {
        switch self {
        case .onboarding1: 0
        case .onboarding2: 1
        case .onboarding3: 2
        default: nil
        }
    }
}
