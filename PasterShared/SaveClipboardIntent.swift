import AppIntents

/// 采集通道 C：操作按钮 / 控制中心 / 锁屏控件按下时触发。
/// 扩展进程读不到剪贴板，所以必须先把主应用拉到前台，由前台完成读取入库。
struct SaveClipboardIntent: AppIntent {
    static let title: LocalizedStringResource = "保存剪贴板"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
