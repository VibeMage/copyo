#if DEBUG
import AppKit

/// 截图辅助（仅 Debug 构建）：`-snapshotDir <目录>` 在启动 2 秒后把每个可见窗口的内容渲染成 PNG
/// 写进该目录，然后退出。
///
/// 用 `cacheDisplay` 直接渲染视图层级，不走 screencapture：不需要「屏幕录制」权限，也不用从整屏截图里裁。
/// 注意毛玻璃是窗口服务器在窗口背后合成的，渲染不出来——拍面板时配合 `-opaquePanel`。
/// 典型用法：`Copyo -demoData -opaquePanel -showPanel -snapshotDir /tmp/shots`
enum DebugSnapshot {
    static func runIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-snapshotDir"), args.indices.contains(index + 1) else { return }
        let directory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (number, window) in NSApp.windows.enumerated() where window.isVisible {
                guard let view = window.contentView, view.bounds.width > 0 else { continue }
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                view.cacheDisplay(in: view.bounds, to: rep)
                let name = "\(number)-\(String(describing: type(of: window)))-\(Int(view.bounds.width))x\(Int(view.bounds.height)).png"
                try? rep.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent(name))
            }
            exit(0)
        }
    }
}
#endif
