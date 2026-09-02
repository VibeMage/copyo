import Foundation
import SwiftData
import XCTest
@testable import PasterCore

final class PasterCoreTests: XCTestCase {

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
}
