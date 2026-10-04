import XCTest
import CryptoKit
@testable import LifeLedger

@MainActor
final class LedgerTests: XCTestCase {
    private var directory: URL!
    private var store: LedgerStore!
    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = LedgerStore(root: directory)
    }
    override func tearDown() async throws { try? FileManager.default.removeItem(at: directory) }
    func add(completed: Bool = false) -> Achievement {
        let item = Achievement(title: "Test", detail: "A real moment")
        XCTAssertTrue(store.save(item))
        if completed { store.complete(item.id) }
        return item
    }
    func testCatalogAndTranslations() {
        XCTAssertEqual(Catalog.presets.count, 109)
        XCTAssertEqual(Set(Catalog.presets.map(\.id)).count, 109)
        XCTAssertEqual(Set(Catalog.presets.map(\.category)).count, 14)
        for preset in Catalog.presets { XCTAssertNotNil(Catalog.english[String(preset.id)]?["t"]) }
        XCTAssertEqual(Rarity(rate: 50), .silver)
        XCTAssertEqual(Rarity(rate: 20), .gold)
        XCTAssertEqual(Rarity(rate: 10), .platinum)
        XCTAssertEqual(Rarity(rate: 5), .legendary)
    }
    func testCompletionIsIdempotentAndRepeatable() {
        let item = add()
        store.complete(item.id); store.complete(item.id)
        XCTAssertEqual(store.balance, 50)
        XCTAssertEqual(store.data.points.count, 1)
        store.complete(item.id, date: nil); store.complete(item.id, date: nil)
        XCTAssertEqual(store.balance, 0)
        store.complete(item.id)
        XCTAssertEqual(store.balance, 50)
        XCTAssertEqual(store.data.points.map(\.amount), [50, -50, 50])
    }
    func testDateAdjustmentDoesNotAwardAgain() {
        let item = add(completed: true)
        let date = Date(timeIntervalSince1970: 1234567890)
        store.complete(item.id, date: date)
        XCTAssertEqual(store.balance, 50)
        XCTAssertEqual(store.data.achievements[0].completedAt, date)
    }
    func testRewardsRefundAndInsufficientBalance() {
        let reward = store.data.rewards[0]
        store.redeem(reward)
        XCTAssertEqual(store.data.redemptions.count, 0)
        _ = add(completed: true); _ = add(completed: true)
        store.redeem(reward)
        XCTAssertEqual(store.balance, 0)
        let redemption = store.data.redemptions[0]
        store.refund(redemption.id); store.refund(redemption.id)
        XCTAssertEqual(store.balance, 100)
        XCTAssertEqual(store.data.points.map(\.amount), [50, 50, -100, 100])
    }
    func testTaskCannotAwardTwice() {
        let goal = Goal(title: "Learn", due: Date())
        let task = GoalTask(goalID: goal.id, title: "Read")
        XCTAssertTrue(store.change { $0.goals.append(goal); $0.tasks.append(task) })
        store.completeTask(task.id); store.completeTask(task.id)
        XCTAssertEqual(store.balance, 10)
    }
    func testDeletionCascadesMediaAndReversesCompletion() throws {
        let item = add(completed: true)
        let path = "media/example.jpg", url = store.mediaURL(path)
        try Data([1, 2, 3]).write(to: url)
        let note = Note(achievementID: item.id, text: "Note", attachments: [Attachment(path: path, kind: "image")])
        XCTAssertTrue(store.saveNote(note))
        store.deleteAchievement(item.id)
        XCTAssertTrue(store.data.notes.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(store.balance, 0)
    }
    func testPersistenceAndLocalEncryption() throws {
        let item = add()
        XCTAssertEqual(LedgerStore(root: directory).data.achievements.first?.id, item.id)
        XCTAssertTrue(store.change { $0.preferences.encryptLocalData = true }, store.error ?? "")
        let bytes = try Data(contentsOf: directory.appendingPathComponent("ledger.json"))
        XCTAssertTrue(bytes.starts(with: LedgerSecurity.localMagic))
        XCTAssertFalse(String(data: bytes, encoding: .utf8)?.contains("A real moment") ?? false)
        XCTAssertEqual(LedgerStore(root: directory).data.achievements[0].title, "Test")
        XCTAssertTrue(store.change { $0.preferences.encryptLocalData = false })
        XCTAssertFalse(try Data(contentsOf: directory.appendingPathComponent("ledger.json")).starts(with: LedgerSecurity.localMagic))
    }
    func testEncryptedBackupRoundtripIncludesGrowthAndMedia() throws {
        let item = add(completed: true)
        let path = "media/fixture.png", content = Data([5, 4, 3, 2, 1])
        try content.write(to: store.mediaURL(path))
        XCTAssertTrue(store.saveNote(Note(achievementID: item.id, text: "Memory", attachments: [Attachment(path: path, kind: "image")])))
        let goal = Goal(title: "Study", due: Date())
        let task = GoalTask(goalID: goal.id, title: "Read")
        let reward = Reward(title: "Tea", icon: "🍵", category: "生活", price: 25)
        XCTAssertTrue(store.change { $0.goals.append(goal); $0.tasks.append(task); $0.rewards.append(reward) })
        store.completeTask(task.id)
        store.redeem(reward)
        let original = store.data
        let bytes = try BackupService.make(state: original, root: directory, password: "中文 password")
        XCTAssertTrue(bytes.starts(with: LedgerSecurity.backupMagic))
        XCTAssertThrowsError(try BackupService.prepare(bytes: bytes, password: "wrong"))
        let backup = try BackupService.prepare(bytes: bytes, password: "中文 password")
        XCTAssertEqual(backup.state, try LedgerCodec.decode(LedgerData.self, from: LedgerCodec.encode(original)))
        XCTAssertEqual(backup.files[path], content)
        store.deleteAchievement(item.id)
        try store.restore(backup)
        XCTAssertEqual(store.data.achievements, backup.state.achievements)
        XCTAssertEqual(store.balance, 35)
        XCTAssertEqual(store.data.tasks.count, 1)
        XCTAssertEqual(store.data.goals.count, 1)
        XCTAssertEqual(store.data.redemptions.count, 1)
        XCTAssertEqual(try Data(contentsOf: store.mediaURL(path)), content)
    }
    func testDamagedRestoreLeavesCurrentLedgerUntouched() throws {
        _ = add(completed: true)
        let original = store.data
        let file = try Data(contentsOf: directory.appendingPathComponent("ledger.json"))
        var invalid = original
        invalid.notes = [Note(achievementID: invalid.achievements[0].id, text: "Missing", attachments: [Attachment(path: "media/missing.jpg", kind: "image")])]
        let zip = try ZipArchive.pack(["backup.json": LedgerCodec.encode(IOSBackup(data: invalid))])
        XCTAssertThrowsError(try BackupService.prepare(bytes: zip, password: ""))
        XCTAssertEqual(store.data, original)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("ledger.json")), file)
    }
    func testAndroidDeflatedBackupWithDataDescriptors() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "android_fixture", withExtension: "zip"))
        let backup = try BackupService.prepare(bytes: Data(contentsOf: url), password: "")
        XCTAssertTrue(backup.isAndroid)
        XCTAssertEqual(backup.state.profile.nickname, "Android 用户")
        XCTAssertEqual(backup.state.achievements.count, 1)
        XCTAssertEqual(backup.state.points.reduce(0) { $0 + $1.amount }, 50)
        let attachment = try XCTUnwrap(backup.state.notes.first?.attachments.first)
        XCTAssertNotNil(backup.files[attachment.path])
        try store.restore(backup)
        XCTAssertEqual(try Data(contentsOf: store.mediaURL(attachment.path)), Data([1, 2, 3]))
    }
    func testArchiveRejectsTraversalAndCorruption() throws {
        XCTAssertThrowsError(try ZipArchive.pack(["../escape.txt": Data([1])]))
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "unsafe_fixture", withExtension: "zip"))
        XCTAssertThrowsError(try ZipArchive.unpack(Data(contentsOf: url)))
        var valid = try ZipArchive.pack(["file.txt": Data("Hello".utf8)])
        valid[38] ^= 1
        XCTAssertThrowsError(try ZipArchive.unpack(valid))
    }
    func testDSTStreakAndLevel() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let dates = (1...3).map { day in calendar.date(from: DateComponents(year: 2025, month: 11, day: day, hour: 12))! }
        let items = dates.map { Achievement(title: "Done", completedAt: $0) }
        let stats = LifeStats(achievements: items)
        XCTAssertEqual(stats.streak(now: dates[2], calendar: calendar), 3)
        XCTAssertEqual(stats.toNext, 2)
        XCTAssertEqual(stats.level, 1)
        XCTAssertEqual(LifeStats(achievements: Array(repeating: items[0], count: 5)).level, 2)
    }
    func testUnreadableExistingDataIsNeverOverwritten() throws {
        let bad = Data("not valid JSON".utf8)
        try bad.write(to: directory.appendingPathComponent("ledger.json"))
        let broken = LedgerStore(root: directory)
        XCTAssertTrue(broken.loadFailed)
        XCTAssertFalse(broken.change { $0.onboarded = true })
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("ledger.json")), bad)
    }
}
