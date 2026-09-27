import AppKit
import Carbon.HIToolbox

/// 系统快捷键（系统设置 › 键盘 › 键盘快捷键）的冲突比对（design-spec 7.5.1）。
///
/// 多数系统快捷键不走 Carbon 的热键注册表，`RegisterEventHotKey` 连独占探测都照样成功（⌘Space 实测）；
/// 少数（⌘Tab、⇧⌘Tab、⌥⌘Esc）在注册表里有独占注册，探测会报「已存在」，但那也是系统，不是别的 App。
/// 所以要拿 `CopySymbolicHotKeys()` 的列表来比，而且比对结果优先于独占探测（见 `HotkeyManager.register`）。
/// 实测（2026-09-27）：它在沙盒里照样可用，列出的启用状态与系统设置一致（维护者关掉的 ⇧⌘3/4/5
/// 显示为未启用）；一次约 13ms，别放进热路径。
/// 它只含系统级的那部分，不含「App 快捷键」与「服务」——那两类是前台 App 自己的菜单键位，不在全局截键。
enum SystemHotkeys {
    /// `config` 是否与一条**已启用**的系统快捷键相同。
    ///
    /// `globeHeld`：按下时是否按着 🌐（fn）。只有录制时被截走的那一下才知道（`SwallowedComboWatcher`）；
    /// Copyo 存下的组合永远不含 🌐（录制器和 `HotkeyConfig` 都不记它），注册时按不含算。
    static func isEnabled(_ config: HotkeyConfig, globeHeld: Bool = false) -> Bool {
        var array: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&array) == noErr,
              let entries = array?.takeRetainedValue() as? [[String: Any]] else {
            return false
        }
        // 列表里的修饰键是 Carbon 形式：⌘⇧⌥⌃ 四位逐位比；未分配的条目 keyCode 为 65535，天然不会命中
        let mask = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        let fnBit = UInt32(kEventKeyModifierFnMask)
        let intrinsicFn = carriesFn(config.keyCode)
        return entries.contains { entry in
            guard (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true,
                  let code = (entry[kHISymbolicHotKeyCode as String] as? NSNumber)?.uint32Value,
                  let modifiers = (entry[kHISymbolicHotKeyModifiers as String] as? NSNumber)?.uint32Value,
                  code == config.keyCode,
                  modifiers & mask == config.carbonModifiers & mask else {
                return false
            }
            // fn 位要分键看。功能键、方向键这类键的事件天生带 fn，列表里它们的条目也都带（⌃F2、⌃← 都是 0x21000），
            // 不能当修饰键比。其余键（字母、标点……）的条目带 fn 就是要按住 🌐：列表里有只带 fn 的 🌐Q、🌐H、🌐F，
            // macOS 15 起的窗口平铺是 🌐⌃F / 🌐⌃C / 🌐⌃R，另有 🌐⌘\ 🌐⇧⌘\ 🌐⌥\（2026-09-27 本机 dump 核对，
            // copyo-54r）。不按 🌐 时系统不拦这些组合，⌃F 不能算被系统占用。
            return intrinsicFn || ((modifiers & fnBit) != 0) == globeHeld
        }
    }

    /// 事件天生带 fn 位的键：NSEvent 给它们置 `.function` 的那些——F1–F20、方向键、Help、⌦、
    /// Home / End / PageUp / PageDown；外加 127 以上的专用键（调度中心 160、启动台 131、亮度 144/145 等），
    /// 列表里这些键不带修饰键的条目也带 fn（直接按调度中心键显然不用按 🌐）。
    ///
    /// 方向键有个分不清的地方：🌐 条目（🌐⌥←、平铺的 🌐⌃⌥⇧← 等）和不按 🌐 的条目（⌃← 切换空间、⌃↑ 调度中心）
    /// 在列表里是同一个样子——方向键的事件本来就带 fn。这里一律按命中算：宁可把 ⌥← 这种本来就不该拿来当
    /// 全局快捷键（会吃掉所有文本框的「按词移动」）的组合拒掉，也不能漏掉 ⌃← ⌃↑ 这些常用的系统组合。
    static func carriesFn(_ keyCode: UInt32) -> Bool {
        keyCode > 127 || functionKeys.contains(keyCode)
    }

