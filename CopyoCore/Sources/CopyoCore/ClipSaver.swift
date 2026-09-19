import Foundation
import SwiftData

/// 采集来源。Mac 端能拿到前台应用的名字、bundle ID 与图标主题色；
/// iOS 沙盒里这些一概拿不到，本机保存的条目用 `.local`（界面把来源显示成本地化的「本机」）。
public struct ClipSource: Sendable, Equatable {
    public var appName: String?
    public var bundleID: String?
    /// "#RRGGBB"，见 `HexColor.string(red:green:blue:)`
    public var colorHex: String?

    public init(appName: String? = nil, bundleID: String? = nil, colorHex: String? = nil) {
        self.appName = appName
        self.bundleID = bundleID
        self.colorHex = colorHex
    }

    /// 本机采集：三个字段都留空，来源文案与固定灰由界面给出
    public static let local = ClipSource()
}

/// 保存的结果。命中去重时不会新增条目，而是把已有条目提到最前，
/// 界面据此决定提示「已保存」还是「已在历史里」。
public enum SaveResult {
    case inserted(ClipItem)
    case refreshed(ClipItem)

    public var item: ClipItem {
        switch self {
        case .inserted(let item), .refreshed(let item): return item
        }
    }

    public var isNew: Bool {
        if case .inserted = self { return true }
        return false
    }
}

public enum ClipSaverError: LocalizedError {
    case emptyContent

    public var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "There is nothing to save."
        }
    }
}

/// 入库规则（去重 → 置顶 → 历史上限清理）的跨平台实现，供 iOS 主应用、分享扩展、App Intent 共用。
///
/// Mac 端的 `ClipboardMonitor.insertDeduplicated` 是同一套规则的原始实现，本轮**没有**改成调用这里
/// （Mac 已上架，不值得为复用冒回归风险）。两处规则必须保持一致：改动去重条件或上限策略时两边都要改。
/// 已知的一处差异：Mac 在 save 之前清理上限，这一轮插入的条目还没落盘，因此最多会多留一条；
/// 这里先 save 再清理，条数是准的。
public enum ClipSaver {
    /// 去重时回看多少条最近记录。与 Mac 端一致：足够挡住「反复复制同一段」，又不必扫全表。
    public static let duplicateScanLimit = 50

    /// 文本 / 富文本 / 链接 / 颜色。类型由 `ClipClassifier` 判定，调用方不需要自己分类。
    /// - Parameter historyLimit: 未固定条目的上限，nil 或 <= 0 表示不限制
    @discardableResult
    public static func save(text: String,
                            rtfData: Data? = nil,
                            source: ClipSource,
                            historyLimit: Int?,
                            in context: ModelContext) throws -> SaveResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClipSaverError.emptyContent
        }
        let item = ClipItem(kind: ClipClassifier.classify(text: text, hasRTF: rtfData != nil),
                            plainText: text,
                            rtfData: rtfData,
                            sourceAppBundleID: source.bundleID,
                            sourceAppName: source.appName,
                            sourceColorHex: source.colorHex)
        return try insert(item, historyLimit: historyLimit, in: context)
    }

    /// 图片。调用方负责先转成 PNG（iOS 侧用 UIImage.pngData()，Mac 侧用 NSBitmapImageRep）。
    @discardableResult
    public static func save(imagePNG: Data,
                            source: ClipSource,
                            historyLimit: Int?,
                            in context: ModelContext) throws -> SaveResult {
        guard !imagePNG.isEmpty else { throw ClipSaverError.emptyContent }
        let item = ClipItem(kind: .image,
                            imageData: imagePNG,
                            sourceAppBundleID: source.bundleID,
                            sourceAppName: source.appName,
                            sourceColorHex: source.colorHex)
        // 去重比的是哈希，避免把 externalStorage 里的整张图读进内存
        item.imageHash = ContentHash.sha256(imagePNG)
        return try insert(item, historyLimit: historyLimit, in: context)
    }

    /// 只删未固定条目、按 createdAt 从旧到新删；固定到 Pinboard 的内容不占历史配额。
    /// 真的删掉东西时会自己 save。
    public static func enforceHistoryLimit(_ limit: Int, in context: ModelContext) throws {
        guard limit > 0 else { return }
        let unpinned = #Predicate<ClipItem> { $0.pinboard == nil }
        let count = try context.fetchCount(FetchDescriptor<ClipItem>(predicate: unpinned))
        guard count > limit else { return }

        var descriptor = FetchDescriptor<ClipItem>(predicate: unpinned,
                                                   sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchOffset = limit
        let overflow = try context.fetch(descriptor)
        guard !overflow.isEmpty else { return }
        for item in overflow {
            context.delete(item)
        }
        try context.save()
    }

    // MARK: - 内部

    private static func insert(_ newItem: ClipItem,
                               historyLimit: Int?,
                               in context: ModelContext) throws -> SaveResult {
        if let duplicate = try findDuplicate(of: newItem, in: context) {
            duplicate.createdAt = Date()
            duplicate.sourceAppBundleID = newItem.sourceAppBundleID
            duplicate.sourceAppName = newItem.sourceAppName
            duplicate.sourceColorHex = newItem.sourceColorHex
            // 同一段文本这次可能带来不同的富文本表示（或不再有），同步最新的；
            // pinboard 不动，用户固定过的条目不会因为再复制一次而掉出 Pinboard
            if newItem.kind != .image && newItem.kind != .file {
                duplicate.rtfData = newItem.rtfData
                duplicate.kindRaw = newItem.kindRaw
            }
            // 扩展进程与 LSUIElement 应用的 autosave 都不可靠，一律显式保存
            try context.save()
            return .refreshed(duplicate)
        }

        context.insert(newItem)
        try context.save()
        if let historyLimit, historyLimit > 0 {
            try enforceHistoryLimit(historyLimit, in: context)
        }
        return .inserted(newItem)
    }

    private static func findDuplicate(of newItem: ClipItem, in context: ModelContext) throws -> ClipItem? {
        var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = duplicateScanLimit
        let recent = try context.fetch(descriptor)

        switch newItem.kind {
        case .image:
            guard let hash = newItem.imageHash else { return nil }
            return recent.first { $0.kind == .image && $0.imageHash == hash }
        case .file:
            let paths = newItem.filePaths
            return recent.first { $0.kind == .file && $0.filePaths == paths }
        default:
            // 文本类之间互相去重：同一段文字这次带富文本、下次不带，仍然算同一条
            let text = newItem.plainText
            return recent.first { $0.kind != .image && $0.kind != .file && $0.plainText == text }
        }
    }
}
