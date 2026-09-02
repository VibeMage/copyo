import AppKit
import ApplicationServices
import PasterCore

/// 负责把历史条目写回剪贴板，并模拟 ⌘V 粘贴到目标应用。
@MainActor
final class PasteService {
    private let monitor: ClipboardMonitor
    /// 每次启动最多提示一次辅助功能授权问题，避免反复打扰
    private var didWarnAccessibility = false

    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
    }

    /// 仅写回剪贴板，不粘贴
    func copyToPasteboard(_ item: ClipItem, asPlainText: Bool = false) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.kind {
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
        case .file:
            let urls = item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }
            if !urls.isEmpty {
                pb.writeObjects(urls)
            }
        default:
            if let rtf = item.rtfData, !asPlainText {
                pb.setData(rtf, forType: .rtf)
                pb.setString(item.plainText ?? "", forType: .string)
            } else {
                pb.setString(item.plainText ?? "", forType: .string)
            }
        }
        monitor.ignoreNextChange()
    }

    /// 写回剪贴板并粘贴到之前的前台应用
    func paste(_ item: ClipItem, to targetApp: NSRunningApplication?, asPlainText: Bool = false) {
        let defaults = UserDefaults.standard
        let plain = asPlainText || defaults.bool(forKey: "plainTextPaste")
        copyToPasteboard(item, asPlainText: plain)

        guard defaults.bool(forKey: "autoPaste") else { return }
        guard Self.ensureAccessibility() else {
            warnAccessibilityOnce()
            return
        }
        // 目标应用不存在时绝不盲发 ⌘V（否则会落进当前前台窗口）
        guard let targetApp, !targetApp.isTerminated else { return }

        targetApp.activate(options: [])
        // 激活是异步的：确认目标应用真正到了前台再发送 ⌘V，
        // 否则按键会落进 Paster 自己的搜索框或碰巧在前台的其他应用
        Task { @MainActor [weak self] in
            for _ in 0..<20 {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == targetApp.processIdentifier {
                    Self.sendCmdV()
                    if UserDefaults.standard.bool(forKey: "pasteSound") {
                        NSSound(named: "Pop")?.play()
                    }
                    return
                }
                if targetApp.isTerminated { return }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            // 等待约 1 秒仍未激活：放弃发送，内容已在剪贴板中可手动 ⌘V
            _ = self
        }
    }

    /// 授权状态变化后允许重新提示（配合 AppDelegate 里的辅助功能变更通知）
    func resetAccessibilityWarning() {
        didWarnAccessibility = false
    }

    /// 未授权时给出可见反馈。系统的授权弹窗对「已在列表里但因签名变化而失效」的
    /// 情况不会再次出现（TCC 只按条目弹一次），没有这个提示自动粘贴会静默失败。
    private func warnAccessibilityOnce() {
        guard !didWarnAccessibility else { return }
        didWarnAccessibility = true
        let alert = NSAlert()
        alert.messageText = String(localized: "Auto-paste requires Accessibility permission")
        alert.informativeText = String(localized: """
        The content is already on the clipboard, so you can paste it manually with ⌘V.

        Enable Paster in System Settings → Privacy & Security → Accessibility.
        If auto-paste still doesn't work after granting access, restart Paster — macOS sometimes applies the permission only after a relaunch.
        """)
        alert.addButton(withTitle: String(localized: "Open System Settings"))
        alert.addButton(withTitle: String(localized: "Restart Paster"))
        alert.addButton(withTitle: String(localized: "Later"))
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        case .alertSecondButtonReturn:
            Self.relaunch()
        default:
            break
        }
    }

    /// 重启自身：先派生一个延迟 open 的子进程，再退出当前实例
    static func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5; /usr/bin/open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }

    /// 检查辅助功能权限；没有则弹出系统授权提示
    @discardableResult
    static func ensureAccessibility() -> Bool {
#if APPSTORE
        // 沙盒应用调用系统授权弹窗不会真的把自己加进辅助功能列表，
        // 弹一个点了没用的框只会误导用户。这里只回报状态，
        // 由 warnAccessibilityOnce 的「打开系统设置」引导用户手动授权。
        return AXIsProcessTrusted()
#else
        if AXIsProcessTrusted() { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        return false
#endif
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    private static func sendCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyVDown?.flags = .maskCommand
        keyVUp?.flags = .maskCommand
        keyVDown?.post(tap: .cghidEventTap)
        keyVUp?.post(tap: .cghidEventTap)
    }
}
