import AppKit
import CopyoCore
import ImageIO
import Observation
import SwiftData

/// 图片条目的卡片缩略图与预览大图缓存（design-spec 7.5.5、第八节第 2 条）。
///
/// view body 里只许调 `cached…` 这一组**只查内存**的接口。未命中时先画 7.5.5 的占位（来源淡染底 + 居中 `photo`），
/// 同时在 `.task` 里 `await thumbnail(for:)` / `preview(for:)`：读 externalStorage 与解码都在后台线程上做，
/// 完成后再换成真图；缓存命中时第一帧就是真图。
///
/// `ClipItem` 是 @Model、不是 Sendable，不能带出主线程。请求在主线程上先拆成 `Request`
/// （持久化 ID + ModelContainer + 缓存键，全是 Sendable），后台用自己新建的 `ModelContext` 按 ID 取行、读 imageData，
/// 与主线程的 mainContext 互不相干。解出来的 CGImage 是 Sendable，回到主线程再包成 NSImage 进缓存。
@MainActor
enum ThumbnailCache {
    /// 一次加载要的全部信息，只含能跨线程的值
    struct Request: Sendable {
        let key: String
        let id: PersistentIdentifier
        let imageHash: String?
        let container: ModelContainer

        /// 条目已经不在任何 context 里（刚删掉）时拿不到容器，也就没什么可加载的
        @MainActor
        init?(_ item: ClipItem) {
            guard let container = item.modelContext?.container else { return nil }
            key = ThumbnailCache.key(for: item)
            id = item.persistentModelID
            imageHash = item.imageHash
            self.container = container
        }
    }

    /// 后台的产出
    private struct Decoded: Sendable {
        enum Status: Sendable {
            case ok
            /// 行找不到，或 imageData 还是 nil（CloudKit 的图片资源还没下完）：数据可能晚到，允许重试
            case missing
            /// 数据在、但解不出来：不再重试，一直画占位
            case failed
        }

        var status: Status
        var image: CGImage?
        var pixelSize: CGSize?
    }

    /// 卡片渲染尺寸 224pt 宽，448px 足够覆盖 2x Retina
    private static let thumbnailPixelSize: CGFloat = 448
    /// 预览浮层宽 720、最高 480（第八节第 2 条），2x 屏上长边 1440 像素就够；原图更小时不会放大
    private static let previewPixelSize = max(CopyoTheme.Dense.previewWidth, CopyoTheme.Dense.previewMaxHeight) * 2

