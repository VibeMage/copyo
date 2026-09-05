import AppIntents

/// 采集通道 C（Control 路径）：操作按钮 / 控制中心 / 锁屏控件按下时触发。
///
/// 扩展进程**读不到剪贴板**（iOS 10 起后台读取一律为空，iOS 16 的授权弹窗也无处弹），
/// 所以这里只留一个时间戳就把主应用拉到前台，真正的读取由前台的
/// `QuickSaveCoordinator` 完成。要全程静默不离开当前 App 的话走 `SaveContentIntent`
/// （快捷指令「获取剪贴板 → Paster 保存内容」），见 docs/ios-plan.md 3.1 的两条路径对照。
struct SaveClipboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Clipboard"
    static let description = IntentDescription(
        "Opens Paster and saves whatever is on the clipboard right now.",
        categoryName: "Clipboard",
        searchKeywords: ["clipboard", "paste", "save"]
    )
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PasterAppGroup.markQuickSaveRequested()
        return .result()
    }
}
