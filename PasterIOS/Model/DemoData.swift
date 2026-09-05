import Foundation
import PasterCore
import SwiftData
import UIKit

/// `-demoData` 用的样例数据，取自 design-spec 第六节。
///
/// 只往**内存容器**里灌（见 `StoreBootstrap.make`），任何情况下都不会碰用户真实数据库。
/// 时间一律相对 `now` 生成，截图什么时候跑，卡片上的「3 分钟前」都是对的。
enum DemoData {

    static func populate(in context: ModelContext) {
        // 已经灌过就别再灌一遍：SwiftUI 的 App.init 在某些场景下会跑两次
        let existing = try? context.fetchCount(FetchDescriptor<ClipItem>())
        guard (existing ?? 0) == 0 else { return }

        let english = isEnglish
        let now = Date()

        let boards = makeBoards(english: english)
        boards.forEach(context.insert)
        let tokenBoard = boards.first

        for spec in historySpecs(english: english) {
            let item = spec.makeItem(now: now)
            context.insert(item)
            if spec.pinned { item.pinboard = tokenBoard }
        }

        for spec in tokenBoardSpecs(english: english).dropFirst() {
            // dropFirst：第 0 条就是历史里那条 #FF9F0A，已经固定进这个板了
            let item = spec.makeItem(now: now)
            context.insert(item)
            item.pinboard = tokenBoard
        }

        // 另外三个板也要有条目：design-spec 6.3 给的条数是 6 / 3 / 12 / 2，
        // 全灌 0 的话 Pinboard 列表与 iPad 侧栏满屏都是 0，看不出这套设计是怎么用的
        for (index, specs) in otherBoardSpecs(english: english).enumerated() {
            guard boards.indices.contains(index + 1) else { continue }
            let board = boards[index + 1]
            for spec in specs {
                let item = spec.makeItem(now: now)
                context.insert(item)
                item.pinboard = board
            }
        }

        try? context.save()
    }

    /// 设计稿的英文版样例（01g）在系统语言为英文时使用
    private static var isEnglish: Bool {
        Locale.current.language.languageCode?.identifier != "zh"
    }

    // MARK: - Pinboard

    private static func makeBoards(english: Bool) -> [Pinboard] {
        [
            Pinboard(name: english ? "Design Tokens" : "设计 Token", sortIndex: 0,
                     iconName: "paintpalette", colorHex: "#A259FF"),
            Pinboard(name: english ? "Addresses" : "常用地址", sortIndex: 1,
                     iconName: "text.alignleft", colorHex: "#34C759"),
            Pinboard(name: english ? "Commands" : "命令", sortIndex: 2,
                     iconName: "terminal", colorHex: "#8E8E93"),
            Pinboard(name: english ? "Billing" : "发票信息", sortIndex: 3,
                     iconName: "doc.text", colorHex: "#FF9F0A"),
        ]
    }

    // MARK: - 条目

    /// 一条样例。`age` 是相对当前时间往前推多久。
    private struct Spec {
        var kind: ClipKind
        var text: String?
        var age: TimeInterval
        var source: String?
        var colorHex: String?
        var filePaths: [String] = []
        var image = false
        var pinned = false

        func makeItem(now: Date) -> ClipItem {
            let item = ClipItem(kind: kind,
                                plainText: text,
                                rtfData: kind == .richText ? DemoData.rtfData(from: text ?? "") : nil,
                                imageData: image ? DemoData.sampleImagePNG : nil,
                                filePaths: filePaths,
                                sourceAppBundleID: nil,
                                sourceAppName: source,
                                sourceColorHex: colorHex)
            item.createdAt = now.addingTimeInterval(-age)
            if image { item.imageHash = ContentHash.sha256(DemoData.sampleImagePNG) }
            return item
        }
    }

    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 3600
    private static let day: TimeInterval = 86400