    private static let thumbnails: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 300
        return cache
    }()
    /// 预览大图一张就是几 MB，只留当前与刚看过的几张（预览开着时左右换卡，像 Quick Look）
    private static let previews: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 4
        return cache
    }()
    /// 解码时顺带读出的图片头像素尺寸：预览浮层按它定窗口高度、在信息行写「宽 × 高」。
    /// 缩略图还没解过、预览又已经打开时，由 `pixelSize(for:)` 单读一次图片头补上
    private static var pixelSizes: [String: CGSize] = [:]
    private static var failedKeys: Set<String> = []
    private static var missingKeys: Set<String> = []
    private static var remoteChangeObserver: NSObjectProtocol?
    /// 远端变更（CloudKit 导入）的序号，每来一条加一。加载在发起时记下它；回来是缺图、序号又已经前进，
    /// 说明「后台读到 nil」与「数据到了」可能擦肩而过（通知先到、key 后进 missingKeys），不等下一条通知，当场放行重试
    private static var remoteChangeSeq = 0

    /// 代际计数：每次 `removeAll` 加一。清空之前发起的加载回来时代际对不上，结果不写回缓存（缺图的登记除外，见 `commit`）
    private static var generation = 0

    private static let thumbnailLoads = BackgroundLoadQueue<String, Decoded>(maxConcurrent: 3)
    private static let previewLoads = BackgroundLoadQueue<String, Decoded>(maxConcurrent: 2)
    private static let sizeLoads = BackgroundLoadQueue<String, CGSize?>(maxConcurrent: 2)

    static func key(for item: ClipItem) -> String {
        item.imageHash ?? String(describing: item.persistentModelID)
    }

    // MARK: - 只查内存（body 里用这一组）

    static func cachedThumbnail(forKey key: String) -> NSImage? {
        thumbnails.object(forKey: key as NSString)
    }

    static func cachedPreview(forKey key: String) -> NSImage? {
        previews.object(forKey: key as NSString)
    }

    /// 图片的像素尺寸。缩略图或大图在后台解过一次、或 `pixelSize(for:)` 读过图片头之后才有；还没有时返回 nil
    static func cachedPixelSize(for item: ClipItem) -> CGSize? {
        pixelSizes[key(for: item)]
    }

    static func cachedPixelSize(forKey key: String) -> CGSize? {
        pixelSizes[key]
    }

    /// 占位中的视图在 body 里读它。CloudKit 的行先到、图片资源后到时，远端变更一来它就变，
    /// 读过它的视图随之重算、重新发起加载（见 `noteMissing`）
    static var retryToken: Int { CacheSignals.shared.retry }

    /// 预览大图还没到时顶上的卡片缩略图（见 `PreviewContentView.imageContent`）。只查内存；
    /// 没有时顺带读一下「缩略图落地」计数：NSCache 的读取本身不会让视图重算，
    /// 读了它，缩略图后到时正在画占位的预览就会自己换上
    static func previewStandIn(forKey key: String) -> NSImage? {
        if let image = cachedThumbnail(forKey: key) { return image }
        _ = CacheSignals.shared.thumbnailsLanded
        return nil
    }

    // MARK: - 后台加载

    /// 卡片缩略图。同一 key 的并发请求只读一次盘、解一次码；调用方被取消时返回 nil
    static func thumbnail(for request: Request) async -> NSImage? {
        if let cached = cachedThumbnail(forKey: request.key) { return cached }
        guard !failedKeys.contains(request.key) else { return nil }
        observeRemoteChanges()
        let generation = self.generation
        let seq = remoteChangeSeq
        let pixelSize = thumbnailPixelSize
        let decoded = await thumbnailLoads.load(request.key) {
            decode(request, maxPixelSize: pixelSize)
        } commit: { decoded in
            commit(decoded, key: request.key, generation: generation, seq: seq, into: thumbnails)
        }
        return cachedThumbnail(forKey: request.key) ?? decoded?.image.map { NSImage(cgImage: $0, size: .zero) }
    }

    /// 预览浮层的大图，长边最多 `previewPixelSize`
    static func preview(for request: Request) async -> NSImage? {
        if let cached = cachedPreview(forKey: request.key) { return cached }
        guard !failedKeys.contains(request.key) else { return nil }
        observeRemoteChanges()
        let generation = self.generation
        let seq = remoteChangeSeq
        let pixelSize = previewPixelSize
        let decoded = await previewLoads.load(request.key) {
            decode(request, maxPixelSize: pixelSize)
        } commit: { decoded in
            commit(decoded, key: request.key, generation: generation, seq: seq, into: previews)
        }
        return cachedPreview(forKey: request.key) ?? decoded?.image.map { NSImage(cgImage: $0, size: .zero) }
    }

    /// 图片的像素尺寸，只读图片头、不等整张解码。预览浮层定窗口高度用：尺寸还不在内存里时，
    /// 等大图整张解完再重排要上百毫秒（5K 截图约 200ms），读图片头只要一两毫秒。
    /// 代价是这张图的 imageData 要多读一次——只在缩略图还没解过、预览又已经打开时才走到这里
    static func pixelSize(for request: Request) async -> CGSize? {
        if let size = pixelSizes[request.key] { return size }
        guard !failedKeys.contains(request.key) else { return nil }
        let generation = self.generation
        let loaded = await sizeLoads.load(request.key) {
            readPixelSize(request)
        } commit: { size in
            guard generation == self.generation, let size else { return }
            pixelSizes[request.key] = size
        }
        return pixelSizes[request.key] ?? loaded.flatMap { $0 }
    }

    /// 预热用：结果留在缓存里，调用方不要图
    static func warm(_ request: Request) async {
        _ = await thumbnail(for: request)
    }

    /// 清空历史、删除所有数据之后调用。条目删了，图就不该还留在内存里；键是 imageHash，
    /// 不清的话相同字节的新条目会命中旧图。清空之前就在途的加载由代际计数挡住，不会把旧图写回来
    static func removeAll() {
        generation &+= 1
        thumbnails.removeAllObjects()
        previews.removeAllObjects()
        pixelSizes.removeAll()
        failedKeys.removeAll()
        missingKeys.removeAll()
        thumbnailLoads.detachAll()
        previewLoads.detachAll()
        sizeLoads.detachAll()
    }

    /// 代际是请求发起时记下的，所以清空时还在排队、清空之后才开跑的那些同样算旧的：图不写回缓存，只交给请求方。
    /// 缺图例外——它只是登记一次重试，不往缓存里写任何东西。清空历史时保留下来的已固定图片卡可能正缺着图，
    /// 挡掉的话 missingKeys 里没有它（`removeAll` 刚清过），CloudKit 资源到了也等不到重试唤醒；不挡最坏只是多放行一次重试
    private static func commit(_ decoded: Decoded, key: String, generation: Int, seq: Int,
                               into cache: NSCache<NSString, NSImage>) {
        if decoded.status == .missing {
            noteMissing(key, seq: seq)
            return
        }
        guard generation == self.generation else { return }
        if let size = decoded.pixelSize { pixelSizes[key] = size }
        switch decoded.status {
        case .ok:
            if let image = decoded.image {
                cache.setObject(NSImage(cgImage: image, size: .zero), forKey: key as NSString)
                if cache === thumbnails { CacheSignals.shared.thumbnailsLanded &+= 1 }
            }
        case .missing:
            break
        case .failed:
            failedKeys.insert(key)
        }
    }

    /// 数据还没到的 key 记下来，等远端变更（CloudKit 导入）来了统一放行重试；只在有缺图的时候才打扰视图。
    /// 加载发起之后已经来过远端变更的，数据可能恰好在「后台读到 nil」之后、这次收尾之前到的——
    /// 那条通知来时这个 key 还不在 missingKeys 里，放不了行，所以这里直接放行，不等下一条
    private static func noteMissing(_ key: String, seq: Int) {
        if seq != remoteChangeSeq {
            CacheSignals.shared.retry &+= 1
        } else {
            missingKeys.insert(key)
        }
    }

    /// 第一次加载时就挂上远端变更的观察者，而不是等到第一次缺图：序号要从加载发起那一刻起就在数
    private static func observeRemoteChanges() {
        guard remoteChangeObserver == nil else { return }
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("NSPersistentStoreRemoteChangeNotification"),
            object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                remoteChangeSeq &+= 1
                guard !missingKeys.isEmpty else { return }
                missingKeys.removeAll()
                CacheSignals.shared.retry &+= 1
            }
        }
    }

    // MARK: - 后台线程上跑的部分

    nonisolated private static func decode(_ request: Request, maxPixelSize: CGFloat) -> Decoded {
        guard let data = imageData(for: request) else { return Decoded(status: .missing) }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return Decoded(status: .failed) }
        let pixelSize = headerPixelSize(of: source)
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary) else {
            return Decoded(status: .failed, pixelSize: pixelSize)
        }
        return Decoded(status: .ok, image: image, pixelSize: pixelSize)
    }

    /// 只读图片头拿像素尺寸（`pixelSize(for:)`）。缺图、坏图都返回 nil：缺图的重试与坏图的记账归缩略图 / 大图那两趟
    nonisolated private static func readPixelSize(_ request: Request) -> CGSize? {
        guard let data = imageData(for: request),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return headerPixelSize(of: source)
    }

    /// 只读图片头，不解码整张图
    nonisolated private static func headerPixelSize(of source: CGImageSource) -> CGSize? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: width, height: height)
    }

    /// 用后台自己的 ModelContext 按持久化 ID 取行、读 externalStorage。context 在这条线程上建、在这条线程上用完就丢，
    /// 不跨线程（ModelContext 不是 Sendable）；它和 mainContext 共用同一个容器，读到的是已经落盘的数据——
    /// 采集、同步导入、演示数据都是插入后当场 save 的。
    nonisolated private static func imageData(for request: Request) -> Data? {
        let context = ModelContext(request.container)
        let id = request.id
        var byID = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.persistentModelID == id })
        byID.fetchLimit = 1
        if let item = try? context.fetch(byID).first {
            return item.imageData
        }
        // 按 ID 找不到：多半是还没 save 的临时 ID（save 之后 persistentModelID 会换成永久的，卡片随之重建），
        // 或者行已经删了。有内容哈希就再找一条同内容的行，找到就是同一张图
        guard let hash = request.imageHash else { return nil }
        let wanted: String? = hash
        var byHash = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.imageHash == wanted })
        byHash.fetchLimit = 1
        return (try? context.fetch(byHash).first)?.imageData
    }
}

/// 缓存状态变化的信号。@Observable 按属性追踪：只有在 body 里读过某个计数的视图才会被它惊动
@MainActor
@Observable
private final class CacheSignals {
    static let shared = CacheSignals()
    /// 「缺图的数据可能到了」。读它的是正在画占位的那几张卡片与预览
    var retry = 0
    /// 「又有缩略图进了缓存」。读它的只有大图、缩略图都还没有的那一个预览浮层（`previewStandIn`）
    var thumbnailsLanded = 0
}
