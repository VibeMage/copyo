import AppKit
import Carbon.HIToolbox
import SwiftUI

// MARK: - 快捷键

/// 快捷键页：上面是全局快捷键的录制行，下面是面板内键位的只读清单（v2 `Settings-general.dc.html` 右窗）。
struct ShortcutsSettingsView: View {
    @State private var hotkey = HotkeyConfig.load()
    @State private var isRecording = false
    @State private var recordingMonitor: Any?
    /// 录制期间盯着「按下去却没送到录制器」的组合——它被别人在全局截走了（7.5.1）
    @State private var swallowWatcher: SwallowedComboWatcher?
    /// 最近一次录制 / 换绑报出的一次性提示：开始新的录制、关窗时清掉；与重新探测出的状态矛盾时也清（见 `recheck`）（7.5.1）
    @State private var notice: Notice?
    /// 当前保存的组合此刻的注册结果。启动时就冲突的话一进这页就要亮出来，
    /// 否则用户只会觉得「按了没反应」。
    @State private var status = AppDelegate.shared?.hotkeyStatus ?? .active

    private enum Notice {
        /// 换绑被拒，当前组合没变：已经回滚到的旧组合，以及被拒的原因（第八节第 19 条）
        case rolledBack(to: HotkeyConfig, reason: HotkeyStatus)
        /// 重录的正是当前组合，却被另一个 App 截走了，而注册探测不出来：对方是非独占注册（按下时两边都响应），
        /// 或是用 CGEventTap 截键的工具（Copyo 根本收不到）——从这边分不出是哪一种，文案不做保证。
        /// 这时没有什么被「恢复」，第 19 条那句用不上
        case shared
    }

