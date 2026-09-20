import CopyoCore
import Foundation
import Observation
import SwiftData

/// 键盘这一侧的共享库读取端。**只读，没有任何写路径。**
///
/// 键盘不做「最近使用」记账、不重排、不去重。它写进去的东西在主应用下次启动之前上不了
/// CloudKit，还会和主应用自己的排序打架；而「不许写」这条约束不靠每个调用点自觉，
/// 交给 SwiftData 去保证——容器是 `allowsSave: false` 打开的，理由见
/// `CopyoStore.makeContainer(url:cloudKit:allowsSave:)`。
@MainActor
@Observable
final class KeyboardClipStore {

    /// 界面要画哪一种。四档之间的话是不一样的，不能合并。
    enum State: Equatable {
        /// 还没读过。第一次 `reload()` 之前的那一帧
        case loading
        /// 读到了。空数组 = 库是空的（与读不到是两回事）
        case ready([KeyboardClip])
        /// 够不着 App Group 容器 → 设计 07b 未授权态
        case needsFullAccess
        /// 容器够得着，但库打不开或读不出来 → 「打开 Copyo 后再试」
        case libraryUnreadable
    }

    private(set) var state: State = .loading

    /// **必须留住。** `ModelContext` 不持有容器，容器一被释放，它取出来的对象全部失效；
    /// `CopyoShareExtension/ShareViewController.swift` 的 `ShareSession` 记着同一个坑。
    /// 留住它还有第二个好处：建容器要读 schema、开 SQLite，键盘每次出现都重来一遍是白花的开销。
    private var container: ModelContainer?

    /// 一次取多少条。
    ///
    /// 卡片条一屏放得下两张半（168 + 8 的间距，440 画布上不到 3 张），40 条够横向滑很久了。
    /// 更要紧的是这是一道内存闸门：`plainText` 是普通属性，`fetch` 会把命中条目的全文
    /// 一并载入，而键盘的 jetsam 预算按 30MB 规划（见 `KeyboardClip`）。
    private static let fetchLimit = 40

    // MARK: - 取数

    /// 重新取一遍。**在 `viewWillAppear` 调，不是在 `viewDidLoad` 调**：
    /// 键盘一次出现很短，而两次出现之间用户完全可能在别处复制了新内容——
    /// 只在加载时取一次的表现是「刚复制完切到键盘，最上面那张还是上一条」。
    ///
    /// **同步跑，不开异步。** 代价是第一次出现时主线程上要开一次 SQLite；换来的是
    /// 键盘出现的第一帧上卡片就已经在那儿了。异步的话第一帧一定是空的、随后弹入，
    /// 而键盘的一次出现本来就只有一两秒，那一下闪动占掉的正是用户看它的全部时间。
    /// 容器只建一次（见 `openedContainer()`），之后每次出现只剩一次 40 行的 fetch。
    /// 真机上要量一次首次出现的耗时——键盘有看门狗，这条路上卡住的表现是直接被杀。
    func reload() {
        do {
            let container = try openedContainer()
            var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            descriptor.fetchLimit = Self.fetchLimit
            // 上下文**每次新建、用完就丢**。上下文会把取过的对象一直注册在自己身上，
            // 而这些对象的 `plainText` 可能很大；摊成 `KeyboardClip` 之后上下文离开作用域，
            // 那批 `ClipItem` 连同它们的字符串一起被放掉，只留下界面真正要画的那份。
            // 况且库是别的进程在写，新开一个上下文也是「读到的就是当下这一份」最省事的办法。
            let context = ModelContext(container)
            state = .ready(try context.fetch(descriptor).map(KeyboardClip.init(item:)))
        } catch let error as CopyoStore.StoreError {
            // 穷举而不是 `default`：以后 `StoreError` 多一个 case，这里会编译不过，
            // 而不是悄悄把一种新的失败当成「没开完全访问」报给用户
            switch error {
            case .appGroupUnavailable:
                // **这就是「没开允许完全访问」的判据。** 没有任何 API 能问「完全访问给了吗」，
                // 只能看行为：没开时 `containerURL(forSecurityApplicationGroupIdentifier:)`
                // 返回 nil，于是 `appGroupStoreURL()` 抛这个错。
                // 同一个错也可能是 App Group capability 配错了，但那是开发期的事，
                // 用户手上拿到的包里，这个错**只有**一种成因。
                state = .needsFullAccess
            }
        } catch {
            // 只读打开也可能抛：库还不存在（用户装完从没开过 Copyo）、或者真正只读的 SQLite
            // 在 WAL 需要恢复时拒绝打开、或者 schema 变了而只读配置不做迁移——
            // 最后这一条正是我们要的：宁可在这里失败，也不要在键盘那点内存和看门狗时限里
            // 迁移到一半被杀。三种成因对用户是同一句话：先去打开一次 Copyo。
            state = .libraryUnreadable
        }
    }

    /// 内存告警。键盘是所有扩展点里预算最紧的，被杀掉在用户眼里就是「键盘坏了」，
    /// 而且没有任何崩溃上报面能看到。
    ///
    /// 放掉**容器**（连同 Core Data 自己的行缓存与那份 SQLite 连接），但**留着已经摊好的快照**：
    /// 快照是纯值类型，不依赖容器也不会 fault，此刻用户正看着它们，清空等于当着人的面把卡片抹掉。
    /// 下一次 `reload()` 会重新开一次库。
    func handleMemoryWarning() {
        container = nil
    }

    // MARK: - 容器

    private func openedContainer() throws -> ModelContainer {
        if let container { return container }
        // `cloudKit: false` 在这里和小组件一样是硬性要求：`CopyoKeyboard.entitlements` 里
        // 只有 App Group，没有 iCloud 容器也没有 `aps-environment`，挂镜像的配置直接抛错。
        // 键盘写进去的东西本来也上不了 CloudKit——不过这块键盘根本不写，见本类开头。
        let container = try CopyoStore.makeContainer(url: try CopyoStore.appGroupStoreURL(),
                                                     cloudKit: false,
                                                     allowsSave: false)
        self.container = container
        return container
    }
}