    private static let functionKeys: Set<UInt32> = Set([
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow,
        kVK_Help, kVK_ForwardDelete, kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown,
    ].map { UInt32($0) })
}

/// 录制时找出「按下去却没送到录制器」的组合（design-spec 7.5.1）。
///
/// 别的 App 用 Carbon 注册了的组合（独占与否都一样）和系统快捷键，按下时由窗口服务器直接分发给占用方，
/// 前台 App 收不到 keyDown，本地事件监视器也就看不见——录制器「按了没反应」，对方的动作却已经触发了。
/// 这是发现**非独占**占用的唯一途径：注册 API 查不到它（见 `HotkeyManager.register`）。
///
/// 做法：录制期间每 20ms 用 `CGEventSource.keyState(.hidSystemState, key:)` 扫一遍按键状态；
/// 某个键在按着 ⌘/⌥/⌃ 时按下，250ms 内录制器却没收到它的 keyDown，就判定它被截走了。
/// 实测（2026-09-27）：沙盒 App 在输入监控、辅助功能都未授权时照样读得到，被热键吃掉的按键也读得到；
/// 扫一遍 118 个键约 0.2ms。将来系统若把它也收进输入监控权限，它会恒为 false，这里退化成什么也不报，不会误报。
/// 只在 Copyo 是前台 App 时录制与判定：不在前台时按键本来就送不到录制器，不能算截走。
/// 录制窗口失去焦点时（⌘Tab、对方的动作把自己的窗口调到了前面）调用方用 `reportPending()` 把还在等的键立即报出来，
/// 不必等满余量。采样时发现 Copyo 已经不在前台、调用方却没因失焦通知收尾，就由这里兜底结束（见 `poll`）。
///
/// 改善不了的：对方的动作照样会被触发，这里只能事后告诉用户。录制时先把别人的快捷键停掉要靠
/// `PushSymbolicHotKeyMode(kHIHotKeyModeAllDisabled)`，它要求辅助功能权限——未授权时照样返回 token、
/// `GetSymbolicHotKeyMode()` 也报已切换，实际不生效（已实测）。Copyo 不为这个去申请辅助功能权限。
@MainActor
final class SwallowedComboWatcher {
    private static let pollInterval: TimeInterval = 0.02
    /// 没被截走的按键，keyDown 通常几毫秒就到；主线程偶尔卡一下也在这个余量里
    private static let grace: TimeInterval = 0.25
    /// 除修饰键（54–63：左右 ⌘ ⇧ ⌥ ⌃、大写锁定、fn）以外的全部虚拟键码
    private static let candidateKeys: [CGKeyCode] = (0..<128).map { CGKeyCode($0) }.filter { !(54...63).contains($0) }

    /// `globeHeld`：按下时按着 🌐。只对字母、标点这类键有意义，功能键、方向键天生带的 fn 位已经滤掉
    /// （见 `SystemHotkeys.carriesFn`）
    private let onSwallowed: (_ combo: HotkeyConfig, _ globeHeld: Bool) -> Void
    /// 采样时发现 Copyo 已经不在前台，又没有在前台时记下的待报键：调用方放弃录制
    private let onFocusLost: () -> Void
    private var timer: Timer?
    /// 暂不判定的键，松开后解除：录制开始时就按着的、按下时没带 ⌘/⌥/⌃ 的
    private var ignored: Set<CGKeyCode> = []
    /// 录制器已经收到 keyDown 的键，松开后解除
    private var delivered: Set<CGKeyCode> = []
    /// 看见按下、还在等 keyDown 的键：何时看见、当时按着哪些修饰键、是否按着 🌐
    private var pending: [CGKeyCode: (since: TimeInterval, modifiers: NSEvent.ModifierFlags, globe: Bool)] = [:]

    init(onSwallowed: @escaping (_ combo: HotkeyConfig, _ globeHeld: Bool) -> Void,
         onFocusLost: @escaping () -> Void) {
        self.onSwallowed = onSwallowed
        self.onFocusLost = onFocusLost
    }

