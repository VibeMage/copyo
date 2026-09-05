import CoreTransferable
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

    static var transferRepresentation: some TransferRepresentation {
        // 顺序即优先级：接收方会挑它支持的第一种。
        // 「这条条目没有这种表示」一律走 exportingCondition 关掉整个表示，不要在导出闭包里抛错——
        // 抛错也能工作，但每次导出都会在日志里刷一条 CoreTransferable Fault。
        DataRepresentation(exportedContentType: .png) { payload in
            payload.imagePNG ?? Data()
        }
        .suggestedFileName { "\($0.suggestedName).png" }
        .exportingCondition { $0.imagePNG != nil }

        DataRepresentation(exportedContentType: .rtf) { payload in
            payload.rtf ?? Data()
        }
        .exportingCondition { $0.rtf != nil }

        ProxyRepresentation { (payload: ClipTransferable) -> URL in
            payload.url ?? URL(filePath: "/")
        }
        .exportingCondition { $0.url != nil }

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
