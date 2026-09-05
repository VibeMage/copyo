import Foundation

/// 卡片与详情页共用的展示派生值。放在 PasterCore 是因为 Mac 与 iOS 要给出一样的标题，
/// 但这里一律不做本地化——本地化字符串表在各自的 App target 里。
extension ClipItem {
    /// 链接条目指向的 URL；其他类型一律 nil（图片、文件的正文不是链接）
    public var linkURL: URL? {
        guard kind == .link else { return nil }
        let raw = plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    /// 链接域名，去掉 "www." 前缀（设计稿里的卡片标题就是这个）
    public var linkDomain: String? {
        guard let host = linkURL?.host(), !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// 正文看起来像代码或命令，界面据此改用等宽字体。只对纯文本 / 富文本判断。
    public var isCodeLike: Bool {
        guard kind == .text || kind == .richText, let text = plainText else { return false }
        return ClipClassifier.looksLikeCode(text)
    }

    /// 卡片标题的原始值（**不含本地化**）：
    /// - 链接 → 域名，取不到域名时用原始 URL 串
    /// - 文件 → 首个文件名；多个文件时仍只给第一个，数量由调用方另行显示
    /// - 颜色 → 大写 hex
    /// - 文本 / 富文本 → 第一行非空内容，最多 200 字（更长的内容标题也放不下）
    /// - 图片 → **空串**：占位文案（「图片」/ "Image"）需要本地化，由调用方在拿到空串时自己填
    public var displayTitle: String {
        switch kind {
        case .link:
            if let domain = linkDomain { return domain }
            return plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case .file:
            if let path = filePaths.first, !path.isEmpty {
                return (path as NSString).lastPathComponent
            }
            return plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case .color:
            return (plainText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        case .image:
            return ""
        case .text, .richText:
            let firstLine = (plainText ?? "")
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first(where: { !$0.isEmpty }) ?? ""
            return String(firstLine.prefix(200))
        }
    }
}
