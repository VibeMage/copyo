import Foundation

/// 采集通道 C 的**应用侧**：消费控件 / 操作按钮 / 锁屏留下的那次一键保存请求。
///
/// 分工是这样的：扩展进程读不到剪贴板，`SaveClipboardIntent` 只能在 App Group 里写一个时间戳
/// 并把主应用拉到前台；主应用一激活就来这里看有没有待办的请求，有就立刻读一次剪贴板。
///
/// 为什么用时间戳而不是布尔值：Intent 触发之后主应用不一定马上起得来（用户可能按完就锁屏了，
/// 或者系统把冷启动排到了几分钟后）。过了有效期还照读，用户会莫名其妙地多出一条几分钟前的剪贴板内容。
@MainActor
enum QuickSaveCoordinator {

    /// 请求的有效期。30 秒足够覆盖一次冷启动，又短到不会把「按下」和「打开」当成同一件事。
    static let validity: TimeInterval = 30

    /// `-simulateQuickSave`：启动时预置一次请求。
    /// 模拟器里没法真的按控制中心的按钮，截图与冒烟只能靠它走通整条链路。
    static func primeIfSimulated(_ launch: LaunchOptions) {
        guard launch.simulateQuickSave else { return }
        IOSSettings.pendingQuickSaveAt = Date()
    }

    /// 有待办请求就读一次剪贴板，返回 true 表示这次激活已经被一键保存接管。
    ///
    /// 无论过没过期都先把时间戳清掉：留着只会在下一次激活时再触发一遍。
    @discardableResult
    static func consume(with capture: PasteboardCapture) -> Bool {
        guard let requestedAt = IOSSettings.pendingQuickSaveAt else { return false }
        IOSSettings.pendingQuickSaveAt = nil
        guard Date().timeIntervalSince(requestedAt) < validity else { return false }
        // 用 captureNow 而不是 checkOnForeground：用户亲手按了按钮，
        // 「打开 Paster 时读取剪贴板」这个开关在这条路上不适用，changeCount 没变也照存。
        capture.captureNow()
        return true
    }
}
