import AppKit
import CopyoCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 卡片拖出（design-spec §4.5.2「本轮要补齐多表示」、§4.5.3）。
///
/// v1 每种类型只注册一种表示，多文件卡也只交出第一个文件。这里按 kind 注册多种表示，顺序即优先级：
///
/// | kind | 表示 |
/// | --- | --- |
/// | `.text` | `public.utf8-plain-text` |
/// | `.richText` | `public.rtf` → `public.utf8-plain-text` |
/// | `.link` | `public.url` → `public.utf8-plain-text` |
/// | `.color` | `com.apple.cocoa.pasteboard.color`（`NSColor`）→ `public.utf8-plain-text`（色值字符串） |
/// | `.image` | 原始图片 UTI（库里按约定是 PNG）；缺图时一种都不登记 |
/// | `.file` | `public.file-url` × N，字节可读时再附文件字节 |
///
/// 纯文本与复制路径（`PasteService.copyToPasteboard`）写的是同一个值 `plainText ?? ""`。
/// 图片的「可选纯文本（文件名或空）」不注册：图片条目没有文件名，空串只会让文本框接下一次什么也没插进去的拖放。
///
/// RTF 与图片存在 externalStorage 里，拖起时一律不读：只登记表示，接收方真来要时才在后台读（见 `StoredBytes`）。
/// 那时再读不到，接收方拿到的是 0 字节而不是错误（见 `registerLazy`），所以图片在拖起时先按内存里的缓存判断缺不缺图。
/// 另注：SwiftUI 把 `NSItemProvider` 桥接到拖拽粘贴板时，只要有 RTF、颜色、PNG、文件字节这类非纯文本的数据表示，
/// 就会在同一项上另附一份文件承诺（NSFilePromise），接收方可以把它落成一个文件。这是 `.onDrag` 自己的行为，
/// v1 的文件拖拽（`NSItemProvider(contentsOf:)`）同样带着它，这里控制不了；
/// 文件卡给了建议名，落地的文件名才与原文件一致（见 `registerFile`）。
struct ClipDragSource: ViewModifier {
    let item: ClipItem

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            if item.kind == .file, item.filePaths.count > 1 {
                multiFileSource(content)
            } else {
                content.onDrag { ClipDrag.itemProvider(for: item) }
            }
        } else {
            content.onDrag { ClipDrag.itemProvider(for: item) }
        }
    }

    /// 多文件卡：`public.file-url` × N 要 N 个拖拽项，而 `.onDrag` 只能交出一个 `NSItemProvider`（= 一项）。
    /// macOS 26 起 SwiftUI 的拖拽容器可以让一张卡交出一组 Transferable，每个文件各成一项；
    /// 容器与可拖项挂在同一张卡上，不必改动卡片轨道本身。更早的系统只能退回 `.onDrag`，仍只交第一个文件
    @available(macOS 26, *)
    private func multiFileSource(_ content: Content) -> some View {
        let cardID = item.persistentModelID
        let paths = item.filePaths
        return content
            .draggable(containerItemID: cardID)
            .dragContainer(for: ClipFileDragItem.self, itemID: \.cardID) { (_: PersistentIdentifier) -> [ClipFileDragItem] in
                // 可读性在拖起这一刻判定（§4.5.3），不在 body 里做：文件可能在面板开着的时候被删、被移走
                paths.map { ClipFileDragItem(cardID: cardID, path: $0) }
            }
    }
}

