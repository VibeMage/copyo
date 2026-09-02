import Foundation

/// 文本内容分类：判断复制来的文本属于哪种条目类型。
public enum ClipClassifier {
    public static func classify(text: String, hasRTF: Bool) -> ClipKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: "^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$", options: .regularExpression) != nil {
            return .color
        }
        if !trimmed.contains(where: \.isWhitespace),
           let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return .link
        }
        return hasRTF ? .richText : .text
    }
}
