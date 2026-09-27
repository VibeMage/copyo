import Foundation

/// 2026-09-27 新增的两个开关的 UserDefaults 键与默认值（设计稿「设置 · 通用」页）。
/// 既有的键（`historyLimit`、`plainTextPaste`、`ignoredApps`、`syncMode` 等）仍写在各自的使用处。
enum Preferences {
    /// 在菜单栏显示图标（design-spec 第八节第 11(a) 条）。关掉后入口只剩全局快捷键与
    /// 「在访达里再次打开 Copyo」（`applicationShouldHandleReopen` → 面板 → 齿轮），不会被锁在门外。
    static let showMenuBarIconKey = "showMenuBarIcon"
    /// 自动记录剪贴板。关掉后 `ClipboardMonitor` 照常对齐 changeCount，只是不入库——
    /// 打开时不会把关掉期间的最后一次复制补录进来。
    static let captureEnabledKey = "captureEnabled"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBarIconKey: true,
            captureEnabledKey: true,
        ])
    }
}
