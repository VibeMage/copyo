import AppKit
import ApplicationServices

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

    /// 未授权时给出可见反馈。系统的授权弹窗对「已在列表里但因签名变化而失效」的
    /// 情况不会再次出现（TCC 只按条目弹一次），没有这个提示自动粘贴会静默失败。
    private func warnAccessibilityOnce() {
        guard !didWarnAccessibility else { return }
        didWarnAccessibility = true
        let alert = NSAlert()
        alert.messageText = "自动粘贴需要「辅助功能」权限"
        alert.informativeText = """
        内容已复制到剪贴板，当前可手动 ⌘V 粘贴。

        请在 系统设置 → 隐私与安全性 → 辅助功能 中勾选 Paster。
        如果之前授权过但更新应用后失效，需要先把 Paster 从列表中移除再重新添加。
        """
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "以后再说")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }

    /// 检查辅助功能权限；没有则弹出系统授权提示
    @discardableResult
    static func ensureAccessibility() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        return false
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
