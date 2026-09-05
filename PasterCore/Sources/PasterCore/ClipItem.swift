import Foundation
import SwiftData

public enum ClipKind: String, Codable, CaseIterable {
    case text
    case richText
    case link
    case color
    case image
    case file
}

@Model
public final class ClipItem {
    public var createdAt: Date = Date()
    public var kindRaw: String = ClipKind.text.rawValue
    public var plainText: String?
    @Attribute(.externalStorage) public var rtfData: Data?
    @Attribute(.externalStorage) public var imageData: Data?
    /// 图片内容的 SHA-256，用于去重时避免读取完整图片数据
    public var imageHash: String?
    public var filePaths: [String] = []
    public var sourceAppBundleID: String?
    public var sourceAppName: String?
    /// 来源 App 的主题色 "#RRGGBB"。只有 Mac 端算得出（沙盒里的 iOS 拿不到别的 App 的图标），
    /// 采集时算好写进来，iOS 直接用它给卡片淡染；本机保存的条目为 nil。
    public var sourceColorHex: String?
    public var charCount: Int = 0
    public var pinboard: Pinboard?

    public var kind: ClipKind {
        get { ClipKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    public init(kind: ClipKind,
                plainText: String? = nil,
                rtfData: Data? = nil,
                imageData: Data? = nil,
                filePaths: [String] = [],
                sourceAppBundleID: String? = nil,
                sourceAppName: String? = nil,
                sourceColorHex: String? = nil) {
        self.createdAt = Date()
        self.kindRaw = kind.rawValue
        self.plainText = plainText
        self.rtfData = rtfData
        self.imageData = imageData
        self.filePaths = filePaths
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.sourceColorHex = sourceColorHex
        self.charCount = plainText?.count ?? 0
    }
}
