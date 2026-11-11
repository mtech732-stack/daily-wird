import XCTest

/// ش6 · المرحلة 3: الإعدادات و«عن التطبيق» (7.4 · 5.8 · 8.3، design/system.md §17.3، ذ50، م53).
@MainActor
final class SettingsUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed", "farReview:1-9;nearReview:10-11;new:12",
                               "-readings", "37:0", "-pages", "112-116:3"] + extra
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func any(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func wait(_ element: XCUIElement, _ format: String, _ args: [Any] = [], timeout: TimeInterval = 20) -> Bool {
        let e = XCTNSPredicateExpectation(predicate: NSPredicate(format: format, argumentArray: args), object: element)
        return XCTWaiter().wait(for: [e], timeout: timeout) == .completed
    }

    private func expectContains(_ element: XCUIElement, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        if !wait(element, "label CONTAINS %@", [text]) {
            XCTAssertTrue(false, "«\(element.exists ? element.label : "(غير ظاهر)")» لا يحوي «\(text)»", file: file, line: line)
        }
    }

    /// يضغط الترس حتى تظهر الورقة، ويعيد الضغط مرة إن لم تصل (#43).
    private func openSettings(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let gear = app.buttons["home.settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 20), "لا ترس", file: file, line: line)
        gear.tap()
        let title = any(app, "settings.title")
        if !title.waitForExistence(timeout: 10) { gear.tap() }
        XCTAssertTrue(title.waitForExistence(timeout: 20), "لم تُفتح الإعدادات", file: file, line: line)
    }

    /// 7.4 و§17.3: الترس يفتح الإعدادات، وفيها حالة النسخ «في هذا الجهاز» بنصّ م53 بلا اسم الشريحة،
    /// والإصدار من حزمة التطبيق، و«عن التطبيق». ولا إعدادات ورد ولا اختيار للوضع الليلي (12). و«تمّ» يغلقها.
    func test_7_4_gearOpensSettings() {
        let app = launch()
        openSettings(app)
        let backup = any(app, "settings.backup.device")
        XCTAssertTrue(backup.waitForExistence(timeout: 20), "حالة النسخ قبل ش7: في هذا الجهاز")
        expectContains(backup, "سجلّك محفوظ في هذا الجهاز")
        let note = app.staticTexts["settings.backup.note"]
        XCTAssertTrue(note.waitForExistence(timeout: 20))
        XCTAssertEqual(note.label, "النسخ إلى iCloud يأتي في تحديث قريب، ويُنقل إليه سجلّك كما هو.")
        XCTAssertFalse(note.label.contains("ش7"), "لا اسم داخلي في نصّ يقرؤه المالك (م53)")
        expectContains(any(app, "settings.version"), "الإصدار")
        XCTAssertTrue(app.buttons["settings.about"].exists)
        for word in ["الوضع الليلي", "المظهر", "الورد اليومي"] {
            XCTAssertFalse(app.staticTexts[word].exists, "لا «\(word)» في الإعدادات")
        }
        shot(app, "82-settings")

        app.buttons["settings.done"].tap()
        XCTAssertTrue(wait(any(app, "settings.title"), "exists == false"), "«تمّ» يغلق الورقة")
    }

    /// 7.4 و§17.3: «عن التطبيق» تُدفع داخل الورقة، وفيها مصدر البيانات ونسبة «تنزيل» برخصتها،
    /// وأيقونة التطبيق واسمه وإصداره (ذ53). ولا اسم للمالك ولا شعار، فالتطبيق عامّ (القرار 32). و«‹ الإعدادات» يرجع.
    func test_7_4_aboutInsideSettings() {
        let app = launch()
        openSettings(app)
        app.buttons["settings.about"].tap()
        let source = any(app, "about.source")
        XCTAssertTrue(source.waitForExistence(timeout: 20), "لم تُفتح «عن التطبيق»")
        expectContains(source, "«تنزيل» المفتوحة، على مصحف المدينة النبوية")
        expectContains(source, "26 حدّاً على طبعة مجمّع الملك فهد")
        expectContains(source, "Tanzil.net · رخصة CC BY 3.0")
        expectContains(app.staticTexts["about.name"], "الورد اليومي")
        expectContains(app.staticTexts["about.app"], "الإصدار ")
        let owner = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'المالك (' OR label CONTAINS 'س8'"))
        XCTAssertEqual(owner.count, 0, "لا اسم للمالك ولا شعار (القرار 32)")
        shot(app, "83-about")

        app.buttons["about.back"].tap()
        XCTAssertTrue(app.buttons["settings.about"].waitForExistence(timeout: 20), "«‹ الإعدادات» يرجع داخل الورقة")
        XCTAssertTrue(wait(source, "exists == false"))
    }

    /// 5.8 و8.3 (ذ50): حالتا iCloud بنصّهما، و«متوقّف» بنصّ الوثيقة حرفاً. والحالة بشكل الشارة لا بلونها.
    func test_5_8_backupStatesText() {
        let off = launch(["-backup", "off"])
        openSettings(off)
        let row = any(off, "settings.backup.off")
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        expectContains(row, "النسخ الاحتياطي متوقّف: iCloud غير مفعّل")
        shot(off, "84-settings-off")
        off.terminate()

        let on = launch(["-backup", "on"])
        openSettings(on)
        let ok = any(on, "settings.backup.on")
        XCTAssertTrue(ok.waitForExistence(timeout: 20))
        expectContains(ok, "يُنسخ سجلّك إلى iCloud تلقائياً")
        shot(on, "85-settings-on")
    }

    /// 8.2: الإعدادات ليلاً، والورقة على `paper` كما في §17.1.
    func test_8_2_settingsAtNight() {
        let app = launch(["-dark"])
        openSettings(app)
        XCTAssertTrue(any(app, "settings.backup.device").waitForExistence(timeout: 20))
        shot(app, "86-settings-dark")
    }
}
