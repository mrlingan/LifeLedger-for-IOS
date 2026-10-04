import XCTest

final class LifeLedgerUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication(); app.launchArguments = ["--uitesting", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] }
    func testCreateCompleteAndAddNote() throws {
        app.launch()
        XCTAssertTrue(app.buttons["startEmpty"].waitForExistence(timeout: 10))
        app.buttons["startEmpty"].tap()
        app.buttons["addAchievement"].tap()
        let title = app.textFields["achievementTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("My first iOS achievement")
        app.buttons["saveAchievement"].tap()
        app.tabBars.buttons["我的"].tap()
        let records = app.buttons["全部成就"]
        for _ in 0..<6 { if records.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(records.isHittable); records.tap()
        XCTAssertTrue(app.staticTexts["My first iOS achievement"].waitForExistence(timeout: 5))
        app.staticTexts["My first iOS achievement"].tap()
        app.buttons["标记完成 · +50 XP"].tap()
        app.buttons["confirmCompletion"].tap()
        XCTAssertTrue(app.buttons["已完成 · 管理状态"].waitForExistence(timeout: 5))
        app.buttons["写笔记"].tap()
        let note = app.textViews["noteText"]
        XCTAssertTrue(note.waitForExistence(timeout: 5)); note.tap(); note.typeText("A moment worth remembering")
        app.buttons["saveNote"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["A moment worth remembering"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Achievement with note"; shot.lifetime = .keepAlways; add(shot)
    }
    func testCatalogSearchAndAllTabs() throws {
        app.launch()
        XCTAssertTrue(app.buttons["startPresets"].waitForExistence(timeout: 10)); app.buttons["startPresets"].tap()
        let home = XCTAttachment(screenshot: app.screenshot()); home.name = "Native home"; home.lifetime = .keepAlways; add(home)
        XCTAssertTrue(app.tabBars.buttons["图鉴"].waitForExistence(timeout: 10)); app.tabBars.buttons["图鉴"].tap()
        XCTAssertTrue(app.staticTexts["成就图鉴"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Codex"; shot.lifetime = .keepAlways; add(shot)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.exists); search.tap(); search.typeText("全款置业")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "全款置业")).firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["成长"].tap()
        XCTAssertTrue(app.staticTexts["我的成长"].waitForExistence(timeout: 5))
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["我的档案"].waitForExistence(timeout: 5))
    }
    func testNativeSettingsAndICloudSavePicker() throws {
        app.launch()
        XCTAssertTrue(app.buttons["startEmpty"].waitForExistence(timeout: 10))
        app.buttons["startEmpty"].tap()
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        app.buttons["settings"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["开发者选项"].exists)
        app.buttons["备份与恢复"].tap()
        let backup = app.buttons["backupToICloud"]
        XCTAssertTrue(backup.waitForExistence(timeout: 5))
        backup.tap()
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 15))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Native iCloud Drive save dialog"; attachment.lifetime = .keepAlways; add(attachment)
        // The system remembers the last folder; cancel is on the locations screen.
        let browse = app.buttons.matching(NSPredicate(format: "label IN %@", ["浏览", "Browse"])).firstMatch
        if browse.exists { browse.tap() }
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["取消", "Cancel", "关闭", "Close"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), app.debugDescription)
        cancel.tap()
        XCTAssertTrue(backup.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "备份已保存")).firstMatch.exists)
        backup.tap()
        XCTAssertTrue(filename.waitForExistence(timeout: 15))
        let save = app.buttons["DOCPicker.actionButton"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "备份已保存")).firstMatch.waitForExistence(timeout: 10))

    }

}
