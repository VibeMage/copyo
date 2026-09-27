import AppKit
import Carbon.HIToolbox
import SwiftUI

// MARK: - 快捷键

/// 快捷键页：上面是全局快捷键的录制行，下面是面板内键位的只读清单（v2 `Settings-general.dc.html` 右窗）。
struct ShortcutsSettingsView: View {
    @State private var hotkey = HotkeyConfig.load()
    @State private var isRecording = false
    @State private var recordingMonitor: Any?
    /// 刚才那次换绑被拒、已经回滚到的旧组合（第八节第 19 条）
    @State private var restoredTo: HotkeyConfig?
    /// 当前保存的组合此刻有没有注册成功。启动时就失败的话一进这页就要亮出来，
    /// 否则用户只会觉得「按了没反应」。
    @State private var registered = AppDelegate.shared?.hotkeyRegistered ?? true

    var body: some View {
        SettingsPage {
            SettingsHeader("Global Shortcut", subtitle: "Click to change")
            VStack(alignment: .leading, spacing: 6) {
                SettingsGroup {
                    recorderRow
                }
                if isRecording {
                    SettingsFooter("The combination must include at least one of ⌘, ⌥ or ⌃. Press Esc to cancel.")
                } else {
                    warnings
                }
            }

            SettingsHeader("In the Panel")
            // 两列并排，顶对齐（gen_v2.py 的 kgroup：`align-self: flex-start`）
            HStack(alignment: .top, spacing: 12) {
                keyGroup(Self.leftColumn)
                keyGroup(Self.rightColumn)
            }
        }
        .onAppear {
            registered = AppDelegate.shared?.hotkeyRegistered ?? true
        }
        .onDisappear { cancelRecording() }
    }

    // MARK: 录制行

