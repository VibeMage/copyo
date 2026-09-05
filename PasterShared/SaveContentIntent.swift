import AppIntents
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// 采集通道 C（快捷指令路径）：静默保存，不打开主应用。
///
/// 典型用法是在快捷指令里组合「获取剪贴板 → Paster 保存内容」，绑到敲击背面或操作按钮上：
/// 剪贴板由快捷指令系统读（用户已经在 Shortcuts 里授过权），内容作为参数传进来，
/// Paster 全程不碰剪贴板，也不用把自己拉到前台——用户留在当前 App 里，只看到一条顶部横幅。
///
/// 三个参数三选一（至少给一个），优先级 图片 > 链接 > 文本：
/// 网页分享类的输入通常同时带 URL 和标题，链接比标题更有保存价值。
struct SaveContentIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Content"
    static let description = IntentDescription(
        "Saves text, a link, or an image to Paster without opening the app.",
        categoryName: "Clipboard",
        searchKeywords: ["clipboard", "save", "clip"]
    )
    /// 静默路径的全部意义就在这里：不抢前台
    static let openAppWhenRun = false

    @Parameter(title: "Text")
    var text: String?

    @Parameter(title: "URL")
    var url: URL?

    @Parameter(title: "Image", supportedContentTypes: [.image])
    var image: IntentFile?

    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$text) to Paster") {
            \.$url
            \.$image
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let payload = try makePayload()
        let container = try ClipIngest.makeContainer()
        let context = ModelContext(container)
        try ClipIngest.save(payload, pinboardID: nil, in: context)
        return .result(dialog: IntentDialog("Saved"))
    }

    private func makePayload() throws -> SharePayload {
        if let image {
            let data = image.data
            guard let prepared = ClipImagePreparer.prepare(data: data) else {
                throw SaveContentError.unreadableImage
            }
            return .image(png: prepared.png,
                          pixelWidth: prepared.pixelWidth,
                          pixelHeight: prepared.pixelHeight)
        }
        if let url {
            return .link(url, title: text)
        }
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(text, rtfData: nil)
        }
        throw SaveContentError.noContent
    }
}

/// 快捷指令里报的错要能读懂：用户看到的就是这句话，没有别的排错线索。
enum SaveContentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case noContent
    case unreadableImage

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noContent:
            "Give Save Content some text, a link, or an image."
        case .unreadableImage:
            "Paster couldn't read that image."
        }
    }
}