@MainActor
enum ClipDrag {
    /// 单个拖拽项的全部表示。多文件卡在 macOS 26 之前也走这里，只交第一个文件（见 `ClipDragSource`）
    static func itemProvider(for item: ClipItem) -> NSItemProvider {
        let provider = NSItemProvider()
        switch item.kind {
        case .text:
            registerPlainText(of: item, on: provider)
        case .richText:
            if let stored = StoredBytes(item) {
                registerLazy(.rtf, on: provider) { stored.read(.rtf) }
            }
            registerPlainText(of: item, on: provider)
        case .link:
            if let url = item.linkURL {
                provider.registerObject(url as NSURL, visibility: .all)
            }
            registerPlainText(of: item, on: provider)
        case .color:
            // 解析失败的颜色条目按普通文本卡画（第八节第 31 条），这里同样只剩纯文本
            if let color = CopyoTheme.uiColor(hexString: item.plainText),
               let archived = color.pasteboardPropertyList(forType: .color) as? Data {
                provider.registerDataRepresentation(forTypeIdentifier: NSPasteboard.PasteboardType.color.rawValue,
                                                    visibility: .all) { completion in
                    completion(archived, nil)
                    return nil
                }
            }
            registerPlainText(of: item, on: provider)
        case .image:
            // 缺图（CloudKit 的图片资源还没下完、行已删除）时不登记 PNG，与 v1 缺图时拖不出东西一致：
            // 登记了，接收方就会接下这次拖放，落地却是 0 字节（见 `registerLazy`）。拖起这一刻在主线程上不读盘，
            // 只查 ThumbnailCache 的内存：缩略图 / 大图解出过、或读过图片头，才算确实读到过字节；
            // 卡片还画着 `photo` 占位（7.5.5）、这些都还没有的，当缺图——刚唤出面板、缩略图还没回来就拖的，同样拖不出东西
            if ThumbnailCache.cachedThumbnail(forKey: ThumbnailCache.key(for: item)) != nil
                || ThumbnailCache.cachedPixelSize(for: item) != nil,
               let stored = StoredBytes(item) {
                registerLazy(.png, on: provider) { stored.read(.image).flatMap(pngData) }
            }
        case .file:
            if let path = item.filePaths.first {
                registerFile(at: path, on: provider)
            }
        }
        return provider
    }

    private static func registerPlainText(of item: ClipItem, on provider: NSItemProvider) {
        provider.registerObject((item.plainText ?? "") as NSString, visibility: .all)
    }

    /// 接收方来要这份表示时才读：在后台线程上读，读完直接在那条线程上交付。
    /// 不能跳回主线程——粘贴板向拖拽源要数据是同步的，这时主线程就在等这份数据（读多久，主线程就卡多久）。
    ///
    /// 读不到时交的错误到不了接收方：SwiftUI 把 `NSItemProvider` 桥接到拖拽粘贴板时，会把失败换成一份 0 字节的数据交出去
    /// （macOS 27 实测）。接收方已经接下了这次拖放，落地却是空的。所以「会不会读不到」要在拖起时尽量先判断掉：
    /// 图片见 `itemProvider` 的 `.image` 分支；RTF 读不到时，文本类接收方会退回同一项上的纯文本，影响小，维持现状
    private static func registerLazy(_ type: UTType, on provider: NSItemProvider,
                                     read: @escaping @Sendable () -> Data?) {
        provider.registerDataRepresentation(for: type, visibility: .all) { completion in
            DispatchQueue.global(qos: .userInitiated).async {
                // 读不到（行已删除、CloudKit 的资源还没下完）照样报错；接收方最终拿到的是 0 字节，见上
                if let data = read() {
                    completion(data, nil)
                } else {
                    completion(nil, CocoaError(.fileReadUnknown))
                }
            }
            return nil
        }
    }

    /// 一个文件：先登记 file-url，字节可读时再附字节（§4.5.2 表 `.file` 行）
    private static func registerFile(at path: String, on provider: NSItemProvider) {
        let url = URL(fileURLWithPath: path)
        provider.registerObject(url as NSURL, visibility: .all)
        guard let type = byteType(ofFileAt: path) else { return }
        // SwiftUI 会为字节另附一份文件承诺，没有建议名时按类型描述起名（「PNG image.png」）；
        // 给出不带扩展名的原名，落地的文件名与原文件一致
        provider.suggestedName = url.deletingPathExtension().lastPathComponent
        // 文件表示是惰性的：接收方真来要字节时才读文件，拖起时不碰磁盘
        provider.registerFileRepresentation(forTypeIdentifier: type.identifier, fileOptions: [],
                                            visibility: .all) { completion in
            completion(url, false, nil)
            return nil
        }
    }

