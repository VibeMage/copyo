import CopyoCore
import Foundation
import SwiftData
import SwiftUI
import UIKit

/// 卡片条上的一条剪贴内容，**扁平值类型**。
///
/// 与 `CopyoWidgets/ClipSnapshot.swift` 同一个理由，但这里更紧一层：`ClipItem` 的属性是惰性
/// fault，读值那一刻背后的 `ModelContext` 必须还活着。键盘的做法是取完就把上下文丢掉
/// （见 `KeyboardClipStore.reload()`）——**那正是这个类型存在的意义**：上下文一走，
/// 它取过的 `ClipItem` 也跟着走，连带把 `plainText` 这些大字符串从内存里放掉，
/// 而界面要画的东西已经全部摊在这里了。捏着 `ClipItem` 去画就等于捏着整个上下文不放。
///
/// **全程不碰 `item.imageData`。** 它是 `@Attribute(.externalStorage)`，SwiftData 只在真读它时
/// 才把文件读进来，而 `CopyoIOS/Model/ClipItem+Display.swift` 记着 Mac 同步来的一张 5K 截图
/// 解码后约 59MB。键盘扩展是所有扩展点里 jetsam 预算最紧的一个（按 30MB 规划），读一张就是被杀。
/// 图片条目因此只画占位块，见 `ClipStripCard.imageContent`。
struct KeyboardClip: Identifiable, Hashable {

    /// 只用来做 `ForEach` 的身份，不跨进程传——键盘不给任何别的进程发消息，
    /// 所以不必像 `ClipSnapshot` 那样编码成字符串（那条路上有 `.sortedKeys` 的坑）
    let id: PersistentIdentifier
    let kind: ClipKind
    /// 单行标题（`ClipItem.displayTitle`）。图片条目是空串，本地化由 `displayTitle` 补
    let title: String
    /// 卡片正文，已截到 `bodyPrefixLimit`
    let body: String
    /// 「来源 · 时间」里的来源，本机条目已经填好「本机」
    let sourceName: String
    let sourceColorHex: String?
    let createdAt: Date
    let isPinned: Bool
    /// 正文像代码或命令，改用等宽字体
    let isMono: Bool
    /// 链接条目的域名，其余为 nil
    let linkDomain: String?

    /// 送进宿主输入框的文本。nil = 这一类**没有办法**插进去。
    ///
    /// **这里存的是全文，不是 `body` 那份截断稿。** 插入是用户唯一真正要的结果，
    /// 送过去一份被截掉一半的内容，用户多半要到粘贴之后才发现，而那时原文已经不在剪贴板里了。
    /// 代价是这 40 条的全文都留在内存里——但取数那一步本来就已经把它们读进来了
    /// （`plainText` 是普通属性，不是 externalStorage，`fetch` 时一并载入），
    /// 留着不额外抬高峰值；真正的内存杀手是图片，而图片这一路一个字节都不读。
    ///
    /// 各类型的映射按 design-spec 第四节「键盘扩展」那一条：
    /// 文本 / 富文本 → 纯文本，链接 → URL 串，颜色 → 色值。
    /// 图片与文件是 nil——`textDocumentProxy` 只有 `insertText(_:)`，
    /// **没有任何 API 能把图片或带格式的富文本塞进宿主文稿**，所以那两类只能给提示。
    let insertion: String?

    /// 搜索用的小写文本。存下来而不是每次按键现算：查询每敲一个字符都要把 40 条过一遍，
    /// 现算就是每个字符做 40 次 `lowercased()`（中文 / 法语带变音符的折叠并不便宜）
    let searchText: String

    /// 正文与搜索文本的截断长度。
    ///
    /// 卡片是 dense 的三行、168pt 宽，240 字远超画得下的量，截断在视觉上看不见。
    /// **但搜索也只看这 240 字**——一条长文里第 300 个字上的关键词在键盘上搜不到，
    /// 得回 Copyo 里搜。这是有意的取舍：把全文都折成小写留一份，等于把上面
    /// 「插入存全文」那笔内存再付一遍。
    private static let bodyPrefixLimit = 240

