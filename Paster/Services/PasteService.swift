import AppKit
import PasterCore

/// 负责把历史条目写回剪贴板。选中条目后面板收起并把焦点还给之前的应用，由用户按 ⌘V 粘贴。
@MainActor
final class PasteService {
    private let monitor: ClipboardMonitor

    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
    }

    /// 写回剪贴板。`asPlainText`（⌥↩）或「始终以纯文本复制」开启时去掉格式。
    func copyToPasteboard(_ item: ClipItem, asPlainText: Bool = false) {
        let plain = asPlainText || UserDefaults.standard.bool(forKey: "plainTextPaste")
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
            if let rtf = item.rtfData, !plain {
                pb.setData(rtf, forType: .rtf)
                pb.setString(item.plainText ?? "", forType: .string)
            } else {
                pb.setString(item.plainText ?? "", forType: .string)
            }
        }
        monitor.ignoreNextChange()
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
}
