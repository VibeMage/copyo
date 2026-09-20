import AppKit
import CopyoCore

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

    /// 重启自身：派生一个等本进程真正退出、再 `open` 回来的子进程。
    ///
    /// 返回 false 表示子进程根本没派出去——**这时绝对不能退出**：LSUIElement 应用没有
    /// Dock 图标也没有窗口，菜单栏图标一消失，用户只会以为它崩了。
    /// 成功时本函数不会真的返回（NSApp.terminate 之后进程就走了）。
    static func relaunch(arguments: [String] = []) -> Bool {
        let path = Bundle.main.bundlePath
        let pid = String(ProcessInfo.processInfo.processIdentifier)
        // 路径和参数一律走位置参数，不拼进脚本：安装路径里带 " $ ` 会把命令拆坏。
        //
        // 固定 sleep 猜不准退出耗时：退慢了 open 只会给还活着的实例发一个 reopen 事件
        // （applicationShouldHandleReopen 把面板弹出来），然后应用就没了——面板闪一下，
        // 人不见了。改成按 pid 轮询，并先睡满 0.5s 垫底，保证任何情况下都不比原来短。
        var script = """
        /bin/sleep 0.5
        n=0
        while /bin/kill -0 "$1" 2>/dev/null && [ $n -lt 50 ]; do /bin/sleep 0.1; n=$((n+1)); done
        shift 1
        """
        // shift 只动 $1 起，$0 一直是 bundle 路径；arguments 为空时 "$@" 也是空的
        script += arguments.isEmpty
            ? "\nexec /usr/bin/open \"$0\""
            : "\nexec /usr/bin/open \"$0\" --args \"$@\""

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script, path, pid] + arguments
        do {
            try task.run()
        } catch {
            return false
        }
        NSApp.terminate(nil)
        return true
    }
}
