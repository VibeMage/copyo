import AppKit
import CopyoCore
import Foundation
import SwiftData

/// `-demoData` 用的样例数据，取自 design-spec 第六节（7.5.13：照 `CopyoIOS/Model/DemoData.swift` 移植，
/// 数据部分按 6.1–6.4 逐字搬）。
///
/// 只往**内存容器**里灌（AppDelegate 在 `-demoData` 下直接落进内存容器分支），任何情况下都不会碰
/// `Copyo.store`——`scripts/make-store-shots.py` 那条往真实库里灌数据的路因此可以退役。
/// 时间一律相对 `now` 生成，截图什么时候跑，卡片上的「2 分钟前」都是对的。
@MainActor
enum MacDemoData {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-demoData")

    static func populate(into context: ModelContext) {
        // 已经灌过就别再灌一遍（与 iOS 同一道保险：populate 被调两次不该出两份）
        let existing = try? context.fetchCount(FetchDescriptor<ClipItem>())
        guard (existing ?? 0) == 0 else { return }

        let english = isEnglish
        let now = Date()

        let boards = makeBoards(english: english)
        boards.forEach(context.insert)

        for spec in historySpecs(english: english) {
            let item = spec.makeItem(now: now)
            context.insert(item)
            if let index = spec.board, boards.indices.contains(index) {
                item.pinboard = boards[index]
            }
        }

        // 只在板里、不在历史前排的条目：时间都在几天前，排在历史末尾，不挤掉 6.1 的面板主态五条
        for (index, specs) in boardOnlySpecs(english: english).enumerated() where boards.indices.contains(index) {
            for spec in specs {
                let item = spec.makeItem(now: now)
                context.insert(item)
                item.pinboard = boards[index]
            }
        }

        // LSUIElement 应用没有常规窗口事件循环，autosave 不可靠，照 ClipboardMonitor 的做法显式保存
        try? context.save()
    }

    /// 界面实际用的语言不是中文时灌英文版（中文以外一律英文，同 iOS）。
    /// 看 `Bundle.main.preferredLocalizations` 而不是 `Locale.current`：截图脚本用 `-AppleLanguages` 切语言，
    /// 这里要跟界面文案走同一个判断，不然会出现法文界面配中文样例。
    private static var isEnglish: Bool {
        !(Bundle.main.preferredLocalizations.first ?? "en").hasPrefix("zh")
    }

    // MARK: - Pinboard

    /// 名字与颜色取自 gen_v2.py 的「固定到 Pinboard ▸」子菜单（A-menu.dc.html）：
    /// 设计 Token `ACCENT` / 常用短语 `#30D158` / 发版清单 `WARN`
    private static func makeBoards(english: Bool) -> [Pinboard] {
        [
            Pinboard(name: english ? "Design Tokens" : "设计 Token", sortIndex: 0,
                     iconName: "paintpalette", colorHex: "#0A84FF"),
            Pinboard(name: english ? "Snippets" : "常用短语", sortIndex: 1,
                     iconName: "text.quote", colorHex: "#30D158"),
            Pinboard(name: english ? "Release Checklist" : "发版清单", sortIndex: 2,
                     iconName: "checklist", colorHex: "#FF9F0A"),
        ]
    }

    // MARK: - 条目

    /// 条目的时间：多数是「往前推多久」，但设计稿里「昨天 18:42」这种是钟点，
    /// 按秒数往前推的话截图时刻一变，卡片上的钟点就对不上稿子了
    private enum When {
        case ago(TimeInterval)
        /// `second` 只用来给同一分钟里的两条排先后：卡片只显示到分钟，稿子上两张都写「昨天 18:42」
        case yesterday(hour: Int, minute: Int, second: Int = 0)