    /// 文件字节的类型；字节不可读时返回 nil，调用方只登记 file-url。单文件、多文件的每一份都经过这里
    nonisolated static func byteType(ofFileAt path: String) -> UTType? {
#if APPSTORE
        // §4.5.3 的既有守卫（保留，不得删）：沙盒里这些路径通常读不了，而文件表示是惰性的，
        // 照样会声称能提供字节，接收方真去取时才拿到 nil——拖拽看起来成功了，落地却是空的。
        // 读不了就只登记 file-url，让需要字节的目标当场拒绝，而不是静默吞掉内容。
        // 补多表示后这道判定套在每一种文件字节表示上（`.onDrag` 的文件表示、macOS 26 起多文件的每一项）
        guard FileManager.default.isReadableFile(atPath: path) else { return nil }
#endif
        // 目录（含 .app 这类包）没有「字节」可给；已经被删、被移走的文件同理
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue else { return nil }
        let ext = (path as NSString).pathExtension
        return ext.isEmpty ? .data : UTType(filenameExtension: ext) ?? .data
    }

    /// 库里的图片按约定已经是 PNG（`ClipSaver.save(imagePNG:)`、`ClipboardMonitor` 采集时转码）；
    /// 万一不是就在这里转一次，不把别的格式的字节冒充成 PNG 交出去
    nonisolated private static func pngData(_ data: Data) -> Data? {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return data }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImageFromSource(destination, source, 0, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}

/// 多文件卡拖出时的一项（macOS 26 起，见 `ClipDragSource.multiFileSource`）。
/// Transferable 的表示类型是静态的，给不出每个文件自己的 UTI，字节按 §4.5.2 表原文登记为 `public.data`
@available(macOS 26, *)
struct ClipFileDragItem: Transferable, Sendable {
    /// 所属卡片：拖拽容器按它把拖起的那张卡对到这一组文件
    let cardID: PersistentIdentifier
    let url: URL
    /// 与 `.onDrag` 路径同一道判定（`ClipDrag.byteType`，含 §4.5.3 守卫）
    let bytesReadable: Bool

    init(cardID: PersistentIdentifier, path: String) {
        self.cardID = cardID
        url = URL(fileURLWithPath: path)
        bytesReadable = ClipDrag.byteType(ofFileAt: path) != nil
    }

    static var transferRepresentation: some TransferRepresentation {
        // URL 的代理表示对 file URL 同时给出 public.url 与 public.file-url
        ProxyRepresentation(exporting: { (item: ClipFileDragItem) in item.url })
        FileRepresentation(exportedContentType: .data) { item in SentTransferredFile(item.url) }
            .suggestedFileName { item in item.url.lastPathComponent }
            .exportingCondition { item in item.bytesReadable }
    }
}

/// 条目里存在 externalStorage 的字节（富文本的 RTF、图片）。拖起时只记下能跨线程的值（持久化 ID + ModelContainer），
/// 接收方来要时在后台用自己新建的 ModelContext 按 ID 取行读出来，与主线程的 mainContext 互不相干
/// ——同 `ThumbnailCache.Request` 的做法（7.5.5）。拖到半路放弃的，一个字节都不读
struct StoredBytes: Sendable {
    enum Field: Sendable {
        case rtf
        case image
    }

    let id: PersistentIdentifier
    let container: ModelContainer

    /// 条目已经不在任何 context 里（刚删掉）时拿不到容器，也就没什么可读的
    @MainActor
    init?(_ item: ClipItem) {
        guard let container = item.modelContext?.container else { return nil }
        id = item.persistentModelID
        self.container = container
    }

    /// 后台线程上调。context 在这条线程上建、用完就丢，不跨线程
    func read(_ field: Field) -> Data? {
        let context = ModelContext(container)
        let id = self.id
        var byID = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.persistentModelID == id })
        byID.fetchLimit = 1
        guard let row = try? context.fetch(byID).first else { return nil }
        switch field {
        case .rtf: return row.rtfData
        case .image: return row.imageData
        }
    }
}
