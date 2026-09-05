import Foundation
import PasterCore
import SwiftUI

/// iOS 端的用户设置。全部落在 App Group 的 UserDefaults suite 里：
/// 分享扩展和 Intent 也要读历史上限、也要写「待处理的一键保存」，各进程的 standard 是隔离的。
enum IOSSettings {

    /// 三个进程共用的 suite。理论上 App Group 一定拿得到；拿不到时退回 standard，
    /// 主应用至少还能正常读写自己的设置，不至于因为一个 nil 就整个跑不起来。
    static let defaults: UserDefaults = UserDefaults(suiteName: PasterStore.appGroupIdentifier) ?? .standard

    enum Key {
        static let cloudSyncEnabled = "cloudSyncEnabled"
        static let autoReadOnForeground = "autoReadOnForeground"
        /// 与 Mac 端同名，取值口径也一致（0 = 不限）
        static let historyLimit = "historyLimit"
        static let onboardingCompleted = "onboardingCompleted"
        /// 右滑固定的默认目标 Pinboard，存 name（PersistentIdentifier 不能进 UserDefaults）
        static let defaultPinboardName = "defaultPinboardName"
        static let lastPasteboardChangeCount = "lastPasteboardChangeCount"
        /// SaveClipboardIntent 写下的时间戳（timeIntervalSince1970），主应用激活时消费
        static let pendingQuickSaveAt = "pendingQuickSaveAt"
    }

    /// 历史上限的可选值，与 Mac 设置页一致（0 = 不限）
    static let historyLimitOptions: [Int] = [100, 300, 500, 1000, 0]

    /// 首次启动时把默认值注册进 suite，读取处就不必到处写 `?? 500`
    static func registerDefaults() {
        defaults.register(defaults: [
            Key.cloudSyncEnabled: true,
            Key.autoReadOnForeground: true,
            Key.historyLimit: 500,
            Key.onboardingCompleted: false,
        ])
    }

    static var cloudSyncEnabled: Bool {
        get { defaults.object(forKey: Key.cloudSyncEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.cloudSyncEnabled) }
    }

    static var autoReadOnForeground: Bool {
        get { defaults.object(forKey: Key.autoReadOnForeground) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.autoReadOnForeground) }
    }

    static var historyLimit: Int {
        get { defaults.object(forKey: Key.historyLimit) as? Int ?? 500 }
        set { defaults.set(newValue, forKey: Key.historyLimit) }
    }

    static var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Key.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Key.onboardingCompleted) }
    }

    static var defaultPinboardName: String? {
        get {
            let name = defaults.string(forKey: Key.defaultPinboardName)
            return (name?.isEmpty ?? true) ? nil : name
        }
        set { defaults.set(newValue ?? "", forKey: Key.defaultPinboardName) }
    }

    /// 上次处理过的 UIPasteboard.changeCount。首次运行是 nil：
    /// 这时不能当成「有新内容」，否则安装后第一次打开就会把用户手上不相干的剪贴板存进来。
    static var lastPasteboardChangeCount: Int? {
        get { defaults.object(forKey: Key.lastPasteboardChangeCount) as? Int }
        set {
            if let newValue { defaults.set(newValue, forKey: Key.lastPasteboardChangeCount) }
            else { defaults.removeObject(forKey: Key.lastPasteboardChangeCount) }
        }
    }

    static var pendingQuickSaveAt: Date? {
        get {
            let value = defaults.double(forKey: Key.pendingQuickSaveAt)
            return value > 0 ? Date(timeIntervalSince1970: value) : nil
        }
        set {
            if let newValue { defaults.set(newValue.timeIntervalSince1970, forKey: Key.pendingQuickSaveAt) }
            else { defaults.removeObject(forKey: Key.pendingQuickSaveAt) }
        }
    }
}

// 视图里要跟着设置变化刷新时，用 @AppStorage 并显式传 suite：
//   @AppStorage(IOSSettings.Key.cloudSyncEnabled, store: IOSSettings.defaults) private var enabled = true
// 不传 store 会落到 standard，扩展进程改的值读不到。
