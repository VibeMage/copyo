import Foundation
import PasterCore

/// 主应用与两个扩展共享容器的标识符，以及三个进程都要读写的那几个设置。
///
/// 真值在 PasterCore 里，这里只是三个进程共用的简称，避免各处硬编码字符串。
/// 主应用侧的读取端是 `IOSSettings`（用 `@AppStorage` 订阅同一个 suite），
/// **键名必须与 `IOSSettings.Key` 逐字一致**——写错一个字母的表现是「扩展写了、主应用读不到」，
/// 不报错也不崩溃，只是功能静默失效，所以这里刻意把键名重新声明一遍并加注释，而不是靠记忆。
public enum PasterAppGroup {
    public static let identifier = PasterStore.appGroupIdentifier

    /// 三个进程共用的 UserDefaults suite。取不到 suite（App Group capability 没配好）时退回 standard：
    /// 至少本进程内部读写自洽，不会因为一个 nil 让整个扩展跑不起来。
    public static let defaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard

    public enum Key {
        /// 未固定条目的上限，0 = 不限（与 Mac 端口径一致）
        public static let historyLimit = "historyLimit"
        /// 一键保存请求的时间戳（timeIntervalSince1970），由控件 / 操作按钮写入，主应用激活时消费
        public static let pendingQuickSaveAt = "pendingQuickSaveAt"
        /// 右滑固定与「保存到默认 Pinboard」的目标板名（PersistentIdentifier 不能进 UserDefaults）
        public static let defaultPinboardName = "defaultPinboardName"
    }

    /// 主应用在首启动时 register 了默认值 500；扩展进程有自己的一份 registration domain，
    /// 拿不到那份默认值，所以这里显式回落到同一个 500，避免扩展保存时按「不限」处理。
    public static var historyLimit: Int {
        defaults.object(forKey: Key.historyLimit) as? Int ?? 500
    }

    public static var defaultPinboardName: String? {
        let name = defaults.string(forKey: Key.defaultPinboardName)
        return (name?.isEmpty ?? true) ? nil : name
    }

    /// 通道 C：控件 / 操作按钮 / 锁屏按下时留一个时间戳。
    /// 扩展进程读不到剪贴板，真正的读取由主应用回到前台后完成。
    public static func markQuickSaveRequested(at date: Date = Date()) {
        defaults.set(date.timeIntervalSince1970, forKey: Key.pendingQuickSaveAt)
    }
}
