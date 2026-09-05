import Foundation
import UniformTypeIdentifiers
import UIKit

/// 把系统分享面板交过来的 `NSExtensionItem` 归一成一份 `SharePayload`。
///
/// 刻意写成非隔离的 async 函数（不是 `@MainActor`）：图片降采样要在协作线程池上跑，
/// 挂在主线程上会把面板卡住，用户看到的就是「点了分享、面板半天不动」。
enum ShareAttachmentLoader {

    /// 取内容的优先级：图片 > 链接 > 文本。
    ///
    /// 网页分享通常同时给 URL 和标题（标题走 `public.plain-text`），这时链接才是用户想留的东西，
    /// 标题只当预览卡的标题行用。从备忘录之类分享纯文字时没有 URL，自然落到文本。
    static func load(from items: [NSExtensionItem]) async -> SharePayload? {
        var imageProvider: NSItemProvider?
        var urlProvider: NSItemProvider?
        var textProvider: NSItemProvider?
        var rtfProvider: NSItemProvider?
        var fallbackText: String?

        for item in items {
            if fallbackText == nil, let attributed = item.attributedContentText?.string,
               !attributed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                fallbackText = attributed
            }
            for provider in item.attachments ?? [] {
                // 一个附件可能同时声明多种表示（富文本往往连纯文本一起给），
                // 所以富文本那一档不 continue，让同一个附件还能落进文本槽
                if imageProvider == nil, provider.conforms(to: .image) {
                    imageProvider = provider
                    continue
                }
                if rtfProvider == nil, provider.conforms(to: .rtf) {
                    rtfProvider = provider
                }
                // 链接要排在纯文本前面：URL 附件常常也声明 public.plain-text，
                // 先判文本就会把链接当普通文字存
                if urlProvider == nil, provider.conforms(to: .url) {
                    urlProvider = provider
                    continue
                }
                if textProvider == nil, provider.conformsToPlainText {
                    textProvider = provider
                }
            }
        }

        var text = fallbackText
        if let textProvider, let loaded = await loadText(from: textProvider) {
            text = loaded
        }
        if text == nil, let rtfProvider, let loaded = await loadText(from: rtfProvider) {
            // 只给了富文本、没给纯文本：正文从同一个附件里再取一次
            text = loaded
        }

        if let imageProvider, let prepared = await loadImage(from: imageProvider) {
            return .image(png: prepared.png,
                          pixelWidth: prepared.pixelWidth,
                          pixelHeight: prepared.pixelHeight)
        }
        if let urlProvider, let url = await loadURL(from: urlProvider) {
            // 文件 URL 当链接存没有意义（路径出了这台设备就是死的），退回文本或直接放弃
            if !url.isFileURL {
                return .link(url, title: text)
            }
        }
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var rtf: Data?
            if let rtfProvider { rtf = await loadData(from: rtfProvider, type: .rtf) }
            return .text(text, rtfData: rtf)
        }
        return nil
    }

    // MARK: - 各类型的取值

    private static func loadImage(from provider: NSItemProvider) async -> ClipImagePreparer.Prepared? {
        // loadItem 可能回 URL / Data / UIImage 三种表示，逐一试：
        // 走 URL 或 Data 时能用 ImageIO 只解一张缩略图出来，不必把原图整张读进内存
        if let value = await loadItem(from: provider, type: .image) {
            if let url = value as? URL, let prepared = ClipImagePreparer.prepare(fileURL: url) {
                return prepared
            }
            if let data = value as? Data, let prepared = ClipImagePreparer.prepare(data: data) {
                return prepared
            }
            if let image = value as? UIImage, let prepared = ClipImagePreparer.prepare(image: image) {
                return prepared
            }
        }
        guard provider.canLoadObject(ofClass: UIImage.self),
              let image = await loadObject(UIImage.self, from: provider) else { return nil }
        return ClipImagePreparer.prepare(image: image)
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        // NSURL 而不是 URL：NSItemProviderReading 是 Objective-C 协议，Swift 值类型在泛型里对不上
        guard let url = await loadObject(NSURL.self, from: provider) else { return nil }
        return url as URL
    }

    private static func loadText(from provider: NSItemProvider) async -> String? {
        if let string = await loadObject(NSString.self, from: provider) {
            return string as String
        }
        // public.utf8-plain-text 不继承 public.plain-text，只问前者会漏掉一部分来源
        for type in [UTType.plainText, UTType.utf8PlainText] {
            guard let value = await loadItem(from: provider, type: type) else { continue }
            if let string = value as? String { return string }
            if let data = value as? Data, let string = String(data: data, encoding: .utf8) { return string }
        }
        return nil
    }

    private static func loadData(from provider: NSItemProvider, type: UTType) async -> Data? {
        guard let value = await loadItem(from: provider, type: type) else { return nil }
        if let data = value as? Data { return data }
        if let url = value as? URL { return try? Data(contentsOf: url) }
        return nil
    }

    // MARK: - NSItemProvider 的回调包装

    private static func loadObject<T: NSItemProviderReading>(_ type: T.Type,
                                                             from provider: NSItemProvider) async -> T? {
        guard provider.canLoadObject(ofClass: type) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: type) { object, _ in
                continuation.resume(returning: object as? T)
            }
        }
    }

    private static func loadItem(from provider: NSItemProvider, type: UTType) async -> NSSecureCoding? {
        guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }
}

private extension NSItemProvider {
    func conforms(to type: UTType) -> Bool {
        hasItemConformingToTypeIdentifier(type.identifier)
    }

    /// `public.plain-text` 与 `public.utf8-plain-text`：后者不继承前者，两个都得问一遍
    var conformsToPlainText: Bool {
        conforms(to: .plainText) || conforms(to: .utf8PlainText)
    }
}