    private static func historySpecs(english: Bool) -> [Spec] {
        if english {
            return [
                Spec(kind: .text, text: "Your verification code is 482913. It expires in 5 minutes.",
                     age: 20, source: nil, colorHex: nil),
                Spec(kind: .text, text: "git rebase -i HEAD~3 && git push --force-with-lease",
                     age: 3 * minute, source: "Terminal", colorHex: "#48484A"),
                Spec(kind: .text, text: "Let's sync on the Q4 roadmap Friday 3pm, room 3B. Bring last week's funnel numbers.",
                     age: 12 * minute, source: "Messages", colorHex: "#34C759"),
                linkSpec,
                Spec(kind: .color, text: "#FF9F0A", age: hour, source: "Figma", colorHex: "#A259FF", pinned: true),
                Spec(kind: .image, text: nil, age: hour, source: "Preview", colorHex: "#5B8DC9", image: true),
                Spec(kind: .richText,
                     text: "Standup 9/4\n· Login redesign ships next week\n· Icon 8a final\n· TestFlight Wed",
                     age: 2 * hour, source: "Notes", colorHex: "#F7C600"),
                Spec(kind: .file, text: nil, age: day + 5 * hour, source: "Finder", colorHex: "#1E9BF0",
                     filePaths: ["/Users/demo/Documents/Q3-Review.key"]),
                Spec(kind: .text, text: "pnpm dlx shadcn@latest add button dialog",
                     age: day + 7 * hour, source: "VS Code", colorHex: "#0078D4"),
                Spec(kind: .text, text: "331 Caoxi North Rd, Tower B, 12F, Xuhui, Shanghai",
                     age: day + 14 * hour, source: nil, colorHex: nil),
            ]
        }
        return [
            Spec(kind: .text, text: "【抖音】验证码 482913，5 分钟内有效，请勿泄露给他人。",
                 age: 20, source: nil, colorHex: nil),
            Spec(kind: .text, text: "git rebase -i HEAD~3 && git push --force-with-lease",
                 age: 3 * minute, source: "终端", colorHex: "#48484A"),
            Spec(kind: .text, text: "周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上，顺便看看新江湾那边场地的报价。",
                 age: 12 * minute, source: "微信", colorHex: "#07C160"),
            linkSpec,
            Spec(kind: .color, text: "#FF9F0A", age: hour, source: "Figma", colorHex: "#A259FF", pinned: true),
            Spec(kind: .image, text: nil, age: hour, source: "预览", colorHex: "#5B8DC9", image: true),
            Spec(kind: .richText,
                 text: "站会纪要 9/4\n· 登录页改版下周灰度\n· 图标最终稿 8a 已定\n· TestFlight 周三发",
                 age: 2 * hour, source: "备忘录", colorHex: "#F7C600"),
            Spec(kind: .file, text: nil, age: day + 5 * hour, source: "访达", colorHex: "#1E9BF0",
                 filePaths: ["/Users/demo/Documents/Q3-复盘.key"]),
            Spec(kind: .text, text: "pnpm dlx shadcn@latest add button dialog",
                 age: day + 7 * hour, source: "VS Code", colorHex: "#0078D4"),
            Spec(kind: .text, text: "上海市徐汇区漕溪北路 331 号中金国际广场 B 座 12 层",
                 age: day + 14 * hour, source: nil, colorHex: nil),
        ]
    }

    /// 中英文版共用同一条链接（design-spec 6.2 注明「原样复用」）
    private static let linkSpec = Spec(
        kind: .link,
        text: "https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass",
        age: 25 * minute, source: "Safari", colorHex: "#1B8EF1"
    )

    /// 「设计 Token」板的六条（6.4）
    private static func tokenBoardSpecs(english: Bool) -> [Spec] {
        [
            Spec(kind: .color, text: "#FF9F0A", age: hour, source: "Figma", colorHex: "#A259FF"),
            Spec(kind: .color, text: "#0A84FF", age: 3 * day, source: "Figma", colorHex: "#A259FF"),
            Spec(kind: .color, text: "#FF2D55", age: 3 * day, source: "Figma", colorHex: "#A259FF"),
            Spec(kind: .text, text: "Color(red: 0.97, green: 0.95, blue: 0.92)",
                 age: 8 * day, source: "Xcode", colorHex: "#1575F9"),
            Spec(kind: .color, text: "#F7F3EA", age: 8 * day, source: "Figma", colorHex: "#A259FF"),
            Spec(kind: .color, text: "#16161A", age: 8 * day, source: "Figma", colorHex: "#A259FF"),
        ]
    }

