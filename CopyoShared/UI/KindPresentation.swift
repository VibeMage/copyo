import CopyoCore
import SwiftUI

/// ClipKind 的界面表达：本地化名、SF Symbol、筛选顺序。
///
/// 不进 `CopyoCore`，是因为本地化字符串表属于各自的 target：`String(localized:)` 默认从
/// `Bundle.main` 取译文，而扩展进程里的 `Bundle.main` 就是扩展自己的 bundle。
/// 这也正是那六个键（`Text` / `Rich` / `Link` / `Color` / `Image` / `File`）在
/// `CopyoIOS` / `CopyoShareExtension` / `CopyoWidgets` 三份 `Localizable.xcstrings` 里
/// 各存了一份的原因——**加新 kind 时三处都要补**，漏一处那个进程就把英文键名当译文显示出来。
///
/// 文件本身放在 `CopyoShared/`：三个 target 的同步组都含它，一份代码配三份译文。
/// 此前分享面板因为够不着主应用而在 `SharePreviewCard` 里另抄了一份 `ShareKindPresentation`，
/// 名字与符号得靠人工对齐；那份副本已删。
enum KindPresentation {

    static func label(_ kind: ClipKind) -> String {
        switch kind {
        case .text: String(localized: "Text")
        // 设计 3.2 的英文角标是 `Rich`；`Rich Text` 在卡片头部与详情标题里都会被截断
        case .richText: String(localized: "Rich")
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
