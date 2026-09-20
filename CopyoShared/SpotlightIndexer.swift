import CoreSpotlight
import CopyoCore
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Core Spotlight 索引：让历史条目能从系统搜索里找到，点开直达详情页。
///
/// 放在 `CopyoShared/` 而不是 `CopyoCore/`——`CopyoCore` 的 `Package.swift` 声明了 `.macOS(.v14)`，
/// 是跨平台代码，Mac 端不做系统索引，不该被拖进 CoreSpotlight 的依赖里。而分享扩展与
/// `SaveContentIntent` 在主应用**没有运行**时也会写入条目，它们必须够得着这里。
///
/// **这个开关默认关闭，而且只能默认关闭。** 剪贴板历史里躺着验证码（设计稿自带的样例内容就是
/// 「【抖音】验证码 482913」）、密码和私聊片段。一旦索引，它们会出现在主屏下拉搜索、锁屏搜索
/// 甚至 Siri 建议里——那是用户完全没预料到的暴露面，只能由用户自己按下开关，
/// 设置页的说明文案也必须把这件事说破。
///
/// 选型（均已定案，不再翻案）：
/// - 用 `CSSearchableIndex` 而不是 `NSUserActivity`：后者一次只登记「刚看过的那一条」，
///   既没有删除接口也没有批量路径，做不了「整库可搜 + 删一条撤一条」。
/// - 用 `CSSearchableIndex` 而不是 `CSUserQuery`：那是查询侧的东西，而应用内搜索刚用
///   `#Predicate` + 防抖修好（见 `ClipQuery`），两件事不要搅在一起。
public enum SpotlightIndexer {

    /// 全部条目共用一个域，`deleteSearchableItems(withDomainIdentifiers:)` 因此能一次粗粒度清场
    public static let domainIdentifier = "dev.vibemage.Copyo.clips"

    // MARK: - 总闸

    /// 演示 / 截图模式的总闸，由 `CopyoIOSApp.init` 在建库之前合上。
    ///
    /// **不能靠读设置来挡**：`-demoData` 下 `IOSSettings.defaults` 换成了一次性的演示 suite，
    /// 而这里读的 `CopyoAppGroup.defaults` 仍是真实 suite，两边根本不是同一份值——截图跑的是
    /// 假数据，读到的却是开发者本人的开关。一旦放行，十几条样例条目（含那条验证码）会被写进
    /// **开发者本人**的 Spotlight 索引，并在截图进程退出后继续留在那里。
    /// 与 `AppModel.handleScenePhaseActive()` / `AppModel.feedback(_:)` 是同一条门禁。
    public static var isSuspended = false

    public static var isEnabled: Bool {
        !isSuspended && CopyoAppGroup.spotlightIndexingEnabled
    }

    // MARK: - 唯一标识

