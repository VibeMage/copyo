import Foundation
import PasterCore
import SwiftData

/// 一份待入库的内容。分享扩展从 `NSExtensionItem` 提取、`SaveContentIntent` 从参数构造，
/// 两条路最终都归一成它再交给 `ClipIngest`，保证「分享面板存进来的」和「快捷指令存进来的」
/// 在分类、去重、历史上限上的行为一模一样。
public enum SharePayload: Sendable {
    /// 纯文本 / 富文本。类型交给 `ClipClassifier` 判（可能落成 link 或 color）
    case text(String, rtfData: Data?)
    /// 链接。`title` 只用于预览显示——ClipItem 没有标题字段，入库存的是 URL 本身
    case link(URL, title: String?)
    /// 图片，已经是 PNG；像素尺寸单独带上，免得预览时再解一次码
    case image(png: Data, pixelWidth: Int, pixelHeight: Int)

    /// 预分类。真正入库时 `ClipSaver` 会再判一次，两处结果一致（同一个 `ClipClassifier`）。
    public var kind: ClipKind {
        switch self {
        case .text(let string, let rtf):
            return ClipClassifier.classify(text: string, hasRTF: rtf != nil)
        case .link:
            return .link
        case .image:
            return .image
        }
    }
}

/// 「拿到内容 → 打开共享库 → 入库 → 可选固定」的唯一实现，分享扩展与 App Intent 共用。
///
/// 两个调用方都在扩展 / 后台进程里，没有 UI 兜底也没有主应用的 `AppModel`，
/// 所以规则必须落在同一处：分散实现必然会在历史上限、去重、Pinboard 归属上走形。
public enum ClipIngest {

    public enum IngestError: LocalizedError {
        case nothingToSave
        /// App Group 里的共享库打不开（capability 没配好，或磁盘出问题）
        case storeUnavailable

        public var errorDescription: String? {
            switch self {
            case .nothingToSave:
                return String(localized: "There's nothing to save here.")
            case .storeUnavailable:
                return String(localized: "Paster can't open its library right now.")
            }
        }
    }

    /// 打开 App Group 里那份共享库。
    ///
    /// **不开 CloudKit 镜像**：扩展进程没有推送 entitlement，SwiftData 的镜像在这里跑不起来，
    /// 硬开只会拖慢建库并留下一串报错。写进本地库的条目会在主应用下次启动挂上镜像时被同步上去。
    public static func makeContainer() throws -> ModelContainer {
        try PasterStore.makeContainer(url: PasterStore.appGroupStoreURL(), cloudKit: false)
    }

    /// 共享库里的 Pinboard，按列表顺序。分享面板的「固定到 Pinboard」菜单用它。
    public static func boardOptions(in context: ModelContext) -> [ShareBoardOption] {
        let descriptor = FetchDescriptor<Pinboard>(sortBy: [SortDescriptor(\.sortIndex),
                                                            SortDescriptor(\.createdAt)])
        let boards = (try? context.fetch(descriptor)) ?? []
        return boards.map {
            ShareBoardOption(id: $0.persistentModelID,
                             name: $0.name,
                             iconName: $0.iconName,
                             colorHex: $0.colorHex)
        }
    }

    /// 入库。`pinboardID` 为 nil 就是「不固定」，留在历史里。
    ///
    /// 历史上限从 App Group 的 UserDefaults 读，与主应用设置页的值是同一个——
    /// 否则用户把上限调成 100，分享扩展仍按 500 存，条数对不上。
    @discardableResult
    public static func save(_ payload: SharePayload,
                            pinboardID: PersistentIdentifier?,
                            in context: ModelContext) throws -> ClipItem {
        let limit = PasterAppGroup.historyLimit
        let result: SaveResult
        switch payload {
        case .text(let string, let rtf):
            result = try ClipSaver.save(text: string,
                                        rtfData: rtf,
                                        source: .local,
                                        historyLimit: limit,
                                        in: context)
        case .link(let url, _):
            result = try ClipSaver.save(text: url.absoluteString,
                                        source: .local,
                                        historyLimit: limit,
                                        in: context)
        case .image(let png, _, _):
            result = try ClipSaver.save(imagePNG: png,
                                        source: .local,
                                        historyLimit: limit,
                                        in: context)
        }

        let item = result.item
        if let pinboardID, let board = context.model(for: pinboardID) as? Pinboard {
            // 命中去重时 ClipSaver 刻意不动 pinboard（重复复制不该把条目踢出板子），
            // 但用户这次明确选了板，以用户这次的选择为准
            item.pinboard = board
            try context.save()
        }
        return item
    }
}

/// 分享面板里可选的 Pinboard。视图层不直接持有 SwiftData 对象：
/// 分享扩展与主应用演示路由跑在不同的容器上，传一个值类型省掉两边的生命周期问题。
public struct ShareBoardOption: Identifiable, Hashable, Sendable {
    public let id: PersistentIdentifier
    public let name: String
    public let iconName: String?
    public let colorHex: String?

    public init(id: PersistentIdentifier, name: String, iconName: String?, colorHex: String?) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
    }
}
