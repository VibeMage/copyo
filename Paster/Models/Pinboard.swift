import Foundation
import SwiftData

@Model
final class Pinboard {
    var name: String = ""
    var sortIndex: Int = 0
    var createdAt: Date = Date()
    @Relationship(deleteRule: .nullify, inverse: \ClipItem.pinboard)
    var items: [ClipItem]? = []

    init(name: String, sortIndex: Int) {
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }
}