    /// 录制行：`min-height 44`、`padding 8 12`（design-spec §04b），比普通行高一档
    private var recorderRow: some View {
        HStack(spacing: 10) {
            SettingsTile(hex: "#5856D6", symbol: "command")
            Text("Show Panel")
                .font(.system(size: 13))
                .foregroundStyle(CopyoTheme.label)
                .frame(maxWidth: .infinity, alignment: .leading)
            if hotkey != .default, !isRecording {
                Button("Reset") {
                    apply(.default)
                }
            }
            recorderButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
    }

    /// 录制按钮：最小宽 88、高 26、圆角 7、底 `bgCard`、等宽 12 / 500；
    /// 录制中描边换成 2pt accent，这就是「录制中」的全部视觉（design-spec §04b）
    private var recorderButton: some View {
        Button {
            isRecording ? cancelRecording() : startRecording()
        } label: {
            Group {
                if isRecording {
                    Text("Press the new shortcut…")
                } else {
                    Text(verbatim: hotkey.displayString)
                }
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(CopyoTheme.label)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minWidth: 88, minHeight: 26, maxHeight: 26)
            .background(CopyoTheme.bgCard, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isRecording ? CopyoTheme.accent : Self.recorderRing,
                                  lineWidth: isRecording ? 2 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Show Panel"))
        .accessibilityValue(isRecording ? Text("Press the new shortcut…") : Text(verbatim: hotkey.displayString))
    }

    /// 录制按钮静止态的 0.5pt 描边（设计稿 `0 0 0 0.5px rgba(0,0,0,0.12)`；深色按 glassRing 的白 15% 推导）
    private static let recorderRing = CopyoTheme.dynamic(light: CopyoTheme.rgb(0x000000, 0.12),
                                                          dark: CopyoTheme.rgb(0xFFFFFF, 0.15))

    /// 录制行下方的红色失败态：13pt 感叹号圆 + 11pt 文字，均为 `destructive`
    @ViewBuilder
    private var warnings: some View {
        if let restoredTo {
            warningLine(Text("This combination is already used by another app. Restored to \(restoredTo.displayString)."))
        }
        if !registered {
            // 回滚后的旧组合也注册不上，或者启动时就没注册上：如实说当前这个不起作用
            warningLine(Text("\(hotkey.displayString) isn’t working because another app is using it. Choose a different combination."))
        }
    }

    private func warningLine(_ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 12))
            text
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(CopyoTheme.destructive)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: 面板内键位

    private struct PanelShortcut: Identifiable {
        let title: LocalizedStringKey
        let keys: [SettingsKeycap]
        let id: Int
    }

    // 行名与键位随第八节第 17、18 条定稿：⇧↩ 纯文本复制、⌘Y 预览、⇥ 在筛选间循环、⌘1–9 直接复制（第 18c 条：选中并复制收起）。
    // 这是只读说明页，写错就是对用户说谎——面板键位改了，这里必须一起改。
    private static let leftColumn: [PanelShortcut] = [
        PanelShortcut(title: "Copy Selected Item", keys: [SettingsKeycap(verbatim: "↩")], id: 0),
        PanelShortcut(title: "Copy Selected as Plain Text", keys: [SettingsKeycap(verbatim: "⇧↩")], id: 1),
        PanelShortcut(title: "Preview", keys: [SettingsKeycap("Space"), SettingsKeycap(verbatim: "⌘Y")], id: 2),
        PanelShortcut(title: "Pin to Pinboard", keys: [SettingsKeycap(verbatim: "⌘P")], id: 3),
        PanelShortcut(title: "Delete", keys: [SettingsKeycap(verbatim: "⌘⌫")], id: 4),
    ]

    private static let rightColumn: [PanelShortcut] = [
        PanelShortcut(title: "Focus Search", keys: [SettingsKeycap(verbatim: "⌘F")], id: 0),
        PanelShortcut(title: "Cycle Through Filters", keys: [SettingsKeycap(verbatim: "⇥")], id: 1),
        PanelShortcut(title: "Copy Card N Directly", keys: [SettingsKeycap(verbatim: "⌘1–9")], id: 2),
        PanelShortcut(title: "Close Panel", keys: [SettingsKeycap(verbatim: "esc")], id: 3),
    ]

    /// 一列键位：每行高 34、`padding 0 12`、gap 6，非末行下边分隔线
    private func keyGroup(_ rows: [PanelShortcut]) -> some View {
        SettingsGroup {
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    Text(row.title)
                        .font(.system(size: 13))
                        .foregroundStyle(CopyoTheme.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(row.keys.enumerated()), id: \.offset) { _, key in
                        key
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
                .accessibilityElement(children: .combine)
                if row.id != rows.count - 1 {
                    SettingsSeparator()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 录制

    private func startRecording() {
        isRecording = true
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) && event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                cancelRecording()
                return nil
            }
            // 必须带 ⌘/⌥/⌃ 至少一个，避免把普通输入键劫持为全局快捷键
            guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty == false else {
                NSSound.beep()
                return nil
            }
            let carbon = HotkeyConfig.carbonFlags(from: event.modifierFlags)
            cancelRecording()
            apply(HotkeyConfig(keyCode: UInt32(event.keyCode), carbonModifiers: carbon))
            return nil
        }
    }

    private func cancelRecording() {
        if let monitor = recordingMonitor {
            NSEvent.removeMonitor(monitor)
            recordingMonitor = nil
        }
        isRecording = false
    }

    /// 保存并注册新组合；注册失败就回滚到旧组合再注册一次（第八节第 19 条 (a)）。
    ///
    /// 实测（2026-09-27）：别的 App 用 Carbon 占掉的组合，注册照样报成功，被系统快捷键占用的也一样，
    /// 所以这条回滚只覆盖罕见的注册失败，跨 App 冲突在这里拦不住（见 HotkeyManager.register 与 7.5.1）。
    private func apply(_ config: HotkeyConfig) {
        let previous = HotkeyConfig.load()
        guard config != previous else {
            restoredTo = nil
            // 同一个组合重录一遍：当前没注册上时这就是「我已经把占用它的 App 关了，再试一次」，
            // 必须真去重注册，否则顶上的警告永远消不掉
            if !registered {
                registered = AppDelegate.shared?.reloadHotkey() ?? true
            }
            return
        }
        save(config)
        // AppDelegate 不在（理论上走不到）就当成功处理，界面跟着存下来的值走
        if AppDelegate.shared?.reloadHotkey() ?? true {
            restoredTo = nil
            registered = true
        } else {
            save(previous)
            registered = AppDelegate.shared?.reloadHotkey() ?? true
            restoredTo = previous
        }
        hotkey = HotkeyConfig.load()
    }

    /// 默认组合不写进 UserDefaults：保持「没存过 = 默认」，以后改默认值时老用户跟着走
    private func save(_ config: HotkeyConfig) {
        if config == .default {
            HotkeyConfig.resetToDefault()
        } else {
            config.save()
        }
    }
}
