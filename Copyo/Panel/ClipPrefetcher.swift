import CopyoCore
import SwiftData

/// 面板的预热（design-spec 7.5.5）：面板唤出时的首屏与紧随其后的几张、以及每张卡在屏上期间的左右邻居，
/// 提前把缩略图、来源 App 图标（文件卡还有类型图标）排进后台加载，卡片滑进来时多半已经是真图。
///
/// 预热与卡片自己走同一条加载队列：同一 key 已经在途就搭车，不会重复读盘解码；并发上限也是同一个。
/// 预热方的 task 被取消（触发它的卡片离屏、面板再次唤出）时撤回兴趣，排队中还没开跑的随之撤掉。
@MainActor
enum ClipPrefetcher {
    /// 面板最宽 1280 时一屏露出不到 5 张（卡宽 260 + 间距 12），首屏按 5 张算
    static let firstScreenCount = 5
    /// 每张卡在屏上期间替左右各预热几张；面板唤出时首屏之后也多备这么几张
    static let neighborRadius = 2

    /// 一条要预热的东西。`ClipItem` 是 @Model、带不出主线程，这里只留能跨线程的值
    struct Target: Sendable {
        let id: PersistentIdentifier
        let thumbnail: ThumbnailCache.Request?
        let bundleID: String?
        let fileExtension: String?

        @MainActor
        init(_ item: ClipItem) {
            id = item.persistentModelID
            thumbnail = item.kind == .image ? ThumbnailCache.Request(item) : nil
            bundleID = item.sourceAppBundleID
            fileExtension = item.kind == .file ? FileTypeIconCache.extensionKey(forPath: item.filePaths.first) : nil
        }
    }

    /// 面板唤出：首屏与紧随其后的几张
    static func firstScreen(of items: [ClipItem]) -> [Target] {
        items.prefix(firstScreenCount + neighborRadius).map(Target.init)
    }

    /// 第 `index` 张卡的左右邻居（不含它自己——它自己的图由卡片视图去取）
    static func neighbors(of index: Int, in items: [ClipItem]) -> [Target] {
        let lower = max(0, index - neighborRadius)
        let upper = min(items.count - 1, index + neighborRadius)
        guard lower <= upper else { return [] }
        return (lower...upper).filter { $0 != index }.map { Target(items[$0]) }
    }

    /// 把这一批排进后台加载，全部落进缓存才返回。调用方被取消时，排队中还没开跑的一并撤掉
    static func warm(_ targets: [Target]) async {
        await withTaskGroup(of: Void.self) { group in
            for target in targets {
                if let request = target.thumbnail {
                    group.addTask { await ThumbnailCache.warm(request) }
                }
                if let bundleID = target.bundleID {
                    group.addTask { await AppIconProvider.warm(bundleID: bundleID) }
                }
                if let ext = target.fileExtension {
                    group.addTask { await FileTypeIconCache.warm(extension: ext) }
                }
            }
        }
    }
}
