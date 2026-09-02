import Foundation
import SwiftData

@Model
public final class Pinboard {
    public var name: String = ""
    public var sortIndex: Int = 0
    public var createdAt: Date = Date()
    @Relationship(deleteRule: .nullify, inverse: \ClipItem.pinboard)
    public var items: [ClipItem]? = []

    public init(name: String, sortIndex: Int) {
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }
}