        func date(now: Date) -> Date {
            switch self {
            case .ago(let seconds):
                return now.addingTimeInterval(-seconds)
            case .yesterday(let hour, let minute, let second):
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: now)
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today.addingTimeInterval(-86400)
                return calendar.date(bySettingHour: hour, minute: minute, second: second, of: yesterday) ?? yesterday
            }
        }
    }

    /// 来源 App：显示名、bundle ID、来源色。来源色取 gen.py `SRC` 的第一列（design-spec 第六节表头的约定）；
    /// bundle ID 填真实值，预览浮层等处按它取 App 图标
    private struct Source {
        var name: String?
        var bundleID: String?
        var colorHex: String?
    }

    /// 一条样例。`board` 是固定进 `makeBoards` 里第几个板；nil = 不固定。
    private struct Spec {
        var kind: ClipKind
        var text: String?
        var when: When
        var source: Source
        var filePaths: [String] = []
        var image = false
        var board: Int?

        @MainActor func makeItem(now: Date) -> ClipItem {
            let png = image ? MacDemoData.sampleImagePNG : nil
            let item = ClipItem(kind: kind,
                                plainText: kind == .file ? filePaths.joined(separator: "\n") : text,
                                rtfData: kind == .richText ? MacDemoData.rtfData(from: text ?? "") : nil,
                                imageData: png,
                                filePaths: filePaths,
                                sourceAppBundleID: source.bundleID,
                                sourceAppName: source.name,
                                sourceColorHex: source.colorHex)
            item.createdAt = when.date(now: now)
            if let png { item.imageHash = ContentHash.sha256(png) }
            return item
        }
    }

    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 3600
    private static let day: TimeInterval = 86400

    private static func sources(english: Bool) -> (xcode: Source, wechat: Source, safari: Source, figma: Source,
                                                   notes: Source, finder: Source, vscode: Source, terminal: Source,
                                                   remoteDesktop: Source, iPhone: Source) {
        (
            Source(name: "Xcode", bundleID: "com.apple.dt.Xcode", colorHex: "#147EFB"),
            Source(name: english ? "WeChat" : "微信", bundleID: "com.tencent.xinWeChat", colorHex: "#07C160"),
            Source(name: "Safari", bundleID: "com.apple.Safari", colorHex: "#1EA7FD"),
            Source(name: "Figma", bundleID: "com.figma.Desktop", colorHex: "#A259FF"),
            Source(name: english ? "Notes" : "备忘录", bundleID: "com.apple.Notes", colorHex: "#FFC300"),
            Source(name: english ? "Finder" : "访达", bundleID: "com.apple.finder", colorHex: "#1EA7FD"),
            Source(name: "VS Code", bundleID: "com.microsoft.VSCode", colorHex: "#0098FF"),
            // 终端、Microsoft Remote Desktop 两个色取 gen_v2.py 的 SRCHEX 补充项
            Source(name: english ? "Terminal" : "终端", bundleID: "com.apple.Terminal", colorHex: "#1C1C1E"),
            Source(name: "Microsoft Remote Desktop", bundleID: "com.microsoft.rdc.macos", colorHex: "#0078D4"),
            // 6.4 第 3 条：iPhone 上存进来的条目没有来源色（第 30 条之后是 nil），显示时回退 #8E8E93
            Source(name: "iPhone", bundleID: nil, colorHex: nil)
        )
    }

    /// 历史，按时间从新到旧。
    ///
    /// 前五条就是 6.1 面板主态的五张卡（Xcode / 微信 / Safari / Figma / 备忘录图片），顺序不能乱：
    /// 面板按 createdAt 倒序排，第六节之外的条目一律比「昨天 18:42」更早。
    /// 这五条都**不固定**——Main.dc.html 上没有一张卡带图钉。
    private static func historySpecs(english: Bool) -> [Spec] {
        let src = sources(english: english)
        return [
            // 6.1 第 1 条：等宽正文由 ClipClassifier 判成代码后自动切换
            Spec(kind: .text, text: "git rebase -i HEAD~3 && git push --force-with-lease",
                 when: .ago(2 * minute), source: src.xcode),
            // 6.1 第 2 条（不是 6.2 那条截短版，两者不可互换）
            Spec(kind: .text,
                 text: english
                    ? "Let's sync on the Q4 roadmap Friday 3pm in the small room on 3F. Bring last week's funnel numbers, and we can look at the venue quotes too."
                    : "周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上，顺便看看新江湾那边场地的报价。",
                 when: .ago(12 * minute), source: src.wechat),
            // 6.1 第 3 条：中英文共用同一条链接（6.2 注明「原样复用」）
            Spec(kind: .link,
                 text: "https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass",
                 when: .ago(25 * minute), source: src.safari),
            // 6.1 第 4 条：淡染取剪贴内容本身 #FF2D55，Figma 的 #A259FF 在卡上一处都不出现（7.4.2）
            Spec(kind: .color, text: "#FF2D55", when: .ago(hour), source: src.figma),
            // 6.1 第 5 条 / 6.3 第 4 条。定在 18:42:30：tight_row 那张富文本也是「昨天 18:42」，
            // 图片要比它新半分钟，才稳稳留在主态第五张
            Spec(kind: .image, text: nil, when: .yesterday(hour: 18, minute: 42, second: 30), source: src.notes, image: true),
            // 6.4 排版最紧的一条（gen_v2.py tight_row 第 1 张）：富文本角标 + pin.fill + 长来源名，
            // 验「省略号只吃来源名，时间永不被截」。时间照稿子「昨天 18:42」，固定进「发版清单」才画得出图钉
            Spec(kind: .richText,
                 text: english
                    ? "Q3 Review (final) — channels, retention, and the three experiments we never finished."
                    : "第三季度复盘（终稿）—— 渠道、留存、以及那三个没做完的实验。",
                 when: .yesterday(hour: 18, minute: 42), source: src.remoteDesktop, board: 2),
            // 6.3 第 6 条：多文件卡 = 首文件名 + 「另外 4 个文件」
            Spec(kind: .file, text: nil, when: .yesterday(hour: 18, minute: 2), source: src.finder,
                 filePaths: english
                    ? ["/Users/Shared/Q3-Review.key", "/Users/Shared/Q3-Review.pdf", "/Users/Shared/Q3-Funnel.numbers",
                       "/Users/Shared/Q3-Cover.png", "/Users/Shared/Q3-Notes.docx"]
                    : ["/Users/Shared/Q3-复盘.key", "/Users/Shared/Q3-复盘.pdf", "/Users/Shared/Q3-漏斗数据.numbers",
                       "/Users/Shared/Q3-封面.png", "/Users/Shared/Q3-会议纪要.docx"]),
            // 固定进「发版清单」：历史里要有一张带 pin.fill 的卡，但不能落在主态前五张里
            Spec(kind: .text, text: "npm run dist --sign", when: .yesterday(hour: 17, minute: 20),
                 source: src.vscode, board: 2),
            // 6.3 第 2 条的富文本。kind_row / 02 预览稿写的是「3 小时前」，但同一条按时间倒序的历史里，
            // 3 小时前会排进主态第五张、把 6.1 的图片卡（昨天 18:42）挤出去——两张稿子在一份数据里不能同时成立。
            // 这里有意偏离、取 6.2 搜索态给同一条备忘录的「昨天 09:12」（gen_v2.py 搜索稿），搜「会议」时两条结果也正好对上 6.2；
            // 要拍「3 小时前」的种类 / 预览截图，得另加一个启动参数单独给这条改时间
            Spec(kind: .richText,
                 text: english
                    ? "Standup 9/4\n· Login flow gets its own draft\n· Icon 8a is final\n· TestFlight ships Wed"
                    : "站会纪要 9/4\n· 登录页流程另开一稿\n· 图标最终稿 8a 已定\n· TestFlight 周三发",
                 when: .yesterday(hour: 9, minute: 12), source: src.notes),
            // 6.4 其余三条，放在更早的位置，横向滚过去就能验（稿子上的「3 分钟前」「2 分钟前」会挤进主态前五，只能往后放）
            Spec(kind: .text,
                 text: english
                    ? "Saved on iPhone. The source color is nil, so it falls back to #8E8E93."
                    : "这条是 iPhone 上存进来的，来源色是 nil，显示时回退到 #8E8E93。",
                 when: .ago(2 * day), source: src.iPhone),
            Spec(kind: .text,
                 text: "Thread 1: Fatal error: Unexpectedly found nil while unwrapping an Optional value",
                 when: .ago(3 * day), source: src.xcode),
            Spec(kind: .richText, text: english ? "Q3 Review (final)" : "第三季度复盘（终稿）",
                 when: .ago(9 * day), source: src.notes),
        ]
    }

    /// 只存在于板里的条目，顺序与 `makeBoards` 一一对应
    private static func boardOnlySpecs(english: Bool) -> [[Spec]] {
        let src = sources(english: english)
        let tokens = [
            Spec(kind: .color, text: "#0A84FF", when: .ago(3 * day), source: src.figma),
            Spec(kind: .color, text: "#F7F3EA", when: .ago(8 * day), source: src.figma),
        ]
        let snippets = english
            ? [
                Spec(kind: .text, text: "Got it — let me double-check and get back to you.",
                     when: .ago(5 * day), source: src.wechat),
                Spec(kind: .text, text: "Thanks everyone, let's pick this up at standup tomorrow.",
                     when: .ago(12 * day), source: src.wechat),
            ]
            : [
                Spec(kind: .text, text: "收到，我确认一下再回复你。", when: .ago(5 * day), source: src.wechat),
                Spec(kind: .text, text: "辛苦了，今天先到这儿，明早站会再对。", when: .ago(12 * day), source: src.wechat),
            ]
        let release = [
            Spec(kind: .text, text: "xcrun notarytool submit Copyo.dmg --keychain-profile copyo --wait",
                 when: .ago(6 * day), source: src.terminal),
        ]
        return [tokens, snippets, release]
    }

    // MARK: - 资源

    /// 富文本条目要有真的 RTF，预览浮层的富文本渲染路径才走得通。
    /// 用 NSAttributedString 生成而不是手拼 RTF 串：中文要转义成 `\uXXXX`，手拼一定出错。
    private static func rtfData(from body: String) -> Data? {
        let attributed = NSMutableAttributedString(
            string: body,
            attributes: [.font: NSFont.systemFont(ofSize: 13)]
        )
        // 首行加粗——设计稿的富文本把第一行当标题
        let firstLineEnd = (body as NSString).range(of: "\n").location
        if firstLineEnd != NSNotFound {
            attributed.addAttribute(.font,
                                    value: NSFont.boldSystemFont(ofSize: 14),
                                    range: NSRange(location: 0, length: firstLineEnd))
        }
        return try? attributed.data(from: NSRange(location: 0, length: attributed.length),
                                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    /// 样例图片（6.1 第 5 条 / 6.3 第 4 条）。取随包资源 `DemoSampleImage`（7.5.18 对 7.5.13 的拍板：缩略图改用随包资源），
    /// 资源里放了两套外观：浅 `#F0E4BE` / 深 `#4A431F`，各叠一个只差一档的圆角块和圆，缩到 260 宽的卡片里基本读作纯色，
    /// 与稿子一致，又不至于像一张没加载出来的空图。
    ///
    /// 条目里存的是 PNG 字节，不是资源名——所以得在灌数据那一刻按外观把对应那套画出来。
    /// 截图是每种外观各起一次进程（`-forceDark`），不存在灌完再切外观的情况；AppDelegate 在灌数据之后才改
    /// NSApp.appearance，所以这里自己也认 `-forceDark`。只画一次并缓存；1200 × 900 像素，预览浮层元信息行才像一张真截图。
    private static let sampleImagePNG: Data = {
        let dark = ProcessInfo.processInfo.arguments.contains("-forceDark")
            || NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let width = 1200, height = 900
        guard let image = NSImage(named: "DemoSampleImage"),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                 space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return Data() }
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
        // 资源按「当前绘制外观」挑那一套，显式指定，不依赖此刻 NSApp 的外观有没有设好
        (NSAppearance(named: dark ? .darkAqua : .aqua) ?? NSAppearance.currentDrawing()).performAsCurrentDrawingAppearance {
            image.draw(in: rect)
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let rendered = cg.makeImage() else { return Data() }
        return NSBitmapImageRep(cgImage: rendered).representation(using: .png, properties: [:]) ?? Data()
    }()
}
