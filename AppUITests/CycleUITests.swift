import XCTest

/// ش3 · المرحلة 1: الدورة وموضع التوقّف في القريب والبعيد (5.5، design/system.md §14.1–14.3، §14.7).
/// سيناريوهات المعاين في docs/reports/ش3-التصميم.md §5: 1، 2، 3، 4، 5، 7، 13.
@MainActor
final class CycleUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// محفوظ المثال، ودورة البعيد بدأت قبل 20 يوماً، والقريب قبل 3 أيام.
    private static let seed = "farReview:1-9;nearReview:10-11"

    /// تظليلات البعيد في الدورة: الأرباع 1…n قبل 5 أيام.
    private static func shaded(_ quarters: ClosedRange<Int>) -> String {
        quarters.map { "\($0):5" }.joined(separator: ",")
    }

    private func launch(readings: String, pinSeconds: Double? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed", Self.seed, "-cycle", "farReview:20,nearReview:3",
                               "-readings", readings]
            + (pinSeconds.map { ["-pin-seconds", String($0)] } ?? [])
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func wait(_ element: XCUIElement, _ format: String, _ text: String, timeout: TimeInterval = 20) -> Bool {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: format, text), object: element)
        return XCTWaiter().wait(for: [match], timeout: timeout) == .completed
    }

    private func expectValue(_ element: XCUIElement, _ text: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        if !wait(element, "value == %@", text) {
            XCTAssertEqual(element.value as? String, text, file: file, line: line)
        }
    }

    private func expectProgress(_ app: XCUIApplication, _ text: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        let element = app.staticTexts["track.farReview.progress"]
        if !wait(element, "label == %@", "تقدّم الدورة: \(text) ربعاً") {
            XCTAssertEqual(element.label, "تقدّم الدورة: \(text) ربعاً", file: file, line: line)
        }
    }

    private func quarter(_ app: XCUIApplication, _ q: Int) -> XCUIElement {
        app.buttons.matching(identifier: "quarter.farReview.\(q)").firstMatch
    }

    private func isBookmark(_ element: XCUIElement) -> Bool { element.label.contains("موضع التوقّف") }

    private func expectBookmark(_ app: XCUIApplication, _ q: Int, file: StaticString = #filePath, line: UInt = #line) {
        let element = quarter(app, q)
        if !wait(element, "label CONTAINS %@", "موضع التوقّف") {
            XCTFail("الإطار ليس على الربع \(q): \(element.label)", file: file, line: line)
        }
    }

    /// §14.1، §14.2: البعيد ح 1–9 وكل ما قبل ح 6 الربع 3 مظلّل في الدورة: مطويّة على ح 6،
    /// والإطار على الربع 3، والتقدّم «22 من 36»؛ وقارئ الشاشة يقرأ «ح 6» بموضع التوقّف (§14.7)
    /// (سيناريوا المعاين 1 و13). ثم ضغطة الموضع تنقل الإطار، والتراجع يعيده (2)، والتخطّي يبقيه (3).
    func test_14_bookmarkProgressSkipAndUndo() {
        let app = launch(readings: Self.shaded(1...22))
        let q23 = quarter(app, 23)
        XCTAssertTrue(q23.waitForExistence(timeout: 20))
        expectProgress(app, "22 من 36")
        expectBookmark(app, 23)
        XCTAssertFalse(isBookmark(quarter(app, 24)))
        XCTAssertFalse(quarter(app, 25).exists, "مطويّة على ح 6 وحده")
        XCTAssertEqual(app.descendants(matching: .any)["hizb.farReview.6"].label, "الحزب 6، فيه موضع التوقّف")
        // القريب: لا تظليل في دورته، فالإطار على أوله و«0 من 8».
        XCTAssertTrue(app.buttons["quarter.nearReview.37"].label.hasSuffix("موضع التوقّف"))
        XCTAssertEqual(app.staticTexts["track.nearReview.progress"].label, "تقدّم الدورة: 0 من 8 ربعاً")
        shot(app, "31-bookmark")

        // 2: ضغطة على ربع الإطار: يُظلَّل، والتقدّم 23، والإطار على الربع 4.
        q23.tap()
        expectValue(q23, "تلوته اليوم")
        expectProgress(app, "23 من 36")
        expectBookmark(app, 24)
        XCTAssertFalse(isBookmark(q23))
        shot(app, "32-bookmark-next")
        // والتراجع يعيد الإطار والعدد.
        q23.tap()
        expectValue(q23, "لم يُتلَ")
        expectProgress(app, "22 من 36")
        expectBookmark(app, 23)

        // 3: التخطّي: ظُلّل الربع 4 وبقي 3، فالإطار باقٍ على 3 والتقدّم 23.
        let q24 = quarter(app, 24)
        q24.tap()
        expectValue(q24, "تلوته اليوم")
        expectProgress(app, "23 من 36")
        expectBookmark(app, 23)
        XCTAssertFalse(isBookmark(q24))
        shot(app, "33-skip")
    }

    /// §14.3 (ذ20): إتمام ح 6 يبقي الصفّ على ح 6 بلا إطار ولا علامة مدّة المهلة، ثم ينتقل إلى ح 7
    /// والإطار على الربع 1 (سيناريو المعاين 4). المهلة 0.8 ث، وتطول في الاختبار (6 ث) ليُقرأ الصفّ فيها.
    func test_14_3_rowStaysThenMoves() {
        let app = launch(readings: Self.shaded(1...23), pinSeconds: 6)
        let q24 = quarter(app, 24)
        XCTAssertTrue(q24.waitForExistence(timeout: 20))
        expectBookmark(app, 24)
        q24.tap()
        expectValue(q24, "تلوته اليوم")
        XCTAssertTrue(quarter(app, 21).exists, "الصفّ باقٍ على ح 6 في المهلة")
        XCTAssertFalse(quarter(app, 25).exists)
        XCTAssertFalse(isBookmark(q24), "لا إطار في المهلة")
        XCTAssertEqual(app.descendants(matching: .any)["hizb.farReview.6"].label, "الحزب 6")
        expectProgress(app, "24 من 36")

        let q25 = quarter(app, 25)
        XCTAssertTrue(q25.waitForExistence(timeout: 20), "انتقل الصفّ إلى ح 7")
        expectBookmark(app, 25)
        XCTAssertFalse(quarter(app, 21).exists)
        XCTAssertEqual(app.descendants(matching: .any)["hizb.farReview.7"].label, "الحزب 7، فيه موضع التوقّف")
        shot(app, "34-row-moved")
    }

    /// §14.3، م38: التراجع في المهلة يلغي الانتقال، فيبقى الصفّ على ح 6 والإطار على الربع 4
    /// (سيناريو المعاين 5).
    func test_14_3_undoWithinWindowKeepsRow() {
        let app = launch(readings: Self.shaded(1...23), pinSeconds: 8)
        let q24 = quarter(app, 24)
        XCTAssertTrue(q24.waitForExistence(timeout: 20))
        q24.tap()
        expectValue(q24, "تلوته اليوم")
        q24.tap()
        expectValue(q24, "لم يُتلَ")
        expectBookmark(app, 24)
        // بعد انقضاء المهلة: لم ينتقل.
        XCTAssertFalse(quarter(app, 25).waitForExistence(timeout: 10), "أُلغي الانتقال")
        XCTAssertTrue(quarter(app, 21).exists)
        expectBookmark(app, 24)
        expectProgress(app, "23 من 36")
    }

    /// §14.2: الربع المشترك (ح 5 الربع 4) موضعاً للتوقّف: الإطار في الموضعين، وضغطة واحدة تزيد التقدّم 1
    /// (سيناريو المعاين 7).
    func test_14_2_sharedBookmarkInBothPlaces() {
        let app = launch(readings: Self.shaded(1...19))
        let pull = app.buttons["track.farReview.pull"]
        XCTAssertTrue(pull.waitForExistence(timeout: 20))
        expectProgress(app, "19 من 36")
        pull.tap()
        XCTAssertTrue(app.otherElements["track.farReview.archive"].waitForExistence(timeout: 20))
        let places = app.buttons.matching(identifier: "quarter.farReview.20")
        XCTAssertEqual(places.count, 2)
        XCTAssertTrue(isBookmark(places.element(boundBy: 0)))
        XCTAssertTrue(isBookmark(places.element(boundBy: 1)))
        let section = app.otherElements["section.farReview.3"]
        for _ in 0..<3 where !section.isHittable { app.swipeUp() }
        shot(app, "35-shared-bookmark")
        // الضغطة من موضع آل عمران الظاهر بعد التمرير، فيُظلَّل في الموضعين معاً.
        places.element(boundBy: 1).tap()
        expectValue(places.element(boundBy: 0), "تلوته اليوم")
        expectProgress(app, "20 من 36")
        expectBookmark(app, 21)
        XCTAssertFalse(isBookmark(places.element(boundBy: 0)))
    }
}
