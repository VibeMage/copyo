import CopyoCore
import Foundation
import SwiftData

/// 时间线条目里那一条剪贴板内容的**扁平快照**。
///
/// `TimelineEntry` 里**绝对不能放 `ClipItem`**：条目会被 WidgetKit 归档下来、
/// 过一段时间再交回给渲染进程，而 `ClipItem` 是 `@Model`，属性是惰性 fault——
/// 真正读值的那一刻背后的 `ModelContext` 早已不在，轻则读到空值，重则直接崩在渲染进程里。
/// 所以在 `RecentClipsProvider.timeline(for:in:)` 里取到对象的那一刻就地摊平成这个值类型。
struct ClipSnapshot: Identifiable, Hashable, Sendable {

    /// 编码后的 `PersistentIdentifier`，`CopyClipIntent` 靠它告诉主应用要复制哪一条
    let id: String
    let kind: ClipKind
    /// 单行标题（`ClipItem.displayTitle`）。图片条目是空串，本地化由下面的 `displayTitle` 补上
    let title: String
    /// 多行正文，已截断到 `bodyPrefixLimit`
    let body: String
    /// 「来源 · 时间」里的来源，本机条目已经填好「本机」
    let sourceName: String
    /// 淡染与角标用的颜色。名字沿用旧的，但从条目灌入时存的是 `renderColorHex`（颜色条目取内容本身）
    let sourceColorHex: String?
    let createdAt: Date
    let isPinned: Bool
    /// 正文像代码或命令，改用等宽字体（设计 6.7 第 1 行的 `git rebase` 就是这一档）
    let isMono: Bool

    /// 正文截断长度。小尺寸最多画 3 行、中尺寸每格 1 行，200 字远超画得下的量，截断看不出来。
    ///
    /// 这道闸门在小组件里比在 `ClipCard`（那边是 600）更要紧：时间线上的**每一个条目**
    /// 都要把整组快照原样归档一遍，一小时的相对时间阶梯有六十来个条目，
    /// 一条十万字的剪贴板会被复制六十几份塞进归档里。
    private static let bodyPrefixLimit = 200

    /// 从库里的对象摊平。取不到标识符时返回 nil——那一条就没法路由复制请求，不如不显示。
    ///
    /// **全程不碰 `item.imageData`。** 它是 `@Attribute(.externalStorage)`，SwiftData 只在真读它时
    /// 才把文件读进来，而 `CopyoIOS/Model/ClipItem+Display.swift` 记着 Mac 同步来的一张 5K 截图
    /// 解码后约 59MB；小组件扩展只有大约 30MB 的额度，读一张就是被 jetsam 掉。
    /// 图片条目因此只带标题与角标，缩略图位置画 `ClipCard.imageContent` 里那个 `photo` 占位块
    /// （那也正是它给「iCloud 资产还没下载下来」准备的画法）。
    /// 也**不要**去碰 `ImageMetadataCache`：那是主应用的缓存，`totalCostLimit` 设的是 96MB，
    /// 光那个上限就是这个进程全部额度的三倍。
    init?(item: ClipItem) {
        // 借用 `SpotlightIndexer.identifier(for:)`：它要的东西和这里一模一样——
        // 把 `PersistentIdentifier` 编成一个**跨进程稳定**的字符串。那边的注释写明了
        // `JSONEncoder.outputFormatting = [.sortedKeys]` 是必需的（不加的话字典键顺序按进程随机，
        // 小组件进程编出来的串主应用解不回同一条），在这里另起一个编码器就是把那条坑重踩一遍。
        guard let id = SpotlightIndexer.identifier(for: item.persistentModelID) else { return nil }
        self.id = id
        self.kind = item.kind
        self.title = item.displayTitle
        // 存渲染色而不是来源色：颜色条目要用内容本身的颜色染（design-spec 7.4.2）
        self.sourceColorHex = item.renderColorHex
        self.createdAt = item.createdAt
        self.isPinned = item.pinboard != nil
        self.isMono = item.isCodeLike

        let source = item.sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.sourceName = source.isEmpty ? String(localized: "This iPhone") : source

        switch item.kind {
        case .image:
            self.body = ""
        case .color, .file:
            self.body = item.displayTitle
        case .text, .richText, .link:
            self.body = String((item.plainText ?? "").prefix(Self.bodyPrefixLimit))
        }
    }

    /// 直接构造，只给占位图与预览用
    init(id: String,
         kind: ClipKind,
         title: String,
         body: String,
         sourceName: String,
         sourceColorHex: String?,
         createdAt: Date,
         isPinned: Bool = false,
         isMono: Bool = false) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.sourceName = sourceName
        self.sourceColorHex = sourceColorHex
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.isMono = isMono
    }

    // MARK: - 显示

    /// 图片条目的 `displayTitle` 是空串（`CopyoCore` 故意把本地化留给调用方），补成「图片」
    var displayTitle: String {
        title.isEmpty ? KindPresentation.label(kind) : title
    }

    /// 「刚刚 / 3 分钟前 / 昨天 18:42」，口径见 `CopyoShared/UI/RelativeTime.swift`。
    ///
    /// 参数是 `reference` 而不是 `Date()`：小组件的每个时间线条目都带自己的时刻，
    /// 渲染时必须按 `entry.date` 算。
    func relativeTime(at reference: Date) -> String {
        RelativeTime.string(for: createdAt, reference: reference)
    }
}
