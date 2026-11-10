import XCTest

/// ش2 · المرحلتان 1 و2: التظليل بالتاريخ وعلامة «اليوم»، والتراجع (5.3، §13.1، §13.2) ولقطاتهما.
/// سيناريوهات المعاين في docs/reports/ش2-التصميم.md §5: 1 (التظليل)، 2 (التراجع)، 3 (منتصف الليل)، 5 (المشترك).
@MainActor
final class ShadingUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(seed: String, readings: String? = nil, now: String? = nil, testClock: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed", seed] + (testClock ? ["-test-clock"] : [])
            + (readings.map { ["-readings", $0] } ?? [])
            + (now.map { ["-now", $0] } ?? [])
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// ينتظر أن تصير قيمة العنصر كما يُتوقّع؛ فما تقرؤه أداة الاختبار يتأخّر على محاكي CI (#43).
    private func expectValue(_ element: XCUIElement, _ text: String, timeout: TimeInterval = 20,
                             file: StaticString = #filePath, line: UInt = #line) {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", text), object: element)
        if XCTWaiter().wait(for: [match], timeout: timeout) != .completed {
            XCTAssertEqual(element.value as? String, text, file: file, line: line)
        }
    }

    private func open(_ track: String, _ app: XCUIApplication) {
        let pull = app.buttons["track.\(track).pull"]
        XCTAssertTrue(pull.waitForExistence(timeout: 20))
        if !pull.isHittable { app.swipeUp() }
        pull.tap()
        XCTAssertTrue(app.otherElements["track.\(track).archive"].waitForExistence(timeout: 20))
    }

    /// 5.3: ضغطة على ربع لم يُتلَ تظلّله وعليه علامة «اليوم»، والضغطة الثانية في اليوم نفسه
    /// لا تظلّله مرة أخرى. ولا تقدّم دورة ولا علامة موضع توقّف في ش2 (ذ10، ذ16) (سيناريو المعاين 1).
    func test_5_3_tapShadesWithTodayMark() {
        let app = launch(seed: "farReview:1-9;nearReview:10-11", readings: "37:0,38:0")
        let q2 = app.buttons["quarter.farReview.2"]
        XCTAssertTrue(q2.waitForExistence(timeout: 20))
        XCTAssertEqual(q2.value as? String, "لم يُتلَ")
        expectValue(app.buttons["quarter.nearReview.37"], "تلوته اليوم")
        XCTAssertEqual(app.buttons["quarter.nearReview.39"].value as? String, "لم يُتلَ")

        q2.tap()
        expectValue(q2, "تلوته اليوم")
        XCTAssertEqual(app.buttons["quarter.farReview.1"].value as? String, "لم يُتلَ", "الضغطة على ربعها وحده")
        XCTAssertFalse(app.staticTexts["track.farReview.progress"].exists, "تقدّم الدورة مخفيّ (ذ10)")
        XCTAssertFalse(q2.label.contains("موضع التوقّف"))
        XCTAssertFalse(app.buttons["quarter.farReview.1"].label.contains("موضع التوقّف"), "لا علامة موضع توقّف (ذ16)")
        shot(app, "22-shaded")

    }

    /// 5.3، §13.2: الضغطة الثانية على ربع ظُلّل اليوم تراجع: يعود فارغاً بلا علامة، ولا يمسّ غيره،
    /// والضغطة بعدها تظلّله من جديد (سيناريو المعاين 2).
    func test_5_3_secondTapUndoes() {
        let app = launch(seed: "farReview:1-9;nearReview:10-11", readings: "37:0")
        let q2 = app.buttons["quarter.farReview.2"]
        XCTAssertTrue(q2.waitForExistence(timeout: 20))
        q2.tap()
        expectValue(q2, "تلوته اليوم")
        q2.tap()
        expectValue(q2, "لم يُتلَ")
        XCTAssertEqual(app.buttons["quarter.nearReview.37"].value as? String, "تلوته اليوم", "التراجع لا يمسّ غيره")
        shot(app, "25-undone")
        q2.tap()
        expectValue(q2, "تلوته اليوم")
    }

    /// 7.1.1، 5.3: الربع المشترك (ح 5 الربع 4) يُظلَّل في قسم البقرة فيظهر مظلّلاً في آل عمران كذلك
    /// (سيناريو المعاين 5).
    func test_5_3_sharedQuarterShadedInBothPlaces() {
        let app = launch(seed: "farReview:5")
        open("farReview", app)
        let places = app.buttons.matching(identifier: "quarter.farReview.20")
        XCTAssertEqual(places.count, 2)
        places.element(boundBy: 0).tap()
        expectValue(places.element(boundBy: 0), "تلوته اليوم")
        expectValue(places.element(boundBy: 1), "تلوته اليوم")
        // والتراجع من الموضع الآخر يفرغهما معاً.
        places.element(boundBy: 1).tap()
        expectValue(places.element(boundBy: 0), "لم يُتلَ")
        expectValue(places.element(boundBy: 1), "لم يُتلَ")
        places.element(boundBy: 0).tap()
        expectValue(places.element(boundBy: 1), "تلوته اليوم")
        let imran = app.otherElements["section.farReview.3"]
        for _ in 0..<3 where !imran.isHittable { app.swipeUp() }
        shot(app, "23-shaded-shared")
    }

    /// 5.3، القرار 2: اليوم يبدأ عند منتصف الليل والتطبيق مفتوح: تختفي علامة «اليوم» دون فتح جديد،
    /// وتصير الضغطة تظليلاً جديداً (سيناريو المعاين 3).
    func test_5_3_todayMarkClearsAtMidnight() {
        let app = launch(seed: "farReview:1", readings: "1:0@21:00", now: "2026-11-06T22:00:00", testClock: true)
        let q1 = app.buttons["quarter.farReview.1"]
        XCTAssertTrue(q1.waitForExistence(timeout: 20))
        expectValue(q1, "تلوته اليوم")
        // تقفز ساعة الاختبار بعد منتصف الليل، فتتحدّث الشاشة وحدها دون فتح جديد.
        app.buttons["test.midnight"].tap()
        expectValue(q1, "لم يُتلَ")
        shot(app, "24-after-midnight")
        q1.tap()
        expectValue(q1, "تلوته اليوم")
    }
}
