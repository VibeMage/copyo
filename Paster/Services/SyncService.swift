import AppKit
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

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - 目录与设备标识

    static var deviceID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: deviceIDKey) { return existing }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: deviceIDKey)
        return fresh
    }

    /// 同步目录：默认 iCloud Drive/Paster；也可在设置中改为任意共享文件夹
    /// （公司 NAS、Dropbox 等——只要多台设备都能读写同一目录即可同步）
    static var syncRoot: URL? {
        if let custom = UserDefaults.standard.string(forKey: "syncFolderOverride"),
           !custom.isEmpty {
            let url = URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path) else { return nil }
            return url
        }
        let icloudDrive = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        guard FileManager.default.fileExists(atPath: icloudDrive.path) else { return nil }
        return icloudDrive.appendingPathComponent("Paster", isDirectory: true)
    }

    static var isAvailable: Bool { syncRoot != nil }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: "icloudSync") }

    // MARK: - 生命周期

    func updateActivation() {
        if isEnabled && Self.isAvailable {
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
        guard isEnabled, let root = Self.syncRoot else { return }
        let assets = root.appendingPathComponent("assets", isDirectory: true)
        try? FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        exportSnapshot(to: root, assets: assets)
        importSnapshots(from: root, assets: assets)
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
            return "f:" + ClipboardMonitor.sha256(Data(item.filePaths.joined(separator: "\n").utf8))
        default:
            return "t:" + ClipboardMonitor.sha256(Data((item.plainText ?? "").utf8))
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

    // MARK: - 导入合并

    private func importSnapshots(from root: URL, assets: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var cursors = (UserDefaults.standard.dictionary(forKey: Self.cursorsKey) as? [String: Double]) ?? [:]
        var localIdentities: Set<String>? // 惰性构建，多数轮询没有新内容

        for file in files where file.lastPathComponent.hasPrefix("device-") && file.pathExtension == "json" {
            guard !file.lastPathComponent.contains(Self.deviceID),
                  let data = try? Data(contentsOf: file),
                  let snapshot = try? decoder.decode(SyncSnapshot.self, from: data) else { continue }

            let cursor = cursors[snapshot.deviceID].map { Date(timeIntervalSince1970: $0) } ?? .distantPast
            let fresh = snapshot.items.filter { $0.createdAt > cursor }
            guard !fresh.isEmpty else {
                cursors[snapshot.deviceID] = snapshot.exportedAt.timeIntervalSince1970
                continue
            }

            if localIdentities == nil {
                let all = (try? context.fetch(FetchDescriptor<ClipItem>())) ?? []
                localIdentities = Set(all.map { Self.identity(of: $0) })
            }

            for remote in fresh where localIdentities?.contains(remote.identity) == false {
                insert(remote, assets: assets)
                localIdentities?.insert(remote.identity)
            }
            cursors[snapshot.deviceID] = snapshot.exportedAt.timeIntervalSince1970
        }

        UserDefaults.standard.set(cursors, forKey: Self.cursorsKey)
        try? context.save()
    }

    private func insert(_ remote: SyncItem, assets: URL) {
        let kind = ClipKind(rawValue: remote.kindRaw) ?? .text
        var imageData: Data?
        if kind == .image, let hash = remote.imageHash {
            imageData = try? Data(contentsOf: assets.appendingPathComponent("\(hash).png"))
            guard imageData != nil else { return } // 图片资产还没同步下来，等下一轮
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
