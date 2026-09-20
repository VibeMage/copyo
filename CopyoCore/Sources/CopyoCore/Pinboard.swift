import Foundation
import SwiftData

@Model
public final class Pinboard {
    public var name: String = ""
    public var sortIndex: Int = 0
    public var createdAt: Date = Date()
    /// 列表里的 SF Symbol 名（paintpalette / mappin / terminal / doc.text 之类），空则由界面给默认图标
    public var iconName: String?
    /// 主题色 "#RRGGBB"，空则由界面给默认色
    public var colorHex: String?
    @Relationship(deleteRule: .nullify, inverse: \ClipItem.pinboard)
    public var items: [ClipItem]? = []

    public init(name: String, sortIndex: Int, iconName: String? = nil, colorHex: String? = nil) {
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = Date()
        self.iconName = iconName
        self.colorHex = colorHex
    }
}
