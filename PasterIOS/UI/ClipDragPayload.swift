import CoreTransferable
// ClipKind 还没标 Sendable（PasterCore 属于另一位代理），
// 这里的载荷本身是值类型且只读，用 @preconcurrency 把噪音挡掉
import PasterCore
import SwiftUI
import UniformTypeIdentifiers

/// iPad 拖放的载荷。一条条目同时提供多种表示，接收方按自己的能力挑：
/// 备忘录取富文本、Safari 取 URL、相册取 PNG、任何输入框都能取纯文本。
///
/// 之所以不直接让 `ClipItem` 遵循 `Transferable`：SwiftData 的模型对象只能在自己的
/// ModelContext 上访问，而拖放的导出闭包会在别的队列跑。这里先把需要的值抄成不可变结构体。
struct ClipTransferable: Transferable, Sendable {
    var kind: ClipKind
    var text: String
    var rtf: Data?
    var url: URL?
    var imagePNG: Data?
    var suggestedName: String

    enum ExportError: Error {
        /// 这条条目没有这种表示（比如给文本条目要 PNG）
        case unavailable
    }

    static var transferRepresentation: some TransferRepresentation {
        // 顺序即优先级：接收方会挑它支持的第一种
        DataRepresentation(exportedContentType: .png) { payload in
            guard let data = payload.imagePNG else { throw ExportError.unavailable }
            return data
        }
        .suggestedFileName { "\($0.suggestedName).png" }

        DataRepresentation(exportedContentType: .rtf) { payload in
            guard let data = payload.rtf else { throw ExportError.unavailable }
            return data
        }

        ProxyRepresentation { (payload: ClipTransferable) -> URL in
            guard let url = payload.url else { throw ExportError.unavailable }
            return url
        }

        ProxyRepresentation(exporting: \.text)
    }
}

extension ClipItem {
    /// 拖起这条条目时的载荷。必须在主线程 / 条目自己的 context 上取。
    var transferable: ClipTransferable {
        ClipTransferable(kind: kind,
                         text: plainText ?? displayTitle,
                         rtf: kind == .richText ? rtfData : nil,
                         url: linkURL,
                         imagePNG: kind == .image ? imageData : nil,
                         suggestedName: displayTitle.isEmpty ? "Paster" : String(displayTitle.prefix(40)))
    }
}
