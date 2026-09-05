import Foundation
import SwiftData
import XCTest
@testable import PasterCore

final class PasterCoreTests: XCTestCase {

    /// 内存容器要活到测试结束：ModelContainer 一旦释放，从它取出的 context 就跟着失效
    private var containers: [ModelContainer] = []

    override func tearDown() {
        containers.removeAll()
        super.tearDown()
    }

    /// 在临时目录建真实存储的容器，插入两类模型后读回，验证 schema 与关系可用
    @MainActor
    func testInsertAndFetchModels() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PasterCoreTests-\(UUID().uuidString)")
            .appendingPathComponent("Paster.store")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let schema = Schema(PasterSchema.models)
        let config = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        let board = Pinboard(name: "Snippets", sortIndex: 0)
        context.insert(board)

        let item = ClipItem(kind: .link,
                            plainText: "https://example.com",
                            sourceAppBundleID: "dev.vibemage.Paster",
                            sourceAppName: "Paster")
        item.pinboard = board
        context.insert(item)
        try context.save()

        let items = try context.fetch(FetchDescriptor<ClipItem>())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.kind, .link)
        XCTAssertEqual(items.first?.plainText, "https://example.com")
        XCTAssertEqual(items.first?.charCount, "https://example.com".count)
        XCTAssertEqual(items.first?.pinboard?.name, "Snippets")

        let boards = try context.fetch(FetchDescriptor<Pinboard>())
        XCTAssertEqual(boards.count, 1)
        XCTAssertEqual(boards.first?.items?.count, 1)
    }

    /// 兼容性回归：把本机现有数据库拷到临时目录，用 PasterSchema 打开副本并读出条目。
    /// 模型移到 PasterCore 后实体名若发生变化，这里会因为读不到数据而失败。
    @MainActor
    func testOpenExistingStoreCopy() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let sourceDirectory = appSupport.appendingPathComponent("Paster", isDirectory: true)
        let sourceStore = sourceDirectory.appendingPathComponent("Paster.store")
        guard FileManager.default.fileExists(atPath: sourceStore.path) else {
            throw XCTSkip("本机没有现有数据库，跳过兼容性检查")
        }

        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PasterCoreStoreCopy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDirectory) }

        // 三个文件按存在情况逐个拷贝：-shm/-wal 只有数据库打开过才有
        for name in ["Paster.store", "Paster.store-shm", "Paster.store-wal"] {
            let source = sourceDirectory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try FileManager.default.copyItem(at: source, to: workDirectory.appendingPathComponent(name))
        }

        let schema = Schema(PasterSchema.models)
        let config = ModelConfiguration(schema: schema, url: workDirectory.appendingPathComponent("Paster.store"))
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let count = try context.fetchCount(FetchDescriptor<ClipItem>())
        XCTAssertGreaterThan(count, 0, "现有数据库里应当能读出条目")

        var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        let newest = try XCTUnwrap(try context.fetch(descriptor).first)
        XCTAssertTrue(ClipKind.allCases.contains(newest.kind), "类型应当是已知枚举值")
        XCTAssertEqual(newest.kindRaw, newest.kind.rawValue, "存储的类型字符串应当能还原成枚举")
        XCTAssertGreaterThan(newest.createdAt.timeIntervalSince1970, 0, "创建时间应当是合理时间戳")
        XCTAssertLessThanOrEqual(newest.createdAt, Date().addingTimeInterval(60), "创建时间不应当在未来")
        if newest.kind == .text || newest.kind == .richText || newest.kind == .link || newest.kind == .color {
            XCTAssertNotNil(newest.plainText, "文本类条目应当有正文")
        }

        // Pinboard 一并读一次，确认关系模型也在同一个库里可用
        _ = try context.fetchCount(FetchDescriptor<Pinboard>())
    }

    func testClassify() {
        XCTAssertEqual(ClipClassifier.classify(text: "#FF8800", hasRTF: false), .color)
        XCTAssertEqual(ClipClassifier.classify(text: "#FF8800CC", hasRTF: false), .color)
        XCTAssertEqual(ClipClassifier.classify(text: "https://example.com", hasRTF: false), .link)
        XCTAssertEqual(ClipClassifier.classify(text: "ftp://example.com", hasRTF: false), .text)
        XCTAssertEqual(ClipClassifier.classify(text: "hello world", hasRTF: true), .richText)
        XCTAssertEqual(ClipClassifier.classify(text: "hello world", hasRTF: false), .text)
    }

    func testContentHash() {
        XCTAssertEqual(ContentHash.sha256(Data()),
                       "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    // MARK: - 新增字段

    /// 新加的三个可选字段：默认为空（老数据读上来就是这样），显式写入后能读回
    @MainActor
    func testNewOptionalFieldDefaults() throws {
        let context = try makeMemoryContext()

        let plain = ClipItem(kind: .text, plainText: "hello")
        context.insert(plain)
        XCTAssertNil(plain.sourceColorHex, "没指定来源色时应当为空，iOS 本机条目就是这种")

        let fromApp = ClipItem(kind: .text,
                               plainText: "hi",
                               sourceAppBundleID: "com.example.App",
                               sourceAppName: "App",
                               sourceColorHex: "#07C160")
        context.insert(fromApp)

        let board = Pinboard(name: "Colors", sortIndex: 0)
        context.insert(board)
        XCTAssertNil(board.iconName)
        XCTAssertNil(board.colorHex)
        board.iconName = "paintpalette"
        board.colorHex = "#FF9F0A"
        try context.save()

        let items = try context.fetch(FetchDescriptor<ClipItem>())
        XCTAssertEqual(items.compactMap(\.sourceColorHex), ["#07C160"])
        let boards = try context.fetch(FetchDescriptor<Pinboard>())
        XCTAssertEqual(boards.first?.iconName, "paintpalette")
        XCTAssertEqual(boards.first?.colorHex, "#FF9F0A")
    }

    func testHexColorString() {
        XCTAssertEqual(HexColor.string(red: 0, green: 0, blue: 0), "#000000")
        XCTAssertEqual(HexColor.string(red: 1, green: 1, blue: 1), "#FFFFFF")
        XCTAssertEqual(HexColor.string(red: 7.0 / 255, green: 193.0 / 255, blue: 96.0 / 255), "#07C160")
        // 越界分量要夹回 0...1，否则格式化出来的串解析不回颜色
        XCTAssertEqual(HexColor.string(red: -1, green: 2, blue: 0.5), "#00FF80")
    }

    // MARK: - ClipSaver

    /// 同一段文本再存一次：不新增条目，只更新时间与来源，且保留已固定的 Pinboard
    @MainActor
    func testClipSaverRefreshesDuplicateText() throws {
        let context = try makeMemoryContext()
        let board = Pinboard(name: "Snippets", sortIndex: 0)
        context.insert(board)

        let first = try ClipSaver.save(text: "same text",
                                       source: ClipSource(appName: "A", bundleID: "com.a", colorHex: "#111111"),
                                       historyLimit: nil,
                                       in: context)
        guard case .inserted(let item) = first else { return XCTFail("第一次保存应当是新增") }
        item.pinboard = board
        let originalDate = item.createdAt
        try context.save()

        let second = try ClipSaver.save(text: "same text",
                                        source: ClipSource(appName: "B", bundleID: "com.b", colorHex: "#222222"),
                                        historyLimit: nil,
                                        in: context)
        guard case .refreshed(let refreshed) = second else { return XCTFail("重复内容应当命中去重") }

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ClipItem>()), 1)
        XCTAssertTrue(refreshed === item, "应当复用同一条记录而不是新建")
        XCTAssertGreaterThan(refreshed.createdAt, originalDate, "命中去重要把条目提到最前")
        XCTAssertEqual(refreshed.sourceAppName, "B")
        XCTAssertEqual(refreshed.sourceColorHex, "#222222", "来源色要跟着最近一次采集更新")
        XCTAssertEqual(refreshed.pinboard?.name, "Snippets", "重复复制不该把条目踢出 Pinboard")
    }

    /// 分类由 ClipSaver 内部完成；不同内容各自入库
    @MainActor
    func testClipSaverClassifiesAndSeparatesContent() throws {
        let context = try makeMemoryContext()
        _ = try ClipSaver.save(text: "https://example.com", source: .local, historyLimit: nil, in: context)
        _ = try ClipSaver.save(text: "#FF8800", source: .local, historyLimit: nil, in: context)
        _ = try ClipSaver.save(text: "plain", rtfData: Data([0x01]), source: .local, historyLimit: nil, in: context)

        let kinds = try context.fetch(FetchDescriptor<ClipItem>()).map(\.kind)
        XCTAssertEqual(Set(kinds), [.link, .color, .richText])
        XCTAssertThrowsError(try ClipSaver.save(text: "   \n ", source: .local, historyLimit: nil, in: context),
                             "空白内容不该入库")
    }

    /// 图片按内容哈希去重
    @MainActor
    func testClipSaverDeduplicatesImagesByHash() throws {
        let context = try makeMemoryContext()
        let png = Data("fake-png-bytes".utf8)

        let first = try ClipSaver.save(imagePNG: png, source: .local, historyLimit: nil, in: context)
        XCTAssertTrue(first.isNew)
        XCTAssertEqual(first.item.imageHash, ContentHash.sha256(png))

        let second = try ClipSaver.save(imagePNG: png, source: .local, historyLimit: nil, in: context)
        XCTAssertFalse(second.isNew, "同一张图应当命中去重")

        _ = try ClipSaver.save(imagePNG: Data("another".utf8), source: .local, historyLimit: nil, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ClipItem>()), 2)
    }

    /// 上限只清理未固定条目，且从最旧的开始
    @MainActor
    func testClipSaverEnforcesHistoryLimit() throws {
        let context = try makeMemoryContext()
        let board = Pinboard(name: "Keep", sortIndex: 0)
        context.insert(board)

        // 显式排定创建时间，避免连续插入时的时间戳过于接近导致顺序不确定
        var items: [ClipItem] = []
        for index in 0..<6 {
            let result = try ClipSaver.save(text: "entry \(index)", source: .local, historyLimit: nil, in: context)
            result.item.createdAt = Date(timeIntervalSince1970: 1_000 + Double(index))
            items.append(result.item)
        }
        items[0].pinboard = board // 最旧的一条被固定，不该被清理
        try context.save()

        try ClipSaver.enforceHistoryLimit(3, in: context)

        let remaining = try context.fetch(FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt)]))
        XCTAssertEqual(remaining.map(\.plainText), ["entry 0", "entry 3", "entry 4", "entry 5"])
        XCTAssertEqual(remaining.first?.pinboard?.name, "Keep")

        // 保存路径自带清理：再存一条后未固定条目仍是 3
        _ = try ClipSaver.save(text: "entry 6", source: .local, historyLimit: 3, in: context)
        let unpinned = try context.fetchCount(FetchDescriptor<ClipItem>(predicate: #Predicate { $0.pinboard == nil }))
        XCTAssertEqual(unpinned, 3)

        // 0 与负数表示不限制
        try ClipSaver.enforceHistoryLimit(0, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ClipItem>()), 4)
    }

    // MARK: - 代码识别与展示派生值

    func testLooksLikeCode() {
        let code = [
            "git commit -m \"fix crash\"",
            "npm install --save-dev typescript",
            "brew install ripgrep && brew cleanup",
            "xcodebuild -project Paster.xcodeproj -scheme Paster build",
            "cat Package.swift | grep platforms",
            "import Foundation",
            "func classify(text: String) -> ClipKind {\n    return .text\n}",
            "const timeout = 30;\nconst retries = 3;",
            "{\n  \"name\": \"paster\",\n  \"version\": \"1.0.0\"\n}",
            "$ swift test",
            "docker run -it --rm ubuntu bash",
        ]
        for sample in code {
            XCTAssertTrue(ClipClassifier.looksLikeCode(sample), "应当识别为代码：\(sample)")
        }

        let prose = [
            "今天下午三点开会，记得把设计稿带上",
            "The quick brown fox jumps over the lazy dog.",
            "Let me know if you need anything else, I will be around all day.",
            "会议纪要：下周一上线，需要产品和设计各自确认一遍",
            "Paster is an open source clipboard manager for the Mac.",
            "https://example.com/docs/getting-started",
            "地址：北京市朝阳区建国路 88 号",
            "",
            "1234567890",
            "Find the report and open it before the meeting",
            "| Mac 版能力 | iOS 现状 | 替代方案 |",
            "/Users/me/Documents/2026 年度总结.pdf",
        ]
        for sample in prose {
            XCTAssertFalse(ClipClassifier.looksLikeCode(sample), "不应当识别为代码：\(sample)")
        }
    }

    func testDisplayHelpers() {
        let link = ClipItem(kind: .link, plainText: " https://www.example.com/a/b?q=1 ")
        XCTAssertEqual(link.linkURL?.absoluteString, "https://www.example.com/a/b?q=1")
        XCTAssertEqual(link.linkDomain, "example.com", "域名要去掉 www.")
        XCTAssertEqual(link.displayTitle, "example.com")

        let bareHost = ClipItem(kind: .link, plainText: "https://docs.example.co.uk/guide")
        XCTAssertEqual(bareHost.linkDomain, "docs.example.co.uk")

        let text = ClipItem(kind: .text, plainText: "\n\n  第一行标题  \n第二行")
        XCTAssertNil(text.linkURL, "非链接条目不给 URL")
        XCTAssertNil(text.linkDomain)
        XCTAssertEqual(text.displayTitle, "第一行标题")
        XCTAssertFalse(text.isCodeLike)

        let command = ClipItem(kind: .text, plainText: "git push origin main")
        XCTAssertTrue(command.isCodeLike)

        let color = ClipItem(kind: .color, plainText: " #ff8800 ")
        XCTAssertEqual(color.displayTitle, "#FF8800")

        let file = ClipItem(kind: .file,
                            plainText: "/Users/me/Documents/report.pdf",
                            filePaths: ["/Users/me/Documents/report.pdf", "/Users/me/notes.txt"])
        XCTAssertEqual(file.displayTitle, "report.pdf")

        let image = ClipItem(kind: .image, imageData: Data([0x00]))
        XCTAssertEqual(image.displayTitle, "", "图片的占位文案要本地化，这里只给空串")
        XCTAssertFalse(image.isCodeLike)

        let long = ClipItem(kind: .text, plainText: String(repeating: "a", count: 500))
        XCTAssertEqual(long.displayTitle.count, 200, "标题最多 200 字")
    }

    // MARK: - 辅助

    @MainActor
    private func makeMemoryContext() throws -> ModelContext {
        let schema = Schema(PasterSchema.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        containers.append(container)
        return container.mainContext
    }
}
