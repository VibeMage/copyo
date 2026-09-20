import AppKit
import CopyoCore
import SwiftData

/// 通过 iCloud Drive 文件夹在多台 Mac 之间同步剪贴板历史。
///
/// 每台设备把自己的历史快照写成 `device-<id>.json`（图片放 `assets/<hash>.png`），
/// 并定期合并其他设备的快照。快照式同步不传播删除：本地删掉的旧条目不会复活，
/// 因为每台设备只导入比上次同步游标更新的条目。
@MainActor
final class SyncService {
    private let context: ModelContext
    private var timer: Timer?

    private static let deviceIDKey = "syncDeviceID"
    private static let cursorsKey = "syncCursors"
    private static let pastDeviceIDsKey = "syncPastDeviceIDs"

#if APPSTORE
    /// 当前计时器正在同步的目录，用于识别「用户中途换了文件夹」
    private var activeRoot: URL?
#endif

    init(context: ModelContext) {
        self.context = context
        // 每次启动把当前标识记进「本机用过的标识」，理由见 knownDeviceIDs
        Self.registerCurrentDeviceID()
    }

    /// 本机用过的所有设备标识。syncDeviceID 丢了就会重新生成一个（配置被重置、换了
    /// 用户账户、偏好文件只恢复了一半），而旧的 device-<id>.json 是本机写进去的、
    /// 装着上限 500 条的明文。自跳过是文件名子串判断，换了 UUID 之后那份就不再被认成
    /// 「自己的」：导入时会把本机刚删掉的历史原样读回来，擦除时也漏掉不删。
    static var knownDeviceIDs: Set<String> {
        var ids = Set(UserDefaults.standard.stringArray(forKey: pastDeviceIDsKey) ?? [])
        ids.insert(deviceID)
        return ids
    }

    private static func registerCurrentDeviceID() {
        let defaults = UserDefaults.standard
        var ids = defaults.stringArray(forKey: pastDeviceIDsKey) ?? []
        let current = deviceID
        guard !ids.contains(current) else { return }
        ids.append(current)
        defaults.set(ids, forKey: pastDeviceIDsKey)
    }

    // MARK: - 目录与设备标识

    static var deviceID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: deviceIDKey) { return existing }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: deviceIDKey)
        return fresh
    }

#if APPSTORE
    /// 沙盒里进程只能访问用户亲自选过的目录，路径字符串一律无效。
    /// 设置页用 NSOpenPanel 取得授权后存下安全作用域书签，这里再解析回 URL。
    static let bookmarkKey = "syncFolderBookmark"
    /// 上次同步成功的时间（timeIntervalSince1970），设置页用 @AppStorage 直接读
    static let lastSyncedAtKey = "syncLastSyncedAt"
    /// 上次同步失败的原因，空串表示没有失败
    static let lastErrorKey = "syncLastError"

    /// 沙盒同步的失败几乎只有一种：目录访问权没了（文件夹被删、外置卷未挂载、
    /// iCloud 条目被清理、书签彻底失效）。这类失败完全静默，不记下来的话
    /// 设置页会一直显示「同步正常」，而实际上一个字节都没写出去。
    enum SyncFailure: String {
        case noAccess
    }

    static var syncRoot: URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                 options: [.withSecurityScope],
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &isStale) else { return nil }
        // 书签能解析不代表还能访问：拿不到安全作用域时必须报告「没有同步目录」，
        // 否则设置页会永远显示旧路径 + 开着的开关，而每一轮同步都在这里静默退出。
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        // 目录被改名或移动后书签会变「陈旧」：趁现在还能解析，立刻换成新书签，
        // 否则下次启动就彻底失去访问权，用户得重新选一遍文件夹。
        if isStale, let refreshed = try? url.bookmarkData(options: .withSecurityScope,
                                                          includingResourceValuesForKeys: nil,
                                                          relativeTo: nil) {
            UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
        }
        return url
    }

    private static func recordSuccess() {
        let defaults = UserDefaults.standard
        defaults.set(Date().timeIntervalSince1970, forKey: lastSyncedAtKey)
        // 30 秒一轮，稳态下不做无谓的写入
        if defaults.string(forKey: lastErrorKey)?.isEmpty == false {
            defaults.set("", forKey: lastErrorKey)
        }
    }

    private static func recordFailure(_ failure: SyncFailure) {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: lastErrorKey) != failure.rawValue else { return }
        defaults.set(failure.rawValue, forKey: lastErrorKey)
    }
