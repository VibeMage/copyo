import PasterCore
import SwiftUI

/// ClipKind 的界面表达：本地化名、SF Symbol、筛选顺序。
/// 放在 App 侧而不进 PasterCore，是因为本地化字符串表属于各自的 target。
enum KindPresentation {

    static func label(_ kind: ClipKind) -> String {
        switch kind {
        case .text: String(localized: "Text")
        case .richText: String(localized: "Rich Text")
        case .link: String(localized: "Link")
        case .color: String(localized: "Color")
        case .image: String(localized: "Image")
        case .file: String(localized: "File")
        }
    }

    static func symbol(_ kind: ClipKind) -> String {
        switch kind {
        case .text: "text.alignleft"
        case .richText: "textformat"
        case .link: "link"
        case .color: "circle.lefthalf.filled"
        case .image: "photo"
        case .file: "doc"
        }
    }

    /// iPhone 顶部筛选 chips 的顺序（设计 01：全部 / 文本 / 链接 / 图片 / 颜色）。
    /// 富文本并入「文本」、文件在手机上不单列——见 design-spec 第八节第 1 条，两端口径尚未拍板。
    static let compactFilters: [ClipKind] = [.text, .link, .image, .color]

    /// iPad 侧栏的分类（设计 09：历史 / 文本 / 链接 / 图片 / 颜色 / 文件）
    static let regularFilters: [ClipKind] = [.text, .link, .image, .color, .file]

    /// 「文本」筛选把富文本一并算进来，否则用户找不到从备忘录复制的内容
    static func matches(_ item: ClipItem, filter: ClipKind?) -> Bool {
        guard let filter else { return true }
        if filter == .text { return item.kind == .text || item.kind == .richText }
        return item.kind == filter
    }
}