    /// 「常用地址」3 条 /「命令」12 条 /「发票信息」2 条（6.3）。
    /// 顺序与 `makeBoards` 里第 2、3、4 个板一一对应。
    private static func otherBoardSpecs(english: Bool) -> [[Spec]] {
        let addresses: [Spec] = english
            ? [
                Spec(kind: .text, text: "331 Caoxi North Rd, Tower B, 12F, Xuhui, Shanghai",
                     age: 2 * day, source: "Maps", colorHex: "#34C759"),
                Spec(kind: .text, text: "One Apple Park Way, Cupertino, CA 95014",
                     age: 5 * day, source: "Safari", colorHex: "#1B8EF1"),
                Spec(kind: .text, text: "Room 1204, 88 Century Ave, Pudong, Shanghai 200120",
                     age: 11 * day, source: nil, colorHex: nil),
            ]
            : [
                Spec(kind: .text, text: "上海市徐汇区漕溪北路 331 号中金国际广场 B 座 12 层",
                     age: 2 * day, source: "地图", colorHex: "#34C759"),
                Spec(kind: .text, text: "北京市朝阳区望京东路 6 号浦项中心 A 座 21 层",
                     age: 5 * day, source: "Safari", colorHex: "#1B8EF1"),
                Spec(kind: .text, text: "上海市浦东新区世纪大道 88 号 1204 室，200120",
                     age: 11 * day, source: nil, colorHex: nil),
            ]

        // 命令类内容两种语言一样，只有来源 App 名要切
        let terminal = english ? "Terminal" : "终端"
        let commandTexts = [
            "git rebase -i HEAD~3",
            "git push --force-with-lease",
            "git log --oneline --graph --decorate -20",
            "xcodebuild -scheme Paster -configuration Release build",
            "xcrun simctl list devices available",
            "swift test --parallel",
            "pnpm dlx shadcn@latest add button dialog",
            "brew upgrade --greedy",
            "docker compose up -d --build",
            "rsync -avh --progress ./dist/ deploy@paster:/srv/www/",
            "find . -name \"*.xcresult\" -mtime +7 -delete",
            "defaults write com.apple.dock autohide-delay -float 0",
        ]
        let commands = commandTexts.enumerated().map { index, text in
            Spec(kind: .text, text: text,
                 age: TimeInterval(index + 1) * day / 2,
                 source: index.isMultiple(of: 3) ? "VS Code" : terminal,
                 colorHex: index.isMultiple(of: 3) ? "#0078D4" : "#48484A")
        }

        let billing: [Spec] = english
            ? [
                Spec(kind: .text, text: "Paster Software Ltd · VAT GB 123 4567 89",
                     age: 6 * day, source: "Mail", colorHex: "#1B8EF1"),
                Spec(kind: .text, text: "IBAN GB29 NWBK 6016 1331 9268 19",
                     age: 20 * day, source: nil, colorHex: nil),
            ]
            : [
                Spec(kind: .text, text: "抬头：上海帕斯特信息科技有限公司\n税号：91310115MA1K35XXXX",
                     age: 6 * day, source: "邮件", colorHex: "#1B8EF1"),
                Spec(kind: .text, text: "开户行：招商银行上海分行营业部\n账号：1219 0688 8810 901",
                     age: 20 * day, source: nil, colorHex: nil),
            ]

        return [addresses, commands, billing]
    }

    // MARK: - 资源

    /// 富文本条目要有真的 RTF，详情页的富文本渲染路径才走得通。
    /// 用 NSAttributedString 生成而不是手拼 RTF 串：中文要转义成 `\\uXXXX`，手拼一定出错。
    private static func rtfData(from body: String) -> Data? {
        let attributed = NSMutableAttributedString(
            string: body,
            attributes: [.font: UIFont.systemFont(ofSize: 15)]
        )
        // 首行加粗——设计稿的富文本卡片把第一行当标题
        let nsBody = body as NSString
        let firstLineEnd = nsBody.range(of: "\n").location
        if firstLineEnd != NSNotFound {
            attributed.addAttribute(.font,
                                    value: UIFont.boldSystemFont(ofSize: 16),
                                    range: NSRange(location: 0, length: firstLineEnd))
        }
        return try? attributed.data(from: NSRange(location: 0, length: attributed.length),
                                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    /// 样例截图。尺寸照 design-spec 的 `1284 × 2778 · PNG`，这样元信息行不用作假。
    /// 只画一次并缓存：`-demoData` 里十条卡片共用同一张。
    ///
    /// 渐变照设计 PasterCard 的 `imgBg` 两套值取（浅 `#D9E6F5 → #F3E7D6 60% → #E6DCEF`、
    /// 深 `#2B3646 → #3D3630 60% → #352D3F`），按 `-demoTheme` 选；
    /// 原来那套紫橙深色渐变在浅色截图里明显偏暗，两套值都对不上设计。
    private static let sampleImagePNG: Data = {
        let dark = LaunchOptions.current.demoColorScheme == .dark
        let hexes = dark
            ? ["#2B3646", "#3D3630", "#352D3F"]
            : ["#D9E6F5", "#F3E7D6", "#E6DCEF"]
        let colors = hexes.compactMap { PasterTheme.uiColor(hexString: $0)?.cgColor }

        let size = CGSize(width: 1284, height: 2778)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            guard colors.count == hexes.count,
                  let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors as CFArray,
                                            locations: [0, 0.6, 1]) else { return }
            // 设计写的是 160deg：基本竖直、略微向右下偏
            context.cgContext.drawLinearGradient(gradient,
                                                 start: .zero,
                                                 end: CGPoint(x: size.width * 0.35, y: size.height),
                                                 options: [])
        }
        return image.pngData() ?? Data()
    }()
}
