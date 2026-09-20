import AppIntents
import Foundation

/// 主屏小组件「点按复制」的入口：**不在扩展进程里写剪贴板**，只在 App Group 里留一条请求，
/// 把主应用拉到前台，由 `AppModel.copy(_:)` 真正写。
///
/// 两条理由，第二条才是决定性的：
///
/// 1. 小组件扩展多半根本写不了 `UIPasteboard.general`。`UIPasteboard.h` 上没有
///    `API_UNAVAILABLE(iosApplicationExtension)` 标注，所以**编译期一声不吭**，
///    只在真机运行时失败；而模拟器据称不拦这一下，在模拟器上测一遍会得到一个假的「通过」。
/// 2. 就算写得进去，这条路也仍然更差。`AppModel.copy(_:)` 会顺手 `capture.markSeen()`，
///    把 `UIPasteboard.general.changeCount` 记进 `IOSSettings.lastPasteboardChangeCount`；
///    扩展进程算不出这个数——它连剪贴板对象都碰不到。少了这一步，用户下次回到主应用时
///    `PasteboardCapture.checkOnForeground()` 会发现 changeCount 变了，把这份内容重新入库，
///    命中 `ClipSaver` 的去重 `.refreshed` 分支并原地把 `createdAt` 改成现在——
///    **每从小组件复制一次，这条内容就在历史里悄悄跳到最前面一次**。
///    `AppModel.copyAllAsPlainText` 的注释记的就是同一条坑。
///
/// 形状照搬已经跑通的通道 C（`SaveClipboardIntent` 留时间戳 → `QuickSaveCoordinator`
/// 在主应用激活时消费），连有效期和 500ms 补读都共用同一套，见那两个文件。
struct CopyClipIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Clip"

    /// 拉起主应用是这条路的全部意义：剪贴板只有前台的主应用写得了
    static let openAppWhenRun = true

    /// 不进快捷指令库。它唯一的参数是一个编码过的 `PersistentIdentifier`，
    /// 只有本机这一份库解得开，用户在快捷指令编辑器里手填不出有意义的值。
    static let isDiscoverable = false

    @Parameter(title: "Clip")
    var clipID: String

    init() {}

    init(clipID: String) {
        self.clipID = clipID
    }

    func perform() async throws -> some IntentResult {
        CopyoAppGroup.markCopyRequested(clipID: clipID)
        return .result()
    }
}