    func start() {
        stop()
        ignored = Set(Self.candidateKeys.filter(Self.isDown))
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        ignored.removeAll()
        delivered.removeAll()
        pending.removeAll()
    }

    /// 录制器的本地监视器收到了这个键的 keyDown：它没被截走
    func noteDelivered(keyCode: UInt16) {
        let key = CGKeyCode(keyCode)
        pending[key] = nil
        delivered.insert(key)
    }

    /// 录制窗口失去焦点时调用：还在等 keyDown 的键不会再送到录制器了，把最早的那个立即当作被截走报出来。
    /// 返回是否报了（报了就会走 `onSwallowed`，调用方不用再自己收尾）。
    ///
    /// 报之前先同步再扫一遍。一按热键就把自己激活的 App（Raycast、Alfred 这类启动器）是最常见的冲突来源：
    /// 失焦通知可能比下一次采样先到（落在 20ms 的采样间隔里），那个键还没记进 pending，不补这一扫就会被当成
    /// 「用户走开了」静默放弃。这一扫算作失焦前一刻：此刻 ⌘/⌥/⌃ 仍按着、按着的键又没送到录制器，就是它把焦点拿走的
    func reportPending() -> Bool {
        scan(now: ProcessInfo.processInfo.systemUptime)
        return reportEarliestPending()
    }

    private func reportEarliestPending() -> Bool {
        guard let first = pending.min(by: { $0.value.since < $1.value.since }) else { return false }
        report(first.key, first.value)
        return true
    }

    private func poll() {
        // 不在前台就不该还在录制。正常情况下失焦通知早已让调用方收了尾；
        // 走到这里多半是录制在 Copyo 不在前台时就开始了（调用方会拦，这里兜底），那样等不到失焦通知——
        // 不能让让出的全局快捷键一直空着、这里一直在后台扫。此刻按着的键可能是用户在别的 App 里敲的，
        // 不补扫，只报在前台时就记下的
        guard NSApp.isActive else {
            if !reportEarliestPending() { onFocusLost() }
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        scan(now: now)
        // 已经松开的键也等满余量：它的 keyDown 可能还排在事件队列里
        guard let overdue = pending.first(where: { now - $0.value.since >= Self.grace }) else { return }
        report(overdue.key, overdue.value)
    }

    /// 扫一遍按键状态：新按下、按着 ⌘/⌥/⌃、又还没送到录制器的键记进 pending
    private func scan(now: TimeInterval) {
        // 修饰键也从 HID 层读，与 keyState 同一来源；CGEventFlags 与 NSEvent.ModifierFlags 的这几位相同。
        // 🌐 也从这里读（maskSecondaryFn）。功能键、方向键的事件本身就带这一位，按着它们时这里也可能亮着，
        // 那种由 report 按键滤掉
        let flags = CGEventSource.flagsState(.hidSystemState)
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(flags.rawValue))
            .intersection([.command, .option, .control, .shift])
        let globe = flags.contains(.maskSecondaryFn)
        let judging = !modifiers.isDisjoint(with: [.command, .option, .control])
        for key in Self.candidateKeys {
            guard Self.isDown(key) else {
                ignored.remove(key)
                delivered.remove(key)
                continue
            }
            guard !ignored.contains(key), !delivered.contains(key), pending[key] == nil else { continue }
            if judging {
                pending[key] = (now, modifiers, globe)
            } else {
                ignored.insert(key)
            }
        }
    }

    /// 回调放在最后：调用方多半会在回调里 stop() 掉本对象
    private func report(_ key: CGKeyCode, _ entry: (since: TimeInterval, modifiers: NSEvent.ModifierFlags, globe: Bool)) {
        pending[key] = nil
        let combo = HotkeyConfig(keyCode: UInt32(key), carbonModifiers: HotkeyConfig.carbonFlags(from: entry.modifiers))
        onSwallowed(combo, entry.globe && !SystemHotkeys.carriesFn(combo.keyCode))
    }

    private static func isDown(_ key: CGKeyCode) -> Bool {
        CGEventSource.keyState(.hidSystemState, key: key)
    }
}