    /// 用编码后的 `PersistentIdentifier` 当 `uniqueIdentifier`，**不给 `ClipItem` 加搜索用的新字段**：
    /// 加一列就是一次 CloudKit schema 变更，而 `iCloud.dev.vibemage.Copyo` 的 Production schema
    /// 已于 2026-09-20 部署、Mac 1.0 正拿它在审核中（docs/appstore-submission.md §二十一），
    /// Production schema 只能增不能改，改了已上架版本就与新版本对不上。
    ///
    /// 代价：这个标识只在**同一个 store 文件**内稳定，重装、重建库、`-demoData` 的内存容器
    /// 都会换一批。换代由 `reconcile` 里的 store 令牌兜住。
    ///
    /// **`.sortedKeys` 是必需的，不是洁癖。** `PersistentIdentifier` 把五个子键编进一个字典，
    /// 而 Swift 的字典遍历顺序按进程随机化：同一个进程里每次编码结果一致，**换一次进程就换一种顺序**。
    /// 实测连开六次进程，六种顺序（`uriRepresentation>isTemporary>primaryKey>…`、
    /// `primaryKey>entityName>…`…），加上 `.sortedKeys` 后六次完全一致。
    ///
    /// 不加的后果不是偶发而是必然，而且三条都不会报错：
    /// 1. **撤索引永远失效**——索引是上次启动写的，删除在这次启动发起，两个字符串对不上，
    ///    `deleteSearchableItems(withIdentifiers:)` 一条也删不掉。用户删掉的验证码、密码
    ///    会继续留在主屏下拉与锁屏搜索里，直到 30 天后自己过期。这正是设置页文案承诺不会发生的事。
    /// 2. **重复条目**——重新索引同一条会写成一个新 `uniqueIdentifier` 而不是覆盖，一条剪贴板
    ///    在系统搜索里出现好几遍。
    /// 3. **每次 reconcile 全量重建**——账本里是上次启动的字符串，比对出来「整库都是新增、
    ///    整本账都要撤销」，提前返回的那道 guard 形同虚设。
    private static let identifierEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    public static func identifier(for id: PersistentIdentifier) -> String? {
        guard let data = try? identifierEncoder.encode(id) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Spotlight 结果回传的标识符 → `PersistentIdentifier`。解不出来就是旧代的标识符（换过 store），
    /// 调用方按「这条已经不在了」处理。
    public static func modelID(from identifier: String) -> PersistentIdentifier? {
        guard let data = identifier.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }

    // MARK: - 增量

    /// 新增或内容已变的条目。
    ///
    /// 去重命中的 `.refreshed` 分支**也要走这里**：它原地改了 `createdAt`（文本类还会改
    /// `rtfData` / `kindRaw`），索引里那一份的正文与时间已经过期了，跳过它等于让系统搜索
    /// 停在旧内容上。
    public static func index(_ items: [ClipItem]) {
        guard isEnabled, !items.isEmpty else { return }
        submit(items.compactMap(searchableItem(for:)))
    }

    public static func index(_ item: ClipItem) {
        index([item])
    }

    /// 撤索引。标识符必须在 `context.delete` **之前**取好——`try context.save()` 之后
    /// `persistentModelID` 再也取不回来，那些条目就成了点不开的孤儿。
    public static func remove(_ ids: [PersistentIdentifier]) {
        remove(identifiers: ids.compactMap(identifier(for:)))
    }

    /// 删除**不看 `isEnabled`**：用户可能刚把开关关掉、而某条删除紧跟其后，
    /// 这时候多删一次是无害的，少删一次留下的却是用户明确不想再被搜到的内容。
    /// 演示模式仍然要挡，那一路根本不该碰真实索引。
    public static func remove(identifiers: [String]) {
        guard !isSuspended, !identifiers.isEmpty else { return }
        // 与 `submit` 同样切块：「清空历史」和对账撤掉整代旧标识符时，这个数组可能有几千条
        for start in stride(from: 0, to: identifiers.count, by: chunkSize) {
            let chunk = Array(identifiers[start..<min(start + chunkSize, identifiers.count)])
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: chunk) { _ in }
        }
    }

    // MARK: - 开关

    /// 关掉开关时清空索引。「以后不再加」**不等于**「现在看不到」——用户按下这一下的动机
    /// 就是不想让验证码再出现在锁屏搜索里，留着存量等于没关。
    /// 账本一并清掉，下次打开走整库重建。
    public static func disable() {
        guard !isSuspended else { return }
        CSSearchableIndex.default().deleteAllSearchableItems { _ in }
        Ledger.clear()
    }

    // MARK: - 对账

    /// 增量钩子**单靠自己不可能保持正确**：CloudKit 镜像进来的新增与删除在应用这一侧
    /// 根本没有调用点——在 Mac 上复制一条、或删掉一条，到了 iPhone 只是一次镜像变更，
    /// 没有任何函数会被调到。所以冷启动与节流后的回前台都要把库里的实际内容和账本对一遍。
    ///
    /// 三条分支：
    /// 1. store 令牌变了（重装 / 重建库 / 换成内存容器）——旧标识符一条都解析不回来，
    ///    全清后重建。
    /// 2. 账本太旧——条目带着 30 天过期时间，活着的必须在那之前整体重写一次续期，
    ///    见 `refreshInterval`。
    /// 3. 其余情况只补差集：多出来的索引上，账本上有而库里没有的撤掉。
    /// 返回值是「这一趟有没有完整跑完」。调用方用它决定要不要记下「已对账」的时刻——
    /// 中途被取消时账本没有写全，记成功会让节流窗口把没建完的那一截一直挡在外面。
    @MainActor
    @discardableResult
    public static func reconcile(in context: ModelContext) async -> Bool {
        guard isEnabled else { return false }
        let items = (try? context.fetch(FetchDescriptor<ClipItem>())) ?? []

        // 空库（用户刚清空历史、或这台设备还没同步到东西）：账本上记着的一律撤掉。
        // 没有条目就取不到 store 令牌，所以这一支提前返回，令牌留到下次有内容时再写。
        guard let token = items.first?.persistentModelID.storeIdentifier else {
            remove(identifiers: Array(Ledger.identifiers))
            Ledger.identifiers = []
            return true
        }

        let generationChanged = Ledger.storeToken != token
        let dueForRefresh = Ledger.indexedAt.map { Date().timeIntervalSince($0) > refreshInterval } ?? true

        var current: [String: ClipItem] = [:]
        for item in items {
            guard let id = identifier(for: item.persistentModelID) else { continue }
            current[id] = item
        }
        let recorded = Ledger.identifiers
        let removed = recorded.subtracting(current.keys)

        if generationChanged {
            // **必须等它做完再重建**：`deleteAllSearchableItems` 是异步的，不等的话
            // 这一轮刚写进去的条目会被上一条清场指令顺手抹掉，表现是「开了开关却什么都搜不到」。
            await deleteAll()
        }
        if generationChanged || dueForRefresh {
            // 续期这一支也要先把「账本上有、库里已经没有」的撤掉。
            // `reindex` 结束时会把账本整个换成库里的现状，那之后这批标识符就再也找不回来了——
            // 而它们**只可能**由对账撤销：Mac 上删掉、镜像同步过来的那些条目，在本机没有任何删除钩子。
            // 漏在这里的后果是那条内容一直留在锁屏搜索里，直到它自己 30 天过期。
            // 换代那一支不必管：`deleteAll()` 已经把整个索引清空了。
            if !generationChanged {
                remove(identifiers: Array(removed))
            }
            return await reindex(items, token: token)
        }

        let added = Set(current.keys).subtracting(recorded)
        guard !added.isEmpty || !removed.isEmpty else { return true }
        remove(identifiers: Array(removed))
        submit(added.compactMap { current[$0] }.compactMap(searchableItem(for:)))
        Ledger.identifiers = Set(current.keys)
        return true
    }

