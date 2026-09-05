import PasterCore
import SwiftUI
import UIKit

/// 把条目写回系统剪贴板。尽量多给几种表示，粘贴方按自己的能力挑：
/// 富文本条目同时给 RTF 与纯文本，链接同时给 URL 与字符串，颜色给 hex 字符串。
enum ClipboardWriter {

    /// 写入结果。文件类条目在 iOS 上没有可用的表示（路径指向的是 Mac 上的文件），
    /// 界面据此提示「仅 Mac」而不是假装复制成功。
    enum Result: Equatable {
        case written
        case unsupported
        case empty
    }

    @discardableResult
    static func write(_ item: ClipItem) -> Result {
        let pasteboard = UIPasteboard.general
        switch item.kind {
        case .file:
            return .unsupported

        case .image:
            guard let data = item.imageData, let image = UIImage(data: data) else { return .empty }
            // 同时给 image 与 PNG data：只给 image 的话，接收方拿到的是重新编码的位图
            var representation: [String: Any] = ["public.png": data]
            representation[UTTypeIdentifier.image] = image
            pasteboard.items = [representation]
            return .written

        case .link:
            let text = (item.plainText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return .empty }
            if let url = URL(string: text) {
                // 有些输入框只认 public.url，有些只认字符串，两个都给
                pasteboard.items = [[UTTypeIdentifier.url: url, UTTypeIdentifier.plainText: text]]
            } else {
                pasteboard.string = text
            }
            return .written

        case .richText:
            let text = item.plainText ?? ""
            guard !text.isEmpty || item.rtfData != nil else { return .empty }
            var representation: [String: Any] = [UTTypeIdentifier.plainText: text]
            if let rtf = item.rtfData { representation[UTTypeIdentifier.rtf] = rtf }
            pasteboard.items = [representation]
            return .written

        case .text, .color:
            let text = item.plainText ?? ""
            guard !text.isEmpty else { return .empty }
            pasteboard.string = text
            return .written
        }
    }

    /// 纯文本复制：只给字符串表示，粘贴到富文本编辑器时不会带样式
    @discardableResult
    static func writePlainText(_ item: ClipItem) -> Result {
        switch item.kind {
        case .file:
            return .unsupported
        case .image:
            // 图片没有纯文本表示，退回普通复制
            return write(item)
        default:
            let text = item.plainText ?? ""
            guard !text.isEmpty else { return .empty }
            UIPasteboard.general.string = text
            return .written
        }
    }

    /// 分享面板（UIActivityViewController / ShareLink）的载荷
    static func shareItems(for item: ClipItem) -> [Any] {
        switch item.kind {
        case .image:
            if let data = item.imageData, let image = UIImage(data: data) { return [image] }
            return []
        case .link:
            if let url = item.linkURL { return [url] }
            return [item.plainText ?? ""]
        case .file:
            return [item.displayTitle]
        default:
            return [item.plainText ?? ""]
        }
    }

    private enum UTTypeIdentifier {
        static let plainText = "public.utf8-plain-text"
        static let rtf = "public.rtf"
        static let url = "public.url"
        static let image = "public.image"
    }
}
