import Foundation
import SwiftData

enum ClipKind: String, Codable, CaseIterable {
    case text
    case richText
    case link
    case color
    case image
    case file

    var label: String {
        switch self {
        case .text: String(localized: "Text")
        case .richText: String(localized: "Rich Text")
        case .link: String(localized: "Link")
        case .color: String(localized: "Color")
        case .image: String(localized: "Image")
        case .file: String(localized: "File")
        }
    }
}

@Model
final class ClipItem {
    var createdAt: Date = Date()
    var kindRaw: String = ClipKind.text.rawValue
    var plainText: String?
    @Attribute(.externalStorage) var rtfData: Data?
    @Attribute(.externalStorage) var imageData: Data?
    /// 图片内容的 SHA-256，用于去重时避免读取完整图片数据
    var imageHash: String?
    var filePaths: [String] = []
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var charCount: Int = 0
    var pinboard: Pinboard?

    var kind: ClipKind {
        get { ClipKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: ClipKind,
         plainText: String? = nil,
         rtfData: Data? = nil,
         imageData: Data? = nil,
         filePaths: [String] = [],
         sourceAppBundleID: String? = nil,
         sourceAppName: String? = nil) {
        self.createdAt = Date()
        self.kindRaw = kind.rawValue
        self.plainText = plainText
        self.rtfData = rtfData
        self.imageData = imageData
        self.filePaths = filePaths
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.charCount = plainText?.count ?? 0
    }
}
