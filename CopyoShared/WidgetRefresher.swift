import Foundation
import WidgetKit

/// 库变动之后让主屏小组件重取一次时间线。
///
/// 三个进程都要调它：主应用（入库、固定 / 取消固定、删条目、删板，以及回前台发现库变了）、
/// 分享扩展与 `SaveContentIntent`。后两条路写库时**主应用根本没有运行**，
/// 等下次启动再刷新的话，用户分享完回到主屏看到的还是上一批内容。
///
/// 挂点与 `SpotlightIndexer` **不是同一组**，别照着另一处补：
/// 索引关心的是「哪一条的内容变了」，所以每个保存出口都要挂；小组件只关心「最新那几条变没变」，
/// 挂在 `AppModel.handle(_:)` 这一层就够，更靠下反而会为同一次保存刷两遍。
/// 改历史上限（`AppModel.applyHistoryLimit`）**故意不刷**——那只会删掉末尾的旧条目，
/// 最新那几条动不了，刷一次必然画出一模一样的东西，白花一次配额。
///
/// 只刷 `recentClipsKind`，**不用** `WidgetCenter.shared.reloadAllTimelines()`：
/// 后者会把 `SaveClipboardControl` 那个静态控件也一并推倒重来，而它显示什么与库无关，
/// 白白占掉 WidgetKit 每天的刷新配额。
enum WidgetRefresher {

    // MARK: - 身份

    /// 「最近」小组件的 kind。**发布之后不能改**——与 `SaveClipboardControl.kind` 同一条规矩：
    /// 改了等于换了一个小组件，用户已经摆在主屏上的那个会变成一个再也不刷新的空格子。
    ///
    /// 声明在 `CopyoShared/` 而不是 `CopyoWidgets/RecentClipsWidget.swift`：主应用编译不到
    /// `CopyoWidgets/`，放在那边就得在主应用里再抄一个字符串字面量。抄错一个字母的表现是
    /// 「小组件永远不刷新」，不报错也不崩溃，只是静默失效。
    static let recentClipsKind = "dev.vibemage.Copyo.recentClips"

    // MARK: - 总闸

    /// 演示 / 截图模式的总闸，由 `AppModel.init` 在灌样例数据之前合上，
    /// 与 `SpotlightIndexer.isSuspended` 是同一类门禁（那一个在 `CopyoIOSApp.init` 里合）。
    ///
    /// `-demoData` 走的是内存容器，样例条目一条也进不了共享库，所以刷新出来的内容并不会出错；
    /// 要挡的是**配额**：一轮截图会把应用拉起几十次，每次都发一遍刷新请求，
    /// 当天真正需要刷新时就没额度了。
    ///
    /// 比 `SpotlightIndexer` 那一处晚设一步（那边必须赶在建库之前）不要紧：
    /// `DemoData.populate` 直接往上下文里插对象，不经过这里任何一个挂点，
    /// 在它之前没有任何东西会请求刷新。
    static var isSuspended = false

    // MARK: - 刷新

    /// 合并窗口。一次用户动作常常经过两个挂点——典型的是分享面板存完、用户随手切回主应用，
    /// 通道 A 又把同一份内容按去重刷新一遍，两次请求之间往往不到一秒。
    /// WidgetKit 对后台发起的刷新有每天四五十次的配额，成对地浪费掉是真会把当天额度用光的。
    private static let coalescingWindow: TimeInterval = 2

    /// 串行队列同时当锁用：调用方分散在主线程（`AppModel`）、分享扩展的后台线程
    /// 与 `SaveContentIntent` 的 async 上下文里，下面两个标志必须只在一条线程上读写。
    private static let queue = DispatchQueue(label: "dev.vibemage.Copyo.WidgetRefresher")
    private static var isWindowOpen = false
    private static var didCoalesce = false

    /// 请求刷新「最近」小组件。
    ///
    /// **前沿触发**：第一次请求立刻就发出去，之后 `coalescingWindow` 内的再合并成一次补发。
    /// 顺序不能反成「等窗口结束再发」——分享扩展保存完马上就被系统回收，
    /// 那个延后的补发根本等不到执行，用户会看到小组件一直停在旧内容上。
    static func reloadRecentClips() {
        guard !isSuspended else { return }
        queue.async {
            guard !isWindowOpen else {
                // 窗口里来的请求记一笔就行，但**必须记**：丢掉的话窗口内最后那次变更
                // 就再也没有机会显示出来了
                didCoalesce = true
                return
            }
            isWindowOpen = true
            WidgetCenter.shared.reloadTimelines(ofKind: recentClipsKind)
            queue.asyncAfter(deadline: .now() + coalescingWindow) {
                isWindowOpen = false
                guard didCoalesce else { return }
                didCoalesce = false
                reloadRecentClips()
            }
        }
    }
}