    var body: some View {
        SettingsPage {
            SettingsHeader("Global Shortcut", subtitle: "Click to change")
            SettingsGroup {
                recorderRow
            }
            // 警示行是内容区的下一块，与「唤出」分组之间就是内容区的 gap 12（design-spec 3.12；gen_v2.py:473、:517-521）
            if isRecording {
                SettingsFooter("The combination must include at least one of ⌘, ⌥ or ⌃. Press Esc to cancel.")
            } else if notice != nil || status != .active {
                warnings
            }

            SettingsHeader("In the Panel")
            // 两列并排，顶对齐（gen_v2.py 的 kgroup：`align-self: flex-start`）
            HStack(alignment: .top, spacing: 12) {
                keyGroup(Self.leftColumn)
                keyGroup(Self.rightColumn)
            }
        }
        .onAppear { recheck() }
        .onDisappear { cancelRecording() }
        // 设置窗口只建一次，关窗只是 orderOut：SwiftUI 此时既不发 onDisappear，再打开也不发 onAppear（实测）。
        // 所以关窗要自己取消录制——否则监视器还挂着、让出的全局快捷键也回不来；一次性提示也在这时清掉，
        // 免得几天后再打开还挂着一条过期的。窗口重新成为 key（再次打开、从别的 App 切回来）时再探测一遍
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            guard Self.isSettingsWindow(note.object) else { return }
            cancelRecording()
            notice = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if Self.isSettingsWindow(note.object) { recheck() }
        }
        // 录制时 Copyo 让出了自己的全局快捷键：用户切到别的 App 去（或点开了面板）就得马上还回来，
        // 否则直到回来取消录制之前，这个组合按下去都没反应。App 失去前台与窗口失去 key 都接，重复调用无妨
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            if Self.isSettingsWindow(note.object) { recordingLostFocus() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            recordingLostFocus()
        }
    }

    /// 重注册一遍，顺带重新探测冲突：在 Copyo 之后才独占同一组合的 App、刚在系统设置里打开的系统快捷键，
    /// 都要到这时才查得出来；对方退出了、系统快捷键关掉了，警示也随之消掉（HotkeyManager.register）。
    /// 录制中不做：那时当前组合是特意让出去的。
    ///
    /// `.shared` 是在状态为 `.active` 时报的；现在探测出了别的状态，那一行常驻警示已经说清楚了，
    /// 再留着「另一个 App 也在用」那句，两行就说法不一。反过来状态仍是 `.active` 时不清：非独占的占用探测不出来，
    /// 看不出对方是否已经退出，何况对方启动器把焦点拿走、用户再切回来，正是这里被调用的时候
    private func recheck() {
        guard !isRecording else { return }
        status = AppDelegate.shared?.reloadHotkey() ?? .active
        if case .shared? = notice, status != .active {
            notice = nil
        }
    }

    private static func isSettingsWindow(_ object: Any?) -> Bool {
        (object as? NSWindow)?.windowController is SettingsWindowController
    }

    // MARK: 录制行

    /// 录制行就是一条普通行 `srow()`：`min-height 40`、`padding 7 12`、`gap 10`（design-spec §04b、3.12；gen_v2.py:518、:442-448）。
    /// v1 的 `min-height 44`、`padding 8 12` 已作废
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
        .padding(.vertical, 7)
        .frame(minHeight: 40)
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

    /// 录制行下方的红色失败态：13pt 感叹号圆 + 11pt 文字，均为 `destructive`。
    /// 「另一个 App」与「系统快捷键」分开说（7.5.1）：后者要去系统设置里改，用户得知道是哪一边。
    /// 一次性提示与常驻警示同时出现时（回滚后旧组合也注册不上，3.12 设计未定）两行之间沿用 6。
    /// 调用方只在 `notice` 或 `status` 至少有一个要说时才放它，免得空栈在分组下方白占一个 gap
    private var warnings: some View {
        VStack(alignment: .leading, spacing: 6) {
            noticeLine
            statusLine
        }
    }

    @ViewBuilder
    private var noticeLine: some View {
        switch notice {
        case .rolledBack(let restoredTo, let reason)?:
            let restored = restoredTo.displayString
            if reason == .takenBySystem {
                warningLine(Text("This combination is already used by a macOS keyboard shortcut. Restored to \(restored)."))
            } else {
                warningLine(Text("This combination is already used by another app. Restored to \(restored)."))
            }
        case .shared?:
            warningLine(Text("\(hotkey.displayString) is also used by another app: pressing it triggers that app, and Copyo may not respond. Choose a different combination."))
        case nil:
            EmptyView()
        }
    }

    /// 回滚后的旧组合也有冲突，或者启动时就有冲突：如实说当前这个不起作用
    @ViewBuilder
    private var statusLine: some View {
        switch status {
        case .active:
            EmptyView()
        case .takenBySystem:
            warningLine(Text("\(hotkey.displayString) isn’t working because macOS uses it as a keyboard shortcut. Choose a different combination, or turn that shortcut off in System Settings."))
        case .takenByApp, .failed:
            // .failed 是注册本身出错（参数非法之类，实际罕见），没有更贴切的说法，沿用「被另一个 App 占用」
            warningLine(Text("\(hotkey.displayString) isn’t working because another app is using it. Choose a different combination."))
        }
    }

    private func warningLine(_ text: Text) -> some View {
        // 图标与文字垂直居中（3.12 警示行表 `align-items: center`；gen_v2.py:519）。文案折成多行时（fr、zh 的常驻警示）
        // 图标照 CSS 同一语义落在段落中间；画板只画了单行，多行该贴首行还是居中设计未定，先按画板
        HStack(alignment: .center, spacing: 6) {
            // 画板 13pt、线宽 1.6 → .medium（第八节第 25 条；gen_v2.py:519-521）
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13, weight: .medium))
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

    /// 被别的 App 占用的组合，按下时由占用方在全局截走，本地监视器收不到 keyDown——这一点改不了
    /// （要先停掉别人的快捷键得有辅助功能权限，见 SwallowedComboWatcher）。能做的是两件事：
    /// 先让出 Copyo 自己的注册，免得重录当前组合时被自己截走、只弹出面板；
    /// 再由 SwallowedComboWatcher 发现被截走的组合，当成一次被拒的换绑报出来。
    ///
    /// 只在 Copyo 是前台 App、设置窗口是 key 时开始：结束录制靠的是失焦、失去 key 这两条通知，不在前台时开始
    /// （辅助功能 API 在后台按下了这个按钮）就等不到它们，让出的全局快捷键会一直空着。
    /// 上一次尝试留下的提示在这里清掉——提示只属于最近一次尝试，这次取消了，也不该再冒出上一次的「已恢复为」
    private func startRecording() {
        guard NSApp.isActive, Self.isSettingsWindow(NSApp.keyWindow) else { return }
        notice = nil
        isRecording = true
        AppDelegate.shared?.suspendHotkey()
        let watcher = SwallowedComboWatcher { combo, globeHeld in
            reportSwallowed(combo, globeHeld: globeHeld)
        } onFocusLost: {
            cancelRecording()
        }
        watcher.start()
        swallowWatcher = watcher
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            watcher.noteDelivered(keyCode: event.keyCode)
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
            stopRecording()
            apply(HotkeyConfig(keyCode: UInt32(event.keyCode), carbonModifiers: carbon))
            return nil
        }
    }

    /// 结束录制但不注册：紧接着由 apply(_:) 注册
    private func stopRecording() {
        if let monitor = recordingMonitor {
            NSEvent.removeMonitor(monitor)
            recordingMonitor = nil
        }
        swallowWatcher?.stop()
        swallowWatcher = nil
        isRecording = false
    }

    /// 放弃录制：把录制时让出的当前组合注册回来（也就重新探测了一遍冲突）
    private func cancelRecording() {
        guard isRecording else { return }
        stopRecording()
        status = AppDelegate.shared?.reloadHotkey() ?? .active
    }

    /// 录制期间设置窗口失去 key，或 Copyo 失去前台。还有按下后没送到录制器的键，就是它被截走、
    /// 对方的动作把焦点拿走了（⌘Tab、弹出自己窗口的启动器），照截走报；否则只是用户走开了，放弃录制。
    /// 两条路都会把让出的组合注册回来。
    private func recordingLostFocus() {
        guard isRecording else { return }
        if swallowWatcher?.reportPending() != true {
            cancelRecording()
        }
    }

    /// 录制时按下的组合被别人在全局截走了（SwallowedComboWatcher）。按第八节第 19 条的口径当作一次
    /// 被拒的换绑：当前组合不动，亮「已被占用，已恢复为 <当前组合>」。能对上已启用的系统快捷键就说是系统，
    /// 否则说是另一个 App。
    private func reportSwallowed(_ combo: HotkeyConfig, globeHeld: Bool) {
        let current = HotkeyConfig.load()
        // 让出的当前组合注册回来，也就重新探测了一遍，status 随之更新
        cancelRecording()
        guard combo != current || globeHeld else {
            // 截走的正是当前组合。探测得到的（系统快捷键、别的 App 独占）上面的重注册已经亮出常驻行，
            // 不再重复；探测不到的只剩「另一个 App 非独占地也注册了它」或「有工具用 event tap 截走了它」——如实说
            notice = status == .active ? .shared : nil
            return
        }
        notice = .rolledBack(to: current,
                             reason: SystemHotkeys.isEnabled(combo, globeHeld: globeHeld) ? .takenBySystem : .takenByApp)
    }

    /// 保存并注册新组合；注册结果不是 `.active` 就回滚到旧组合再注册一次（第八节第 19 条 (a)）。
    ///
    /// 这里拦得下的是 HotkeyManager.register 探测得到的三种：别的 App 独占、已启用的系统快捷键、注册失败。
    /// 别的 App 以非独占方式占用的组合，注册 API 查不到（7.5.1），但它在录制时就会被截走，
    /// 由 reportSwallowed 在走到这里之前报出来。
    private func apply(_ config: HotkeyConfig) {
        let previous = HotkeyConfig.load()
        guard config != previous else {
            // 同一个组合重录一遍：录制时让出了它，这里必须重新注册；这也就是「我已经把占用它的 App 关了，
            // 再试一次」——重注册会重新探测，顶上的警示随之更新
            notice = nil
            status = AppDelegate.shared?.reloadHotkey() ?? .active
            return
        }
        save(config)
        // AppDelegate 不在（理论上走不到）就当成功处理，界面跟着存下来的值走
        let result = AppDelegate.shared?.reloadHotkey() ?? .active
        if result == .active {
            notice = nil
            status = .active
        } else {
            save(previous)
            status = AppDelegate.shared?.reloadHotkey() ?? .active
            notice = .rolledBack(to: previous, reason: result)
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
