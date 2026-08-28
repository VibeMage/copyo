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
        UInt32(kVK_Space): "空格", UInt32(kVK_Return): "↩", UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Escape): "⎋", UInt32(kVK_Delete): "⌫", UInt32(kVK_ForwardDelete): "⌦",
        UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_Home): "↖", UInt32(kVK_End): "↘",
        UInt32(kVK_PageUp): "⇞", UInt32(kVK_PageDown): "⇟",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3", UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6", UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9", UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
    ]

    static func keyName(for keyCode: UInt32) -> String {
        if let special = specialKeyNames[keyCode] { return special }
        return characterName(for: keyCode)?.uppercased() ?? "键码\(keyCode)"
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
        return text.isEmpty ? nil : text
    }
}

/// 通过 Carbon RegisterEventHotKey 注册系统级全局快捷键。
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    var onHotkey: (() -> Void)?

    /// 注册（或换绑）全局快捷键
    func register(_ config: HotkeyConfig) {
        installHandlerIfNeeded()
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        let hotKeyID = EventHotKeyID(signature: OSType(0x50415354), id: 1) // 'PAST'
        RegisterEventHotKey(config.keyCode,
                            config.carbonModifiers,
                            hotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &hotKeyRef)
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
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        unregister()
    }
}
