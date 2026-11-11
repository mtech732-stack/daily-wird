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

    private func wait(_ element: XCUIElement, _ format: String, _ args: [Any] = [], timeout: TimeInterval = 20) -> Bool {
        let e = XCTNSPredicateExpectation(predicate: NSPredicate(format: format, argumentArray: args), object: element)
        return XCTWaiter().wait(for: [e], timeout: timeout) == .completed
    }

    private func expectLabel(_ element: XCUIElement, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        if !wait(element, "label == %@", [text]) {
            XCTAssertEqual(element.exists ? element.label : "(غير ظاهر)", text, file: file, line: line)
        }
    }

    private func tapSelecting(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 20), "لم يظهر \(element)", file: file, line: line)
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
        XCTAssertTrue(button.waitForExistence(timeout: 20), "لم يظهر «\(item)» في «⋯»")
        button.tap()
    }

    /// يضغط «ح [رقم]» ضغطة مطوّلة حتى تظهر قائمة الحزب المخصّصة (§12.5، م22، م32)، ويعيد بندها
    /// (`hizbmenu.move.[المسار]` أو `hizbmenu.remove`). ينتظر أن يصير «ح» قابلاً للضغط أولاً، ويعيد الضغط
    /// مرة إن لم تظهر القائمة، فإن لم تظهر فشل بطباعة ما على الشاشة بأسطر «تشخيص:».
    @discardableResult
    private func pressHizb(_ app: XCUIApplication, _ track: String, _ hizb: Int, item: String,
                           file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let label = app.descendants(matching: .any)["hizb.\(track).\(hizb)"]
        XCTAssertTrue(label.waitForExistence(timeout: 20), "لم يظهر ح \(hizb)", file: file, line: line)
        XCTAssertTrue(wait(label, "isHittable == true"), "لا يُضغط ح \(hizb)", file: file, line: line)
        let entry = app.buttons[item]
        label.press(forDuration: 1.0)
        if entry.waitForExistence(timeout: 20) { return entry }
        print("تشخيص: لم تظهر قائمة ح \(hizb) بعد الضغط المطوّل، يُعاد مرة")
        if label.isHittable {
            label.press(forDuration: 1.0)
            if entry.waitForExistence(timeout: 20) { return entry }
        }
        // سجلّ CI لا يُظهر إلا الأسطر التي تبدأ بـ«تشخيص:»، فيُطبع كل سطر بها.
        for row in app.debugDescription.split(separator: "\n") where row.contains("label:") {
            print("تشخيص: \(row)")
        }
        XCTFail("لم يظهر «\(item)» في قائمة ح \(hizb)", file: file, line: line)
        return entry
    }

    /// §12.5، 5.2: الضغط المطوّل على «ح 10» في القريب يعرض قائمته، و«نقل إلى مراجعة البعيد»
    /// ينقله فوراً بلا سؤال (ذ6)، ويؤكّده الإشعار.
    func test_12_5_hizbMenuMovesWithoutAsking() {
        let app = launch()
        let move = pressHizb(app, "nearReview", 10, item: "hizbmenu.move.farReview")
        // الرأس بلون muted (م32)، والبنود بنصوصها بلا علامات خفيّة.
        expectLabel(app.staticTexts["hizbmenu.header"], "ح 10 · النساء · الجزء 5")
        expectLabel(move, "نقل إلى مراجعة البعيد")
        expectLabel(app.buttons["hizbmenu.remove"], "إزالة من المسار")
        shot(app, "16-hizb-menu")
        move.tap()

        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 20))
        expectLabel(app.staticTexts["toast"], "نُقل ح 10 إلى مراجعة البعيد")
        expectLabel(app.otherElements["track.farReview.quarterCount"], "40")
        expectLabel(app.otherElements["track.nearReview.quarterCount"], "4")
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
        XCTAssertTrue(app.otherElements["track.nearReview.empty"].waitForExistence(timeout: 20))
        expectLabel(app.otherElements["track.farReview.quarterCount"], "36")
        shot(app, "20-removed")
    }

    /// §12.5: «نقل» من «⋯» تفتح ورقة الإدارة بسطر الوجهة، و«انقل الحزب 9 إلى مراجعة القريب» ينقله.
    func test_12_5_moveSheetFromTrackMenu() {
        let app = launch()
        menu(app, "farReview", "نقل")
        expectLabel(app.staticTexts["manage.title"], "نقل من مراجعة البعيد")
        XCTAssertTrue(app.otherElements["manage.target"].waitForExistence(timeout: 20)
                      || app.staticTexts["manage.target"].exists)
        tapSelecting(app.buttons["manage.hizb.9"])
        expectLabel(app.buttons["manage.go"], "انقل الحزب 9 إلى مراجعة القريب")
        shot(app, "21-move-sheet")
        tapEnabled(app.buttons["manage.go"])

        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 20))
        expectLabel(app.staticTexts["toast"], "نُقل ح 9 إلى مراجعة القريب")
        expectLabel(app.otherElements["track.nearReview.quarterCount"], "12")
        expectLabel(app.otherElements["track.farReview.quarterCount"], "32")
    }

    /// 5.1: الإزالة من قائمة الحزب تسأل أولاً، و«إلغاء» لا يزيل شيئاً.
    func test_5_1_removeFromHizbMenuCanBeCancelled() {
        let app = launch()
        pressHizb(app, "farReview", 1, item: "hizbmenu.remove").tap()
        let question = app.staticTexts["remove.question"]
        XCTAssertTrue(question.waitForExistence(timeout: 20))
        expectLabel(question, "أتزيل الحزب 1 من مراجعة البعيد؟")
        app.buttons["remove.cancel"].tap()
        XCTAssertTrue(wait(question, "exists == false"))
        expectLabel(app.otherElements["track.farReview.quarterCount"], "36")
    }

    /// §12.5: الضغط خارج قائمة الحزب يغلقها بلا نقل ولا إزالة.
    func test_12_5_hizbMenuClosesOnOutsideTap() {
        let app = launch()
        let move = pressHizb(app, "farReview", 1, item: "hizbmenu.move.nearReview")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)).tap()
        XCTAssertTrue(wait(move, "exists == false"), "لم تُغلق القائمة")
        expectLabel(app.otherElements["track.farReview.quarterCount"], "36")
        expectLabel(app.otherElements["track.nearReview.quarterCount"], "8")
        XCTAssertFalse(app.staticTexts["toast"].exists, "لا فعل بالضغط خارجها")
    }
}