#else
    /// 同步目录的父目录：默认 iCloud Drive。设置里填了自定义路径时，那个路径本身
    /// 就是同步目录（不再往下加一层 `Copyo/`），这种情况返回 nil。
    static var syncContainer: URL? {
        guard (UserDefaults.standard.string(forKey: "syncFolderOverride") ?? "").isEmpty else { return nil }
        let icloudDrive = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        guard FileManager.default.fileExists(atPath: icloudDrive.path) else { return nil }
        return icloudDrive
    }

    /// 同步目录：默认 iCloud Drive/Copyo；也可在设置中改为任意共享文件夹
    /// （公司 NAS、Dropbox 等——只要多台设备都能读写同一目录即可同步）。
    /// 纯计算，不建目录：同步关着的时候设置页也会读它。
    static var syncRoot: URL? {
        if let custom = UserDefaults.standard.string(forKey: "syncFolderOverride"),
           !custom.isEmpty {
            let url = URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path) else { return nil }
            return url
        }
        guard let container = syncContainer else { return nil }
        return SyncFolderLayout.root(in: container)
    }
#endif

    static var isAvailable: Bool { syncRoot != nil }

    /// 只有「文件夹」这一种同步方式会用到本服务；关闭与 iCloud 方式下计时器必须停住，
    /// 否则 iCloud 同步的删除刚生效就会被快照重新导入回来。
    ///
    /// cloudKitActive 也要看：容器是启动时建的，从 iCloud 切到文件夹又没重启时，方式
    /// 已经是 folder，而这次会话的容器仍然挂着 CloudKit 镜像——两套同步一起跑正是
    /// 上面那句要避免的。设置页现在会在这种切换时当场拦下并回退选择器，所以这个状态
    /// 正常走不到；这一条留着，因为它才是这个不变式本身。
    var isEnabled: Bool {
        SyncMode.current == .folder && AppDelegate.shared?.cloudKitActive != true
    }

    // MARK: - 生命周期

    func updateActivation() {
#if APPSTORE
        let root = Self.syncRoot
        // 用户换了同步文件夹时必须重启计时器：start() 在计时器已存在时直接返回，
        // 否则新目录要等到下一个 30s 周期才生效。
        if timer != nil, root != activeRoot {
            stop()
        }
        activeRoot = root
        let available = root != nil
#else
        let available = Self.isAvailable
#endif
        if isEnabled && available {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard timer == nil else { return }
        syncNow()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncNow()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    func syncNow() {
        guard isEnabled else { return }
#if APPSTORE
        guard let picked = Self.syncRoot else {
            Self.recordFailure(.noAccess)
            return
        }
        // 安全作用域必须成对开关：每轮同步开始前申请，结束后立即归还，
        // 否则句柄会一直累积，最终连自己都拿不到访问权。
        guard picked.startAccessingSecurityScopedResource() else {
            Self.recordFailure(.noAccess)
            return
        }
        defer { picked.stopAccessingSecurityScopedResource() }
        // 用户可能选的是 iCloud Drive 根目录或公司共享盘，绝不能把 device-*.json
        // 和 assets/ 直接摊在别人的目录里。安全作用域覆盖子路径，无需第二个书签。
        let root = SyncFolderLayout.prepareRoot(in: picked)
        let legacyRoot = SyncFolderLayout.legacyRoot(in: picked)
#else
        let root: URL
        let legacyRoot: URL?
        if let container = Self.syncContainer {
            // 先改名再找旧目录，顺序颠倒的话 legacyRoot 指的是刚被改掉的那个
            root = SyncFolderLayout.prepareRoot(in: container)
            legacyRoot = SyncFolderLayout.legacyRoot(in: container)
        } else {
            // 设置里填了自定义目录：那个路径本身就是同步目录，名字由用户定，不改
            guard let custom = Self.syncRoot else { return }
            root = custom
            legacyRoot = nil
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
#endif
        let assets = root.appendingPathComponent("assets", isDirectory: true)
        try? FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        exportSnapshot(to: root, assets: assets)
        importSnapshots(from: root, assets: assets)
        // 还没升级到 Copyo 的 Mac 会把 Paster/ 重新建起来并继续往里写快照，
        // 这段窗口期里只读地再合并一次，免得那台设备的新条目到不了这边。
        if let legacyRoot, legacyRoot != root {
            importSnapshots(from: legacyRoot,
                            assets: legacyRoot.appendingPathComponent("assets", isDirectory: true))
        }
#if APPSTORE
        Self.recordSuccess()
#endif
    }

    // MARK: - 快照格式

    private struct SyncItem: Codable {
        var identity: String
        var kindRaw: String
        var plainText: String?
        var rtfBase64: String?
        var imageHash: String?
        var filePaths: [String]
        var sourceAppBundleID: String?
        var sourceAppName: String?
        var createdAt: Date
        var pinboardName: String?
    }

    private struct SyncSnapshot: Codable {
        var deviceID: String
        var exportedAt: Date
        var pinboards: [String]
        var items: [SyncItem]
    }

    /// 内容指纹：跨设备判断「同一条内容」
    static func identity(of item: ClipItem) -> String {
        switch item.kind {
        case .image:
            return "i:" + (item.imageHash ?? "")
        case .file:
            return "f:" + ContentHash.sha256(Data(item.filePaths.joined(separator: "\n").utf8))
        default:
            return "t:" + ContentHash.sha256(Data((item.plainText ?? "").utf8))
        }
    }

    // MARK: - 导出

    private func exportSnapshot(to root: URL, assets: URL) {
        var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 500
        guard let items = try? context.fetch(descriptor) else { return }
        let pinboards = (try? context.fetch(FetchDescriptor<Pinboard>())) ?? []

        let syncItems: [SyncItem] = items.map { item in
            if item.kind == .image, let hash = item.imageHash {
                let assetURL = assets.appendingPathComponent("\(hash).png")
                if !FileManager.default.fileExists(atPath: assetURL.path), let data = item.imageData {
                    try? data.write(to: assetURL)
                }
            }
            return SyncItem(identity: Self.identity(of: item),
                            kindRaw: item.kindRaw,
                            plainText: item.plainText,
                            rtfBase64: item.rtfData?.base64EncodedString(),
                            imageHash: item.imageHash,
                            filePaths: item.filePaths,
                            sourceAppBundleID: item.sourceAppBundleID,
                            sourceAppName: item.sourceAppName,
                            createdAt: item.createdAt,
                            pinboardName: item.pinboard?.name)
        }

        let snapshot = SyncSnapshot(deviceID: Self.deviceID,
                                    exportedAt: Date(),
                                    pinboards: pinboards.map(\.name),
                                    items: syncItems)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        let target = root.appendingPathComponent("device-\(Self.deviceID).json")
        try? data.write(to: target, options: .atomic)
    }

    /// 「删除所有数据」对同步文件夹的收尾结果
    enum EraseResult {
        /// 当前不是文件夹同步，没有要清的东西
        case notApplicable
        /// 本机写进去的快照和图片都删掉了
        case erased
        /// 够不着同步目录（书签失效、卷没挂载、目录被删、iCloud Drive 没开）。
        /// 对话框已经说了「会删掉」，所以这个必须报出来，绝不能静默当成成功。
        case noAccess
    }

    /// 删掉本机写进同步文件夹的快照，以及这些快照引用到的图片。
    ///
    /// 只删本机自己的那几份（当前标识 + 用过的旧标识）：别的设备的 device-*.json 是
    /// 人家的数据，删了对方下一轮还会原样写回来。所以同步文件夹永远不可能被这个按钮
    /// 清干净，确认框必须照实说。
    ///
    /// 图片哈希取自快照文件本身而不是本地行：被 trimHistory 清掉过的老图片在库里
    /// 已经没有对应条目，只有快照里还记着它们的哈希——只按本地行算会漏掉绝大多数。
    /// assets/ 是按内容哈希命名、多台设备共用的，所以这里可能删掉别的设备也引用着的
    /// 那一份；对方下一轮 exportSnapshot 的 fileExists 判断会把它重新写出来，而导入端的
    /// 游标已经改成「资产缺失就不前进」，所以不会有设备因此永久丢图。
    func eraseExportedSnapshot(extraImageHashes: Set<String>) -> EraseResult {
        guard SyncMode.current == .folder else { return .notApplicable }
        let fileManager = FileManager.default
        let roots: [URL]
#if APPSTORE
        guard let picked = Self.syncRoot, picked.startAccessingSecurityScopedResource() else {
            Self.recordFailure(.noAccess)
            return .noAccess
        }
        defer { picked.stopAccessingSecurityScopedResource() }
        // 用 root(in:) 而不是 prepareRoot(in:)：擦除的时候不该顺手把目录建出来
        roots = [SyncFolderLayout.root(in: picked),
                 SyncFolderLayout.legacyRoot(in: picked)].compactMap { $0 }
#else
        if let container = Self.syncContainer {
            roots = [SyncFolderLayout.root(in: container),
                     SyncFolderLayout.legacyRoot(in: container)].compactMap { $0 }
        } else if let custom = Self.syncRoot {
            roots = [custom]
        } else {
            return .noAccess
        }
#endif
        let mine = Self.knownDeviceIDs
        var reachedAll = true
        for root in roots {
            // 目录压根不存在 = 没什么可删的，不算失败
            guard fileManager.fileExists(atPath: root.path) else { continue }
            guard let files = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
                reachedAll = false
                continue
            }
            var hashes = extraImageHashes
            let assets = root.appendingPathComponent("assets", isDirectory: true)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            for file in files where file.lastPathComponent.hasPrefix("device-") && file.pathExtension == "json" {
                let name = file.lastPathComponent
                guard mine.contains(where: { name.contains($0) }) else { continue }
                if let data = try? Data(contentsOf: file),
                   let snapshot = try? decoder.decode(SyncSnapshot.self, from: data) {
                    hashes.formUnion(snapshot.items.compactMap(\.imageHash))
                }
                try? fileManager.removeItem(at: file)
            }
            for hash in hashes {
                try? fileManager.removeItem(at: assets.appendingPathComponent("\(hash).png"))
            }
        }
        guard reachedAll else {
#if APPSTORE
            Self.recordFailure(.noAccess)
#endif
            return .noAccess
        }
        return .erased
    }

    // MARK: - 导入合并

    private func importSnapshots(from root: URL, assets: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var cursors = (UserDefaults.standard.dictionary(forKey: Self.cursorsKey) as? [String: Double]) ?? [:]
        var localIdentities: Set<String>? // 惰性构建，多数轮询没有新内容
        // 不只跳过当前标识：本机换过 UUID 时那份孤儿快照也是自己的
        let mine = Self.knownDeviceIDs

        for file in files where file.lastPathComponent.hasPrefix("device-") && file.pathExtension == "json" {
            let name = file.lastPathComponent
            guard !mine.contains(where: { name.contains($0) }),
                  let data = try? Data(contentsOf: file),
                  let snapshot = try? decoder.decode(SyncSnapshot.self, from: data) else { continue }

            let cursor = cursors[snapshot.deviceID].map { Date(timeIntervalSince1970: $0) } ?? .distantPast
            let fresh = snapshot.items.filter { $0.createdAt > cursor }
            guard !fresh.isEmpty else {
                advance(&cursors, snapshot)
                continue
            }

            if localIdentities == nil {
                let all = (try? context.fetch(FetchDescriptor<ClipItem>())) ?? []
                localIdentities = Set(all.map { Self.identity(of: $0) })
            }

            var oldestSkipped: Date?
            for remote in fresh where localIdentities?.contains(remote.identity) == false {
                if insert(remote, assets: assets) {
                    localIdentities?.insert(remote.identity)
                } else {
                    // 图片资产还没同步下来。以前这里写「等下一轮」，其实等不到：游标照样
                    // 被推到 exportedAt，下一轮 `createdAt > cursor` 就把它滤掉了，这张图
                    // 永远进不来。游标必须停在它之前。
                    oldestSkipped = min(oldestSkipped ?? remote.createdAt, remote.createdAt)
                }
            }
            advance(&cursors, snapshot, notBeyond: oldestSkipped)
        }

        UserDefaults.standard.set(cursors, forKey: Self.cursorsKey)
        try? context.save()
    }

    /// 游标只许前进。同一台设备的快照可能同时出现在 `Copyo/` 与改名前的 `Paster/` 里，
    /// 旧的那份导出时间更早，直接覆盖会把游标拉回去，下一轮就得白扫一遍全表。
    ///
    /// `notBeyond` 是这一轮因为图片资产缺失而跳过的最早条目：游标要停在它之前，
    /// 代价是这份快照下一轮还要再扫一遍（上限 500 条，可以接受），换来的是不会永久丢图。
    private func advance(_ cursors: inout [String: Double], _ snapshot: SyncSnapshot, notBeyond: Date? = nil) {
        var target = snapshot.exportedAt.timeIntervalSince1970
        if let notBeyond {
            target = min(target, notBeyond.timeIntervalSince1970 - 0.001)
        }
        if let existing = cursors[snapshot.deviceID], existing >= target { return }
        cursors[snapshot.deviceID] = target
    }

    /// - Returns: false 表示这条依赖的图片资产还不在，本轮没有插入
    @discardableResult
    private func insert(_ remote: SyncItem, assets: URL) -> Bool {
        let kind = ClipKind(rawValue: remote.kindRaw) ?? .text
        var imageData: Data?
        if kind == .image, let hash = remote.imageHash {
            imageData = try? Data(contentsOf: assets.appendingPathComponent("\(hash).png"))
            guard imageData != nil else { return false }
        }
        let item = ClipItem(kind: kind,
                            plainText: remote.plainText,
                            rtfData: remote.rtfBase64.flatMap { Data(base64Encoded: $0) },
                            imageData: imageData,
                            filePaths: remote.filePaths,
                            sourceAppBundleID: remote.sourceAppBundleID,
                            sourceAppName: remote.sourceAppName)
        item.createdAt = remote.createdAt
        item.imageHash = remote.imageHash
        if let boardName = remote.pinboardName {
            item.pinboard = findOrCreatePinboard(named: boardName)
        }
        context.insert(item)
        return true
    }

    private func findOrCreatePinboard(named name: String) -> Pinboard {
        let boards = (try? context.fetch(FetchDescriptor<Pinboard>())) ?? []
        if let existing = boards.first(where: { $0.name == name }) {
            return existing
        }
        let board = Pinboard(name: name, sortIndex: (boards.map(\.sortIndex).max() ?? -1) + 1)
        context.insert(board)
        return board
    }
}
