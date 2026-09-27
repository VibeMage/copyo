import AppKit
import Carbon.HIToolbox

/// 全局快捷键配置：keyCode + Carbon 修饰键，持久化在 UserDefaults。
struct HotkeyConfig: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let `default` = HotkeyConfig(keyCode: UInt32(kVK_ANSI_V),
                                        carbonModifiers: UInt32(cmdKey | shiftKey))

    static func load() -> HotkeyConfig {
        let defaults = UserDefaults.standard
        guard let code = defaults.object(forKey: "hotkeyKeyCode") as? Int,
              let mods = defaults.object(forKey: "hotkeyModifiers") as? Int else {
            return .default
        }
        return HotkeyConfig(keyCode: UInt32(code), carbonModifiers: UInt32(mods))
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: "hotkeyKeyCode")
        defaults.set(Int(carbonModifiers), forKey: "hotkeyModifiers")
    }

    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: "hotkeyKeyCode")
        UserDefaults.standard.removeObject(forKey: "hotkeyModifiers")
    }

    static func carbonFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }

    var cocoaModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbonModifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbonModifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbonModifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    /// 如 "⇧⌘V"，用于界面展示
    var displayString: String {
        var symbols = ""
        if carbonModifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols + Self.keyName(for: keyCode)
    }

    /// 用于 NSMenuItem.keyEquivalent 的小写字符（仅当按键可用字符表示时）
    var keyEquivalentCharacter: String? {
        let name = Self.characterName(for: keyCode)
        return name?.lowercased()
    }

    private static let specialKeyNames: [UInt32: String] = [
        UInt32(kVK_Space): String(localized: "Space"), UInt32(kVK_Return): "↩", UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Escape): "⎋", UInt32(kVK_Delete): "⌫", UInt32(kVK_ForwardDelete): "⌦",
        UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_Home): "↖", UInt32(kVK_End): "↘",
        UInt32(kVK_PageUp): "⇞", UInt32(kVK_PageDown): "⇟",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3", UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6", UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9", UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
        // 下面这些经键盘布局翻译出来是控制字符（F13/F14 是 U+0010、Help 是 U+0005、小键盘 Enter 是 U+0003、
        // Clear 是 U+001B），或者什么都没有（F19、F20），不列在这里界面上就是一个看不见的字符或「按键 80」。
        // 冲突警示行（第八节第 19 条）靠它告诉用户是哪个组合
        UInt32(kVK_F13): "F13", UInt32(kVK_F14): "F14", UInt32(kVK_F15): "F15", UInt32(kVK_F16): "F16",
        UInt32(kVK_F17): "F17", UInt32(kVK_F18): "F18", UInt32(kVK_F19): "F19", UInt32(kVK_F20): "F20",
        UInt32(kVK_Help): String(localized: "Help"),
        UInt32(kVK_ANSI_KeypadEnter): "⌤", UInt32(kVK_ANSI_KeypadClear): "⌧",
    ]

    static func keyName(for keyCode: UInt32) -> String {
        if let special = specialKeyNames[keyCode] { return special }
        return characterName(for: keyCode)?.uppercased() ?? String(localized: "Key \(Int(keyCode))")
    }

    /// 通过当前键盘布局把 keyCode 翻译为字符
    private static func characterName(for keyCode: UInt32) -> String? {
        guard specialKeyNames[keyCode] == nil,
              let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = unsafeBitCast(layoutPointer, to: CFData.self)
        guard let bytes = CFDataGetBytePtr(layoutData) else { return nil }
        let keyboardLayout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = UCKeyTranslate(keyboardLayout,
                                    UInt16(keyCode),
                                    UInt16(kUCKeyActionDisplay),
                                    0,
                                    UInt32(LMGetKbdType()),
                                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                    &deadKeyState,
                                    chars.count,
                                    &length,
                                    &chars)
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: chars, count: length)
        // 上面没列到的键翻译出控制字符时同样画不出来，当作没有名字：界面回退成「按键 N」，菜单不标键位
        guard !text.isEmpty,
              !text.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else { return nil }
        return text
    }
}

/// 一次注册的结果，设置 · 快捷键页据此回滚并亮警示行（第八节第 19 条）。
enum HotkeyStatus: Equatable {
    /// 注册成功，且没发现冲突（不等于一定没有冲突，见 `HotkeyManager.register` 的注释）
    case active
    /// 另一个 App 以独占方式（`kEventHotKeyExclusive`）注册了同一组合：按下去只有它收得到
    case takenByApp
    /// 与一条已启用的系统快捷键相同（系统设置 › 键盘 › 键盘快捷键里那些）
    case takenBySystem
    /// `RegisterEventHotKey` 本身失败（参数非法等，实际罕见）
    case failed
}

