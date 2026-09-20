import CopyoCore
import Foundation
import SwiftData
import WidgetKit

/// 一帧「最近」小组件要画的东西。
struct RecentClipsEntry: TimelineEntry {
    /// 这一帧代表的时刻。相对时间一律按它算，不能按 `Date()`——条目是提前生成好归档起来的
    let date: Date
    /// 要显示的条目，顺序即新到旧。空数组且 `isLibraryUnavailable == false` 表示「库里就是空的」
    let snapshots: [ClipSnapshot]
    /// 共享库根本打不开。用它把「库是空的」和「读不到库」分开——两种情况要说的话不一样，
    /// 而后者在 App Group entitlement 真正展开之前是真机上的**预期状态**
    var isLibraryUnavailable = false
    /// 主应用抄过来的同步状态，未知 / 过期时为 nil，中尺寸的头部据此决定显不显示
    var syncState: WidgetSyncState?
}

/// 「最近」小组件的取数端。
struct RecentClipsProvider: AppIntentTimelineProvider {

    // MARK: - 共享库

    /// 共享库**整个进程只建一次**。`ModelContainer` 的建立要读 schema、开 SQLite，
    /// 在小组件这点时间与内存的余量里，每次刷新都重来一遍是笔白花的开销。
    ///
    /// `ClipIngest.makeContainer()` 原样用，**它的 `cloudKit: false` 在这里不是偏好而是硬性要求**：
    /// `CopyoWidgets.entitlements` 里只有 App Group，没有 iCloud 容器也没有 `aps-environment`，
    /// 挂 CloudKit 镜像的配置在这个进程里直接抛错，小组件就会永远停在占位图上。
    ///
    /// 建不起来时留 nil 而不是 `try!`：`CopyoStore.appGroupStoreURL()` 在 App Group 没配好时抛
    /// `appGroupUnavailable`，而那正是真机上 entitlement 真正展开之前的**预期状态**。
    /// `static let` 只算一次，所以这一进程里会一直是 nil；小组件进程本来就短命，
    /// 下次拉起时会重试一遍。
    private static let container: ModelContainer? = try? ClipIngest.makeContainer()

    // MARK: - AppIntentTimelineProvider

    /// 占位图。**不开库**：画廊里滚动、以及正式内容到位之前的过渡帧都会要它，
    /// 慢一下用户看到的就是一个空格子。
    ///
    /// 里面那几行字故意**没有进本地化目录**——占位图由系统整体 redact 成灰条，
    /// 一个字也不会被读出来，它们唯一的作用是把行数和格子宽度撑成真实内容的样子。
    /// 也因此没照抄 design-spec 6.7 那四行中文样例，换成了语言无关的内容（命令行、域名、色值、图片）：
    /// 占位图是全流程里唯一一处可能露出未本地化文案的地方，选这样的内容，
    /// 万一哪天露出来了，法语用户看到的也不会是四行中文。
    func placeholder(in context: Context) -> RecentClipsEntry {
        RecentClipsEntry(date: Date(),
                         snapshots: Array(Self.sampleSnapshots.prefix(Self.clipLimit(for: context.family))),
                         syncState: .synced)
    }

    /// 画廊里给用户看的那一帧。这里**照常开库**：`fetchLimit` 最多 4 条，从 SQLite 里读出来是毫秒级的，
    /// 用样例顶上的话用户在画廊里挑完、摆上主屏，内容会当场变一次样。
    ///
    /// 库打不开时给的是「打不开」那一帧，**不是**占位图：画廊里这一帧不会被 redact，
    /// 退回占位图等于把那几行英文样例当成真内容摆给用户看。
    func snapshot(for configuration: RecentClipsConfiguration, in context: Context) async -> RecentClipsEntry {
        let limit = Self.clipLimit(for: context.family)
        let syncState = CopyoAppGroup.widgetSyncState
        guard let snapshots = Self.loadSnapshots(limit: limit) else {
            return RecentClipsEntry(date: Date(),
                                    snapshots: [],
                                    isLibraryUnavailable: true,
                                    syncState: syncState)
        }
        return RecentClipsEntry(date: Date(), snapshots: snapshots, syncState: syncState)
    }

    func timeline(for configuration: RecentClipsConfiguration,
                  in context: Context) async -> Timeline<RecentClipsEntry> {
        let now = Date()
        let limit = Self.clipLimit(for: context.family)
        let syncState = CopyoAppGroup.widgetSyncState

        guard let snapshots = Self.loadSnapshots(limit: limit) else {
            let entry = RecentClipsEntry(date: now,
                                         snapshots: [],
                                         isLibraryUnavailable: true,
                                         syncState: syncState)
            return Timeline(entries: [entry], policy: .never)
        }

        let entries = ([now] + Self.relativeTimeLadder(from: now, newest: snapshots.first))
            .map { RecentClipsEntry(date: $0, snapshots: snapshots, syncState: syncState) }
        return Timeline(entries: entries, policy: .never)
    }

