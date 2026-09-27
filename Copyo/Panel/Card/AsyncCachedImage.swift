import AppKit
import SwiftUI

/// 卡片与预览浮层里所有「要读盘 / 要查 LaunchServices」的图共用的画法（design-spec 7.5.5；
/// 7.5.18 拍板：「`NSWorkspace.icon` 移出 view body，异步 + 缓存」，缩略图与预览大图同一套）：
///
/// - body 里只调 `cached`（只查内存）。命中时第一帧就是真图，不闪占位；
/// - 未命中先把 `nil` 交给 `content` 画占位，同时在 `.task` 里 `await load()`（后台加载，已去重、限流），
///   回来后换成真图。视图离屏时 task 被取消，排队中还没开跑的加载随之撤掉。
///
/// 在屏期间这里还留一份 @State（第一帧就命中缓存的图也留）：NSCache 在内存吃紧时会淘汰，
/// 「清空历史」保留已固定条目时也会整个清掉（`ThumbnailCache.removeAll`），卡片还在屏上就不该因此掉回占位、
/// 再读一遍盘。离屏时放掉：滑出去的卡片 LazyHStack 未必销毁它的 @State，不放的话看过的每张图都常驻内存，
/// 缓存的上限就形同虚设。结果按 `key` 认领——同一视图身份换了请求（预览浮层换条目）时，
/// 上一条的图不会被带到下一条上。
///
/// `content` 在拿到 nil 时也必须画出一个真实存在的视图（占位、`Color.clear`），不能是空的 `if`：
/// 内容为空时挂在它上面的 `.task` 不会触发，图就永远不来了。
struct AsyncCachedImage<Content: View>: View {
    private let key: String
    private let cached: @MainActor () -> NSImage?
    private let load: @MainActor () async -> NSImage?
    private let retryToken: @MainActor () -> Int
    private let content: (NSImage?) -> Content

    @State private var loaded: Loaded?

    /// - Parameters:
    ///   - key: 请求的身份，变了就重新取
    ///   - retryToken: 画占位期间读的一个计数；它一变就重新发起加载（CloudKit 的行先到、图片资源后到）
    init(key: String,
         cached: @escaping @MainActor () -> NSImage?,
         load: @escaping @MainActor () async -> NSImage?,
         retryToken: @escaping @MainActor () -> Int = { 0 },
         @ViewBuilder content: @escaping (NSImage?) -> Content) {
        self.key = key
        self.cached = cached
        self.load = load
        self.retryToken = retryToken
        self.content = content
    }

    private struct Loaded {
        let key: String
        let image: NSImage
    }

    private struct TaskID: Equatable {
        let key: String
        /// 有图时恒为 -1：已经画着真图的视图不去读重试计数，也就不会被它惊动
        let retry: Int
    }

    var body: some View {
        let image = cached() ?? loaded.flatMap { $0.key == key ? $0.image : nil }
        content(image)
            .task(id: TaskID(key: key, retry: image == nil ? retryToken() : -1)) {
                let key = key
                if let image {
                    // 命中缓存的也记一份。body 仍是 cached() 优先：图标从通用替身换成真图标照样即时生效
                    if loaded?.key != key || loaded?.image !== image { loaded = Loaded(key: key, image: image) }
                    return
                }
                guard let result = await load(), !Task.isCancelled else { return }
                loaded = Loaded(key: key, image: result)
            }
            .onDisappear { loaded = nil }
    }
}
