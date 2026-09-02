import Foundation
import PasterCore

extension ClipKind {
    /// 界面上显示的类型名。本地化表在 App 里，所以留在 App 侧而不进 PasterCore。
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
