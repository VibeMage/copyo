import Foundation

/// 扩展进程留下的待办请求的**应用侧**消费者。
///
/// 两条请求同一个形状：扩展进程干不了那件事（读不到剪贴板 / 写不了剪贴板），
/// 于是在 App Group 里留一条带时刻的请求并把主应用拉到前台，主应用一激活就来这里取走。
/// - 一键保存（通道 C，`SaveClipboardIntent`）——读一次剪贴板；
/// - 小组件点按复制（`CopyClipIntent`）——把某一条写回剪贴板。
///
/// 为什么用时刻而不是布尔值：Intent 触发之后主应用不一定马上起得来（用户可能按完就锁屏了，
/// 或者系统把冷启动排到了几分钟后）。过了有效期还照做，用户会莫名其妙地多出一条几分钟前的
/// 剪贴板内容、或者剪贴板被一条他早忘了自己点过的旧内容顶掉。
///
/// 类型名还叫 `QuickSaveCoordinator` 是历史原因——改名要连带改文件名，不在本次改动范围内。
@MainActor
enum QuickSaveCoordinator {

    /// 请求的有效期，两条请求共用。30 秒足够覆盖一次冷启动，又短到不会把「按下」和「打开」
    /// 当成同一件事。
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
        // 「打开 Copyo 时读取剪贴板」这个开关在这条路上不适用，changeCount 没变也照存。
        capture.captureNow()
        return true
    }

    /// 取走小组件那条「复制这一条」的请求，返回编码后的条目标识符。
    ///
    /// 与 `consume(with:)` 同一套规矩：先清后判有效期，过期就当没发生过。
    /// 读的是 `CopyoAppGroup` 而不是 `IOSSettings`——小组件进程写的是真实 suite，
    /// 而 `-demoData` 下 `IOSSettings.defaults` 被换成了一次性的演示 suite，两边不是同一份值。
    ///
    /// **解码留给调用方**（`SpotlightIndexer.modelID(from:)`），这里只负责取走那个串：
    /// 解不出来说明换过 store 文件（重装 / 重建库），小组件上那一批全是上一代的标识符，
    /// 用户按下之后该看到一句「这条不在了」而不是什么都不发生；在这里吞成 nil 的话，
    /// 调用方分不清「压根没有请求」和「请求解不开」，那一下就静默失效了。
    static func consumeCopyRequest() -> String? {
        guard let request = CopyoAppGroup.pendingCopyRequest else { return nil }
        CopyoAppGroup.clearPendingCopyRequest()
        guard Date().timeIntervalSince(request.requestedAt) < validity else { return nil }
        return request.clipID
    }
}