    // MARK: - 取数

    /// 返回 nil 表示共享库打不开（与「库里一条都没有」是两回事，界面上说的话也不一样）。
    ///
    /// 容器留着、`ModelContext` 每次新建：上下文会把取过的对象一直注册在自己身上，
    /// 而这个进程只有大约 30MB 的余量；况且库是别的进程在写，新开一个上下文是
    /// 「保证读到的是当下这一份」最省事的办法。
    private static func loadSnapshots(limit: Int) -> [ClipSnapshot]? {
        guard let container else { return nil }
        var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = limit
        guard let items = try? ModelContext(container).fetch(descriptor) else { return nil }
        // `compactMap`：标识符编不出来的那一条没法路由复制请求，与其画一个按了没反应的格子不如不画
        return items.compactMap(ClipSnapshot.init(item:))
    }

    /// 小 1 条、中 4 条（设计 08）。其余家族用不上，按小尺寸兜底。
    private static func clipLimit(for family: WidgetFamily) -> Int {
        family == .systemMedium ? 4 : 1
    }

    // MARK: - 相对时间的阶梯

    /// 时间线用 `.never`，**内容**的更新一律靠 `WidgetRefresher` 显式 reload；
    /// 这里排的是另一件事：「刚刚」这几个字没人推也会过期，十分钟后它还写着「刚刚」。
    ///
    /// 所以把未来一小时内的整分钟时刻排成条目，WidgetKit 到点自己换一条渲染，
    /// **一次后台刷新配额都不花**——`.atEnd` / `.after` 会花，而那个配额一天只有四五十次。
    ///
    /// 只按**最新那条**的分钟边界排：每个条目渲染时四条内容的标签都会按 `entry.date` 重算一遍，
    /// 所以其余三条最多晚一分钟才换字，而「12 分钟前」晚一分钟看不出来；
    /// 真正扎眼的是最新那条从「刚刚」跳到「1 分钟前」。四条各排一份要 240 个条目，
    /// 而每个条目都得把整组快照再归档一遍。
    ///
    /// 满一小时之后标签按小时进位，不再逐分钟变，阶梯到此为止；再往后就停在最后一条上，
    /// 直到下一次库变动触发 reload。那时显示的已经是「1 小时前」这种档位，差一档也看不出来。
    private static func relativeTimeLadder(from now: Date, newest: ClipSnapshot?) -> [Date] {
        guard let newest else { return [] }
        let elapsed = max(0, now.timeIntervalSince(newest.createdAt))
        guard elapsed < ladderWindow else { return [] }
        let lastMinute = Int(ladderWindow / 60)
        return ((Int(elapsed / 60) + 1)...lastMinute).map {
            newest.createdAt.addingTimeInterval(Double($0) * 60)
        }
    }

    /// 一小时。同时也是条目数的上限（每分钟一条，最多 60 条）。
    private static let ladderWindow: TimeInterval = 60 * 60

    // MARK: - 样例

    /// 占位图用的四条。内容刻意选语言无关的（命令行、域名、色值、图片），理由见 `placeholder(in:)`。
    /// 来源色取自 design-spec 6.7 的色条色。
    private static let sampleSnapshots: [ClipSnapshot] = {
        let now = Date()
        return [
            ClipSnapshot(id: "sample-0",
                         kind: .text,
                         title: "git rebase -i HEAD~3 && git push --force-with-lease",
                         body: "git rebase -i HEAD~3 && git push --force-with-lease",
                         sourceName: "Terminal",
                         sourceColorHex: "#48484A",
                         createdAt: now.addingTimeInterval(-3 * 60),
                         isMono: true),
            ClipSnapshot(id: "sample-1",
                         kind: .link,
                         title: "developer.apple.com",
                         body: "https://developer.apple.com",
                         sourceName: "Safari",
                         sourceColorHex: "#1B8EF1",
                         createdAt: now.addingTimeInterval(-25 * 60)),
            ClipSnapshot(id: "sample-2",
                         kind: .color,
                         title: "#07C160",
                         body: "#07C160",
                         sourceName: "Figma",
                         sourceColorHex: "#07C160",
                         createdAt: now.addingTimeInterval(-48 * 60)),
            ClipSnapshot(id: "sample-3",
                         kind: .image,
                         title: "",
                         body: "",
                         sourceName: "Xcode",
                         sourceColorHex: "#8E8E93",
                         createdAt: now.addingTimeInterval(-70 * 60)),
        ]
    }()
}
