import AppKit
import ServiceManagement
import SwiftUI

// MARK: - 通用

/// 通用页：启动 / 捕获两组照 v2 `Settings-general.dc.html`；「始终以纯文本复制」是既有功能，
/// 设计稿没画，单独成一小组放在捕获之后，不删。
struct GeneralSettingsView: View {
    @AppStorage("plainTextPaste") private var plainTextPaste = false
    @AppStorage(Preferences.showMenuBarIconKey) private var showMenuBarIcon = true
    @AppStorage(Preferences.captureEnabledKey) private var captureEnabled = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    /// 找回设置那句提示里要印当前快捷键；页面每次切进来都会重建，改完快捷键回来就是新值
    @State private var hotkeyDisplay = HotkeyConfig.load().displayString

    var body: some View {
        SettingsPage {
            SettingsHeader("Startup")
            SettingsGroup {
                SettingsToggleRow(title: Text("Launch Copyo at login"), isOn: $launchAtLogin) {
                    SettingsTile(hex: "#34C759", symbol: "power")
                }
                SettingsSeparator()
                // 第八节第 11(a) 条：允许关掉菜单栏图标，但必须当场告诉用户怎么回来——
                // 再次打开 App → 面板 → 齿轮，这条路径已经存在
                SettingsToggleRow(title: Text("Show icon in menu bar"),
                                  subtitle: Text("When this is off, press \(hotkeyDisplay) or open Copyo again in Finder to get back to Settings"),
                                  isOn: $showMenuBarIcon) {
                    SettingsTile(hex: "#8E8E93", symbol: "menubar.rectangle")
                }
            }

            SettingsHeader("Capture")
            SettingsGroup {
                SettingsToggleRow(title: Text("Record clipboard automatically"),
                                  subtitle: Text("Copyo records in the background and needs no permissions"),
                                  isOn: $captureEnabled) {
                    SettingsTile(color: CopyoTheme.accent, symbol: "doc.on.clipboard")
                }
                SettingsSeparator()
                // 第八节第 11(b) 条：不做开关。ConcealedType / TransientType 的过滤在 ClipboardMonitor 里
                // 无条件生效，给一个能关的开关等于承诺了一个不存在的行为
                SettingsRow(title: Text("Ignore password managers"),
                            subtitle: Text("Content from 1Password and Keychain is never recorded"),
                            lead: { SettingsTile(hex: "#FF9F0A", symbol: "key.fill") },
                            trailing: { SettingsValue("Always on") })
            }

            SettingsGroup {
                SettingsToggleRow(title: Text("Always copy as plain text"), isOn: $plainTextPaste) {
                    SettingsTile(hex: "#8E8E93", symbol: "doc.plaintext")
                }
            }
            // 第八节第 17 条：纯文本复制以 ⇧↩ 为准，界面只印 ⇧↩
            SettingsFooter("Applies when you press ↩. ⇧↩ always copies as plain text.")

            // 「不代粘贴」这条硬约束的对外说明，不可删、不可改写成粘贴动作的说明（design-spec §04）
            SettingsFooter("After you copy, Copyo writes the item back to the system clipboard and hands focus back to the app you came from. You press ⌘V yourself — Copyo never pastes for you.")
        }
        .onChange(of: launchAtLogin) { _, enabled in
            // 回弹到系统实际状态时这里会再进来一次；状态已经一致就什么都不做，免得反复注册
            guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // 用户可能在系统设置 → 登录项里改过
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
