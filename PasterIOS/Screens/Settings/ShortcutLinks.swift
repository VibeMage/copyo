import Foundation

/// 「保存剪贴板」快捷指令的 iCloud 分享链接。
///
/// 只有「轻点背面」这条通道真的需要快捷指令：轻点背面在系统里只能绑定快捷指令，
/// 而操作按钮与控制中心都能直接选到本 App 提供的控件（PasterWidgets 的 `SaveClipboardControl`），
/// 不需要用户手工导入任何东西。
///
/// 链接要等快捷指令在「快捷指令」App 里发布后才拿得到，现在是占位：
/// `isPublished` 为假时界面弹提示而不是打开一个 404 页面。
enum ShortcutLinks {
    /// 发布后把这个常量换成真实的 iCloud 分享链接
    static let saveClipboard = "https://www.icloud.com/shortcuts/REPLACE-WITH-PUBLISHED-LINK"

    /// 占位串的标记。用后缀判断而不是整串相等，改域名时不用同步改这里。
    private static let placeholderMarker = "REPLACE-WITH-PUBLISHED-LINK"

    static var isPublished: Bool {
        !saveClipboard.contains(placeholderMarker)
    }

    /// 已发布时给出可打开的 URL，未发布时恒为 nil
    static var saveClipboardURL: URL? {
        guard isPublished else { return nil }
        return URL(string: saveClipboard)
    }
}