    /// 整库重建。分批构造并在批与批之间让出主线程：`attributeSet` 要逐条读正文，
    /// 上万条的库一口气走完会把那一帧卡死（这次重建通常就发生在冷启动或刚打开开关的时候）。
    @MainActor
    private static func reindex(_ items: [ClipItem], token: String) async -> Bool {
        var indexed: Set<String> = []
        var chunk: [CSSearchableItem] = []
        for item in items {
            guard let searchable = searchableItem(for: item) else { continue }
            indexed.insert(searchable.uniqueIdentifier)
            chunk.append(searchable)
            guard chunk.count >= chunkSize else { continue }
            submit(chunk)
            chunk.removeAll(keepingCapacity: true)
            await Task.yield()
            // 中途被取消（用户又把开关关了）就**不写账本**：写了会让下次对账以为整库都在索引里，
            // 于是永远补不上没建完的那一截。
            if Task.isCancelled { return false }
        }
        submit(chunk)
        Ledger.identifiers = indexed
        Ledger.storeToken = token
        Ledger.indexedAt = Date()
        return true
    }

    /// 显式写出 `CheckedContinuation<Void, Never>`：只靠 `resume()` 推断返回类型，
    /// 编译器要从一个 `where T == Void` 的扩展方法倒推泛型参数，不是稳定的推断路径。
    private static func deleteAll() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            CSSearchableIndex.default().deleteAllSearchableItems { _ in continuation.resume() }
        }
    }

    // MARK: - 条目构造

    private static func searchableItem(for item: ClipItem) -> CSSearchableItem? {
        guard let id = identifier(for: item.persistentModelID) else { return nil }
        let searchable = CSSearchableItem(uniqueIdentifier: id,
                                          domainIdentifier: domainIdentifier,
                                          attributeSet: attributeSet(for: item))
        // 兜底过期。孤儿迟早会有：CloudKit 在应用没运行时镜像掉一条、或进程在 delete 与撤索引
        // 之间被杀，都会留下一条库里没有、索引里有的记录。没有这一条它们会永远留在系统搜索里，
        // 点开只能得到一句「这条不在了」。活着的条目由 `reconcile` 在到期前整体续期。
        searchable.expirationDate = Date().addingTimeInterval(expirationInterval)
        return searchable
    }

    private static func attributeSet(for item: ClipItem) -> CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        // `CopyoCore` 的 `displayTitle` 对图片**故意**返回空串，本地化留给调用方
        // （iOS 侧是 `ClipItem+Display` 的 `displayTitleLocalized`）。这里取的
        // 「图片」与 `KindPresentation.label(.image)` 是同一个键，三份目录里都有，
        // 三个进程拿到的译文一致。
        let title = item.displayTitle
        attributes.title = title.isEmpty ? String(localized: "Image") : title
        attributes.contentDescription = searchBody(of: item)
        attributes.contentCreationDate = item.createdAt
        attributes.keywords = keywords(for: item)
        // **图片条目不塞 thumbnailData**：`ClipItem.imageData` 是 `@Attribute(.externalStorage)`，
        // `CopyoIOS/Model/ClipItem+Display.swift` 记着 Mac 同步来的一张 5K 截图解码后约 59MB，
        // 整库跑一遍必然先被 jetsam 掉。图片靠标题与时间也找得到。
        return attributes
    }

    /// 索引正文，截到 1000 字。`ClipCard` 渲染本来也只取 600 字，而把一条 100KB 的文本
    /// × 500 条整个塞进索引纯属浪费——Spotlight 也不会拿整篇正文去匹配一个关键词。
    private static func searchBody(of item: ClipItem) -> String? {
        let body = (item.plainText ?? item.displayTitle).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        return String(body.prefix(descriptionLimit))
    }

    /// 关键词只放「正文里搜不到、但用户会拿它找东西」的那几项：固定到的 Pinboard 名、
    /// Mac 端带过来的来源 App 名、链接域名。类型名不放——`richText` 这种原始值是英文标识符。
    ///
    /// 板名进了索引，板的归属一变这一条就过期了，所以 `AppModel` 的 `pin` / `unpin` /
    /// `delete(_ board:)` 三处都要重索引。**重命名 Pinboard 目前没有钩子**
    /// （`PinboardContentScreen` 直接改 `board.name`），那一批条目的板名关键词会旧到下一次
    /// 整体续期为止；不影响正文命中，只是按旧板名也能搜到。
    private static func keywords(for item: ClipItem) -> [String] {
        var words: [String] = []
        if let board = item.pinboard?.name, !board.isEmpty { words.append(board) }
        if let source = item.sourceAppName, !source.isEmpty { words.append(source) }
        if let domain = item.linkDomain, !domain.isEmpty { words.append(domain) }
        return words
    }

    /// 默认索引**不支持批次**（`beginIndexBatch` / `endIndexBatch` 只对自建索引有效），
    /// 一次提交多少就是一次多大的 IPC，所以在这里统一切成 100 条一块——
    /// CloudKit 一口气镜像进来几千条时，增量那条路同样会撞上这个上限。
    private static func submit(_ items: [CSSearchableItem]) {
        guard !items.isEmpty else { return }
        for start in stride(from: 0, to: items.count, by: chunkSize) {
            let chunk = Array(items[start..<min(start + chunkSize, items.count)])
            CSSearchableIndex.default().indexSearchableItems(chunk) { _ in
                // 索引失败只影响系统搜索，历史本身一条不少，不值得为此打扰用户；
                // 下一次对账会把漏掉的补回去。
            }
        }
    }

    // MARK: - 常量

    private static let descriptionLimit = 1_000
    private static let chunkSize = 100
    /// 30 天。只是孤儿的兜底期限，不是「条目只能被搜 30 天」
    private static let expirationInterval: TimeInterval = 30 * 24 * 60 * 60
    /// 14 天整体续期一次。必须**明显短于** `expirationInterval`：晚了的话活着的条目会先过期
    /// 从索引里消失，而账本还记着「已索引」，增量差分算出来的新增是空集，永远补不回来。
    private static let refreshInterval: TimeInterval = 14 * 24 * 60 * 60

    // MARK: - 账本

    /// 「我认为索引里现在有哪些条目」的快照，落在 App Group 的 suite 里。
    ///
    /// 只由 `reconcile` / `reindex` / `disable` 写，**增量的 index / remove 一律不动它**：
    /// 两种漂移都能自愈且幂等——增量加进去而账本没记的，下次对账当成新增再写一遍（重复索引
    /// 同一个 uniqueIdentifier 就是覆盖）；增量删掉而账本还记着的，下次对账再发一次删除。
    /// 反过来每存一条就重写一遍几百 KB 的数组，才是真的代价。
    ///
    /// 体量：一条编码后的 `PersistentIdentifier` 约 260 字节，默认上限 500 条约 130KB。
    /// 历史上限设成「不限」且真的攒到上万条时这份数组会长到数 MB，那是这个方案的已知上界。
    private enum Ledger {
        static let identifiersKey = "spotlightIndexedIDs"
        static let storeTokenKey = "spotlightStoreToken"
        static let indexedAtKey = "spotlightIndexedAt"

        static var identifiers: Set<String> {
            get { Set(CopyoAppGroup.defaults.stringArray(forKey: identifiersKey) ?? []) }
            set { CopyoAppGroup.defaults.set(Array(newValue), forKey: identifiersKey) }
        }

        /// store 的身份，取自任意一条的 `persistentModelID.storeIdentifier`。
        /// 与上次不同就说明换了库文件，旧标识符全作废。
        static var storeToken: String? {
            get { CopyoAppGroup.defaults.string(forKey: storeTokenKey) }
            set { CopyoAppGroup.defaults.set(newValue, forKey: storeTokenKey) }
        }

        /// 上一次**整库**重建的时刻，增量对账不更新它
        static var indexedAt: Date? {
            get { CopyoAppGroup.defaults.object(forKey: indexedAtKey) as? Date }
            set { CopyoAppGroup.defaults.set(newValue, forKey: indexedAtKey) }
        }

        static func clear() {
            CopyoAppGroup.defaults.removeObject(forKey: identifiersKey)
            CopyoAppGroup.defaults.removeObject(forKey: storeTokenKey)
            CopyoAppGroup.defaults.removeObject(forKey: indexedAtKey)
        }
    }
}