    init(item: ClipItem) {
        self.id = item.persistentModelID
        self.kind = item.kind
        self.title = item.displayTitle
        self.sourceColorHex = item.sourceColorHex
        self.createdAt = item.createdAt
        self.isPinned = item.pinboard != nil
        self.isMono = item.isCodeLike
        self.linkDomain = item.linkDomain

        let source = item.sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.sourceName = source.isEmpty ? String(localized: "This iPhone") : source

        let text = item.plainText ?? ""
        switch item.kind {
        case .image:
            self.body = ""
            self.insertion = nil
        case .file:
            self.body = item.displayTitle
            self.insertion = nil
        case .color:
            self.body = item.displayTitle
            self.insertion = item.displayTitle.isEmpty ? nil : item.displayTitle
        case .text, .richText, .link:
            self.body = String(text.prefix(Self.bodyPrefixLimit))
            self.insertion = text.isEmpty ? nil : text
        }

        self.searchText = "\(title)\n\(body)".lowercased()
    }

    // MARK: - 显示

    /// 图片条目的 `displayTitle` 是空串（`CopyoCore` 故意把本地化留给调用方），补成「图片」
    var displayTitle: String {
        title.isEmpty ? KindPresentation.label(kind) : title
    }

    var sourceUIColor: UIColor {
        CopyoTheme.uiColor(hexString: sourceColorHex) ?? CopyoTheme.sourceLocalUI
    }

    /// 整卡淡染（设计 3.3：浅 12% 混白 / 深 20% 混 #1C1C1E）。
    ///
    /// **这是 `CopyoIOS/Model/ClipItem+Display.swift` 里 `tintColor(for:)` 的第二份实现**，
    /// 那个扩展写在 `ClipItem` 上、文件属于 `CopyoIOS` target，键盘编译不到。
    /// 混色本身走共用的 `CopyoTheme.mix`，抄过来的只有 base 与那两个比例；
    /// **改淡染比例时两处都要改**，只改一处的表现是同一条内容在应用里和在键盘上不是一个颜色。
    /// 该把它提到 `CopyoTheme` 去（那里已经有 trait 版的 `tintUIColor`），只是那个文件
    /// 不在本次改动范围内。
    func tintColor(for scheme: ColorScheme) -> Color {
        let base = scheme == .dark ? CopyoTheme.rgb(0x1C1C1E) : CopyoTheme.rgb(0xFFFFFF)
        let fraction: CGFloat = scheme == .dark ? 0.20 : 0.12
        return Color(uiColor: CopyoTheme.mix(sourceUIColor, into: base, fraction: fraction))
    }

    /// 「刚刚 / 3 分钟前 / 昨天 18:42」。
    ///
    /// **这是同一段逻辑的第三份实现**：`CopyoIOS/Model/ClipItem+Display.swift` 的
    /// `relativeTime(reference:)`、`CopyoWidgets/ClipSnapshot.swift` 的 `relativeTime(at:)`，
    /// 和这里。本地化键（`now` / `%lldm` / `%lldh` / `%lldd` / `Last week`）三处逐字相同，
    /// **改档位口径时三处都要改**——只改一处的表现是同一条内容在应用、小组件、键盘上
    /// 各写一个时间。小组件那份的注释已经写着「该把它提到 `CopyoShared/` 去」；
    /// 到第三份了，下一次碰这块之前应该先把它搬走，本次改动范围只含 `CopyoKeyboard/`。
    func relativeTime(at reference: Date = Date()) -> String {
        let interval = reference.timeIntervalSince(createdAt)
        if interval < 60 { return String(localized: "now") }
        let calendar = Calendar.current
        if calendar.isDate(createdAt, inSameDayAs: reference) {
            let minutes = Int(interval / 60)
            if minutes < 60 {
                return String(format: String(localized: "%lldm"), minutes)
            }
            return String(format: String(localized: "%lldh"), minutes / 60)
        }
        if calendar.isDateInYesterday(createdAt) {
            return Self.dateTimeFormatter.string(from: createdAt)
        }
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: createdAt),
                                           to: calendar.startOfDay(for: reference)).day ?? 0
        if days < 7 { return String(format: String(localized: "%lldd"), days) }
        if days < 14 { return String(localized: "Last week") }
        return Self.dateOnlyFormatter.string(from: createdAt)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        // 「今天 / 昨天」交给系统按当前语言给，自己拼会在英文下变成错误的语序
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    // MARK: - 搜索

    /// 查询命中。空查询一律命中，于是「筛选后的卡片条」与「全部卡片条」是同一条代码路径。
    ///
    /// 只做小写子串匹配，不做分词、不做拼音：键盘只打得出拉丁字符（见 `LetterPlane`），
    /// 而这道匹配要能让 `482913`、`git`、`apple.com` 这类内容被三五个字符找出来，
    /// 子串就够了。中文查询在这块键盘上根本输入不了，做分词也没有输入源。
    func matches(query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return true }
        return searchText.contains(needle)
    }
}
