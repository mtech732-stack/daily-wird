import XCTest

/// ش1 · المرحلة 5: النقل والإزالة مع حفظ السجلّ (5.1، 5.2، §12.5) ولقطاتها.
/// ما تقرؤه أداة الاختبار يتأخّر 2 إلى 4 ث عن التطبيق على محاكي CI (#43)،
/// فلا يُقرأ نصّ أو سمة بعد ضغطة إلا بانتظار.
@MainActor
final class ManageUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(seed: String = "farReview:1-9;nearReview:10-11") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed", seed]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func wait(_ element: XCUIElement, _ format: String, _ args: [Any] = [], timeout: TimeInterval = 15) -> Bool {
        let e = XCTNSPredicateExpectation(predicate: NSPredicate(format: format, argumentArray: args), object: element)
        return XCTWaiter().wait(for: [e], timeout: timeout) == .completed
    }

    private func expectLabel(_ element: XCUIElement, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        if !wait(element, "label == %@", [text]) {
            XCTAssertEqual(element.exists ? element.label : "(غير ظاهر)", text, file: file, line: line)
        }
    }

    private func tapSelecting(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 15), "لم يظهر \(element)", file: file, line: line)
        XCTAssertTrue(wait(element, "isHittable == true"), "لا يُضغط \(element)", file: file, line: line)
        element.tap()
        XCTAssertTrue(wait(element, "isSelected == true", timeout: 20), "لم يُختر \(element)", file: file, line: line)
    }

    private func tapEnabled(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(wait(element, "isEnabled == true AND isHittable == true"), "لم يتفعّل \(element)", file: file, line: line)
        element.tap()
    }

    /// يفتح «⋯» المسار ويختار منها بنداً.
    private func menu(_ app: XCUIApplication, _ track: String, _ item: String) {
        XCTAssertTrue(app.otherElements["track.\(track).folded"].waitForExistence(timeout: 20))
        app.buttons["track.\(track).more"].tap()
        let button = app.buttons[item]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "لم يظهر «\(item)» في «⋯»")
        button.tap()
    }

    /// يضغط «ح [رقم]» ضغطة مطوّلة فتظهر قائمة الحزب (§12.5، م22).
    private func pressHizb(_ app: XCUIApplication, _ track: String, _ hizb: Int) {
        let label = app.descendants(matching: .any)["hizb.\(track).\(hizb)"]
        XCTAssertTrue(label.waitForExistence(timeout: 20), "لم يظهر ح \(hizb)")
        label.press(forDuration: 0.8)
    }

    /// §12.5، 5.2: الضغط المطوّل على «ح 10» في القريب يعرض قائمته، و«نقل إلى مراجعة البعيد»
    /// ينقله فوراً بلا سؤال (ذ6)، ويؤكّده الإشعار.
    func test_12_5_hizbMenuMovesWithoutAsking() {
        let app = launch()
        pressHizb(app, "nearReview", 10)
        let move = app.buttons["نقل إلى مراجعة البعيد"]
        XCTAssertTrue(move.waitForExistence(timeout: 10), "لم تظهر قائمة الحزب")
        XCTAssertTrue(app.buttons["إزالة من المسار"].exists)
        shot(app, "16-hizb-menu")
        move.tap()

        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 20))
        expectLabel(app.staticTexts["toast"], "نُقل ح 10 إلى مراجعة البعيد")
        expectLabel(app.staticTexts["track.farReview.progress"], "0 من 40")
        expectLabel(app.staticTexts["track.nearReview.progress"], "0 من 4")
        XCTAssertFalse(app.staticTexts["remove.question"].exists, "النقل بلا سؤال")
        shot(app, "17-moved")
    }

    /// 5.1، §12.5: «إزالة» من «⋯» تفتح ورقة الإدارة بأحزاب المسار وحدها، ثم تأكيد صريح،
    /// ثم الإشعار «أُزيل حزبان · سجلّهما محفوظ»، والمسار الفارغ يعود ببطاقته الفارغة.
    func test_5_1_removeFromSheetAsksThenEmptiesTrack() {
        let app = launch()
        menu(app, "nearReview", "إزالة")
        expectLabel(app.staticTexts["manage.title"], "إزالة من مراجعة القريب")
        // لا يظهر في الورقة إلا ما في القريب: ح 9 في البعيد فراغ في مكانه.
        XCTAssertFalse(app.buttons["manage.hizb.9"].exists)
        tapSelecting(app.buttons["manage.hizb.10"])
        tapSelecting(app.buttons["manage.hizb.11"])
        expectLabel(app.buttons["manage.go"], "أزل حزبين")
        shot(app, "18-remove-sheet")
        tapEnabled(app.buttons["manage.go"])

        let question = app.staticTexts["remove.question"]
        XCTAssertTrue(question.waitForExistence(timeout: 20), "لا إزالة بلا تأكيد صريح (5.1)")
        expectLabel(question, "أتزيل الحزبين 10 و11 من مراجعة القريب؟")
        expectLabel(app.buttons["remove.confirm"], "أزلهما")
        shot(app, "19-remove-confirm")
        app.buttons["remove.confirm"].tap()

        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 20))
        expectLabel(app.staticTexts["toast"], "أُزيل حزبان · سجلّهما محفوظ")
        XCTAssertTrue(app.otherElements["track.nearReview.empty"].waitForExistence(timeout: 15))
        expectLabel(app.staticTexts["track.farReview.progress"], "0 من 36")
        shot(app, "20-removed")
    }

    /// §12.5: «نقل» من «⋯» تفتح ورقة الإدارة بسطر الوجهة، و«انقل الحزب 9 إلى مراجعة القريب» ينقله.
    func test_12_5_moveSheetFromTrackMenu() {
        let app = launch()
        menu(app, "farReview", "نقل")
        expectLabel(app.staticTexts["manage.title"], "نقل من مراجعة البعيد")
        XCTAssertTrue(app.otherElements["manage.target"].waitForExistence(timeout: 10)
                      || app.staticTexts["manage.target"].exists)
        tapSelecting(app.buttons["manage.hizb.9"])
        expectLabel(app.buttons["manage.go"], "انقل الحزب 9 إلى مراجعة القريب")
        shot(app, "21-move-sheet")
        tapEnabled(app.buttons["manage.go"])

        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 20))
        expectLabel(app.staticTexts["toast"], "نُقل ح 9 إلى مراجعة القريب")
        expectLabel(app.staticTexts["track.nearReview.progress"], "0 من 12")
        expectLabel(app.staticTexts["track.farReview.progress"], "0 من 32")
    }

    /// 5.1: الإزالة من قائمة الحزب تسأل أولاً، و«إلغاء» لا يزيل شيئاً.
    func test_5_1_removeFromHizbMenuCanBeCancelled() {
        let app = launch()
        pressHizb(app, "farReview", 1)
        let remove = app.buttons["إزالة من المسار"]
        XCTAssertTrue(remove.waitForExistence(timeout: 10), "لم تظهر قائمة الحزب")
        remove.tap()
        let question = app.staticTexts["remove.question"]
        XCTAssertTrue(question.waitForExistence(timeout: 20))
        expectLabel(question, "أتزيل الحزب 1 من مراجعة البعيد؟")
        app.buttons["remove.cancel"].tap()
        XCTAssertTrue(wait(question, "exists == false"))
        expectLabel(app.staticTexts["track.farReview.progress"], "0 من 36")
    }
}