/// 通过 Carbon RegisterEventHotKey 注册系统级全局快捷键。
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    var onHotkey: (() -> Void)?

    /// 注册（或换绑）全局快捷键，并尽力查出冲突（design-spec 7.5.1、第八节第 19 条）。
    ///
    /// **能检测到的范围**（2026-09-27 实测，实验记录在 copyo-54r）：
    /// - `options 0`（非独占）注册**跨进程从不报错**：别的进程注册了同一组合、独占也好非独占也好，
    ///   这边照样 noErr；`eventHotKeyExistsErr` 只在本进程内重复注册，或**两边都独占**时出现。
    ///   两边都非独占时，按一下**两个 App 都会收到**。
    /// - 独占注册会让所有非独占注册者（不论先后）静默收不到事件，而后者注册时照样 noErr。
    ///   所以别的 App 独占了这个组合，Copyo 就是「按下去毫无反应」。
    /// - 因此这里先用 `kEventHotKeyExclusive` **探测一次**：报 `eventHotKeyExistsErr` 就是有 App 独占
    ///   → `.takenByApp`。探测完立即注销，常驻注册仍用非独占（理由见下）。
    /// - 多数系统快捷键不在 Carbon 注册表里，独占探测照样成功（⌘Space、⌃Space 实测）；少数在表里有独占注册，
    ///   探测报「已存在」（⌘Tab、⇧⌘Tab、⌥⌘Esc 实测）。所以系统快捷键一律拿 `CopySymbolicHotKeys()` 里
    ///   **已启用**的条目比对 → `.takenBySystem`，并且**先于**独占探测判断，免得 ⌘Tab 被说成「另一个 App」。
    ///   它在沙盒里可用，列出的启用状态与系统设置一致；比对规则（fn 位 / 🌐）见 `SystemHotkeys.isEnabled`。
    ///   按下去是系统先拿走，Copyo 收不到（7.5.1 原记录；本轮没有投递系统组合去复测，那会真的触发系统动作）。
    ///
    /// **检测不到的**：
    /// - 别的 App 以非独占方式注册了同一组合（绝大多数 App 都是这样注册的，包括 Copyo 自己）——
    ///   两边都收得到，没有任何 API 能查到对方。只有录制时能从「按下去却没送到录制器」看出来，
    ///   见 `SwallowedComboWatcher`。
    /// - 别的 App 在 Copyo 注册**之后**才独占同一组合：先注册的一方收不到任何通知，
    ///   只能等下一次调用本方法时再探测出来（设置 · 快捷键页每次出现、以及停在该页时设置窗口重新成为 key，
    ///   都会重注册一遍；菜单栏与面板空态用的 `AppDelegate.hotkeyStatus` 也只在这些时候和启动、换绑时刷新）。
    /// - 别的 App 用 CGEventTap 截键：不经过热键注册表，完全不可见。
    ///
    /// **常驻注册为什么不用独占**：独占会让别的 App 已有的、以及之后的非独占注册全部静默失效——
    /// 那边的设置页照样显示快捷键，按下去却没反应，正是 7.5.1 要消灭的那种无声失败，只是转嫁给了别人。
    /// 非独占则冲突时两边都响，用户看得见。另外独占不妨碍 Copyo 自己「先注销再注册」的换绑顺序
    /// （实测注销后立刻独占重注册照样成功），不是弃用它的原因。
    ///
    /// 冲突时仍然保留一份非独占注册：对方退出（或用户在系统设置里关掉那条系统快捷键）之后
    /// 不用重启 Copyo 就能恢复。只有 `.failed` 时手里没有注册。
    @discardableResult
    func register(_ config: HotkeyConfig) -> HotkeyStatus {
        installHandlerIfNeeded()
        suspend()
        let hotKeyID = EventHotKeyID(signature: OSType(0x50415354), id: 1) // 'PAST'

        // 独占探测：自己的注册已经在上面注销了，这里报「已存在」只可能是别的进程独占着
        var probeRef: EventHotKeyRef?
        let probe = RegisterEventHotKey(config.keyCode,
                                        config.carbonModifiers,
                                        hotKeyID,
                                        GetApplicationEventTarget(),
                                        OptionBits(kEventHotKeyExclusive),
                                        &probeRef)
        if probe == noErr, let probeRef {
            UnregisterEventHotKey(probeRef)
        }

        let status = RegisterEventHotKey(config.keyCode,
                                         config.carbonModifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        guard status == noErr else {
            hotKeyRef = nil
            return .failed
        }
        // 系统在前：⌘Tab 这类系统快捷键在注册表里也有独占注册，探测同样报「已存在」
        if SystemHotkeys.isEnabled(config) {
            return .takenBySystem
        }
        if probe == OSStatus(eventHotKeyExistsErr) {
            return .takenByApp
        }
        return .active
    }

    /// 暂时注销快捷键，事件处理器留着。录制新组合时用：Copyo 自己的注册同样会在全局截走当前组合，
    /// 不先让开的话，重录一遍当前组合只会把面板弹出来，录制器收不到。之后调用 `register(_:)` 恢复。
    func suspend() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onHotkey?()
            return noErr
        }, 1, &eventType, selfPointer, &eventHandlerRef)
    }

    func unregister() {
        suspend()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        unregister()
    }
}
