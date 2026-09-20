import Foundation
import XCTest
@testable import CopyoCore

/// 改名（Paster → Copyo）带来的两处搬迁：本地数据库目录与文件夹同步的子目录。
/// 两者都只是文件操作，可以在临时目录里完整验证。
final class LegacyMigrationTests: XCTestCase {

    private var container: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = FileManager.default.temporaryDirectory
            .appendingPathComponent("CopyoMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: container)
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - 数据库目录

    /// 完整搬迁：store 三件套改名、外部图片目录跟着改名、陌生文件原名搬过去、旧目录清掉
    func testMigratesLegacyStoreDirectory() throws {
        let legacy = container.appendingPathComponent("Paster", isDirectory: true)
        let externalData = legacy.appendingPathComponent(".Paster_SUPPORT/_EXTERNAL_DATA", isDirectory: true)
        try FileManager.default.createDirectory(at: externalData, withIntermediateDirectories: true)
        try "db".write(to: legacy.appendingPathComponent("Paster.store"), atomically: true, encoding: .utf8)
        try "wal".write(to: legacy.appendingPathComponent("Paster.store-wal"), atomically: true, encoding: .utf8)
        try "shm".write(to: legacy.appendingPathComponent("Paster.store-shm"), atomically: true, encoding: .utf8)
        try "png".write(to: externalData.appendingPathComponent("blob"), atomically: true, encoding: .utf8)
        try "note".write(to: legacy.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        XCTAssertEqual(LegacyStoreMigration.migrateIfNeeded(in: container), .migrated)

        let new = container.appendingPathComponent("Copyo", isDirectory: true)
        XCTAssertEqual(try String(contentsOf: new.appendingPathComponent("Copyo.store"), encoding: .utf8), "db")
        XCTAssertEqual(try String(contentsOf: new.appendingPathComponent("Copyo.store-wal"), encoding: .utf8), "wal")
        XCTAssertEqual(try String(contentsOf: new.appendingPathComponent("Copyo.store-shm"), encoding: .utf8), "shm")
        // 外部二进制目录名由 store 文件名推导，不一起改名等于把所有图片藏起来
        XCTAssertEqual(try String(contentsOf: new.appendingPathComponent(".Copyo_SUPPORT/_EXTERNAL_DATA/blob"), encoding: .utf8),
                       "png")
        XCTAssertEqual(try String(contentsOf: new.appendingPathComponent("notes.txt"), encoding: .utf8), "note")
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path), "搬空后旧目录应当删掉")
    }

    /// 新库已经在用了：一个字节都不许动，否则旧数据会盖掉新数据
    func testKeepsNewStoreWhenAlreadyMigrated() throws {
        let legacy = container.appendingPathComponent("Paster", isDirectory: true)
        let new = container.appendingPathComponent("Copyo", isDirectory: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        try "old".write(to: legacy.appendingPathComponent("Paster.store"), atomically: true, encoding: .utf8)
        try "new".write(to: new.appendingPathComponent("Copyo.store"), atomically: true, encoding: .utf8)

        XCTAssertEqual(LegacyStoreMigration.migrateIfNeeded(in: container), .alreadyMigrated)
        XCTAssertEqual(try String(contentsOf: new.appendingPathComponent("Copyo.store"), encoding: .utf8), "new")
        XCTAssertEqual(try String(contentsOf: legacy.appendingPathComponent("Paster.store"), encoding: .utf8), "old")
    }

    func testNothingToDoOnFreshInstall() throws {
        XCTAssertEqual(LegacyStoreMigration.migrateIfNeeded(in: container), .nothingToDo)

        let url = try CopyoStore.storeURL(in: container)
        XCTAssertEqual(url.path,
                       container.appendingPathComponent("Copyo", isDirectory: true)
                           .appendingPathComponent("Copyo.store").path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }

    /// 搬不动时必须退回旧位置继续用：目录名难看好过让用户的历史消失
    func testStoreURLFallsBackToLegacyWhenMigrationFails() throws {
        let legacy = container.appendingPathComponent("Paster", isDirectory: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try "db".write(to: legacy.appendingPathComponent("Paster.store"), atomically: true, encoding: .utf8)
        // 目标目录的位置被一个普通文件占着，createDirectory 必然失败
        try "blocker".write(to: container.appendingPathComponent("Copyo"), atomically: true, encoding: .utf8)

        XCTAssertEqual(LegacyStoreMigration.migrateIfNeeded(in: container),
                       .failed(legacyStoreURL: legacy.appendingPathComponent("Paster.store")))
        XCTAssertEqual(try CopyoStore.storeURL(in: container),
                       legacy.appendingPathComponent("Paster.store"))
    }

    func testMigratedNameMapping() {
        XCTAssertEqual(LegacyStoreMigration.migratedName(for: "Paster.store"), "Copyo.store")
        XCTAssertEqual(LegacyStoreMigration.migratedName(for: "Paster.store-wal"), "Copyo.store-wal")
        XCTAssertEqual(LegacyStoreMigration.migratedName(for: ".Paster_SUPPORT"), ".Copyo_SUPPORT")
        // 不是这两类的名字不猜，原样搬过去
        XCTAssertEqual(LegacyStoreMigration.migratedName(for: "PasterBackup.zip"), "PasterBackup.zip")
        XCTAssertEqual(LegacyStoreMigration.migratedName(for: "notes.txt"), "notes.txt")
    }

    // MARK: - 同步目录

    func testPrepareRootRenamesLegacySyncFolder() throws {
        let legacy = container.appendingPathComponent("Paster", isDirectory: true)
        try FileManager.default.createDirectory(at: legacy.appendingPathComponent("assets", isDirectory: true),
                                                withIntermediateDirectories: true)
        try "{}".write(to: legacy.appendingPathComponent("device-A.json"), atomically: true, encoding: .utf8)

        let root = SyncFolderLayout.prepareRoot(in: container)
        XCTAssertEqual(root, container.appendingPathComponent("Copyo", isDirectory: true))
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("device-A.json"), encoding: .utf8), "{}")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("assets").path))
        XCTAssertNil(SyncFolderLayout.legacyRoot(in: container), "改名之后不该再有旧目录")
    }

    /// 没升级的 Mac 会把 Paster/ 重新建起来：新目录已存在时不动它，旧目录留着给只读合并
    func testPrepareRootKeepsBothWhenNewFolderExists() throws {
        let legacy = container.appendingPathComponent("Paster", isDirectory: true)
        let new = container.appendingPathComponent("Copyo", isDirectory: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        try "{}".write(to: legacy.appendingPathComponent("device-B.json"), atomically: true, encoding: .utf8)

        XCTAssertEqual(SyncFolderLayout.prepareRoot(in: container), new)
        XCTAssertEqual(SyncFolderLayout.legacyRoot(in: container), legacy)
        XCTAssertEqual(try String(contentsOf: legacy.appendingPathComponent("device-B.json"), encoding: .utf8), "{}")
    }

    func testPrepareRootCreatesFolderOnFreshInstall() {
        let root = SyncFolderLayout.prepareRoot(in: container)
        XCTAssertEqual(root, container.appendingPathComponent("Copyo", isDirectory: true))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
        XCTAssertNil(SyncFolderLayout.legacyRoot(in: container))
    }
}
