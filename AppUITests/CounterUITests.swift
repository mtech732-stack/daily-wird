import XCTest

/// ش5 · المرحلة 1: الدائرة والعدد، والشريط مع الأرشيف المفتوح (5.7، design/system.md §16.1–16.2، §16.5–16.7).
/// سيناريوهات المعاين في docs/reports/ش5-التصميم.md §5: 1، 2، 8، 9، 10، 11.
@MainActor
final class CounterUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// محفوظ كمحفوظ المالك في اللقطات المرجعية: البعيد والقريب والجديد، وسطور «آخر إدخال».
    private static let owner = "farReview:1-9;nearReview:10-11;new:12"

    private func launch(seed: String = CounterUITests.owner, counter: Int? = nil, readings: String? = "37:0",
                        pages: String? = "112-116:3") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed", seed]
            + (counter.map { ["-counter", String($0)] } ?? [])
            + (readings.map { ["-readings", $0] } ?? [])
            + (pages.map { ["-pages", $0] } ?? [])
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func circle(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "counter.circle").firstMatch
    }

    /// ما تقرؤه أداة الاختبار يتأخّر على محاكي CI (#43)، فيُنتظر.
    private func expectCount(_ app: XCUIApplication, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = circle(app)
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", text), object: element)
        if XCTWaiter().wait(for: [match], timeout: 20) != .completed {
            XCTAssertEqual(element.exists ? element.value as? String : "(غير موجود)", text, file: file, line: line)
        }
    }

    /// سيناريو المعاين 1 و§16.1: العدّاد تحت البطاقات، و«تصفير» فوقه والإشارة تحته، كله بلا تمرير.
    /// والعدد أول تثبيت «0»، و«تصفير» ظاهر هادئ (ذ43).
    func test_5_7_foldedCounterUnderCards() {
        let app = launch()
        let c = circle(app)
        XCTAssertTrue(c.waitForExistence(timeout: 20))
        expectCount(app, "0")
        XCTAssertEqual(c.label, "العدّاد")
        let reset = app.descendants(matching: .any)["counter.reset"]
        XCTAssertTrue(reset.exists, "«تصفير» ظاهر والعدد صفر")
        let hint = app.descendants(matching: .any)["keys.hint"]
        XCTAssertTrue(hint.exists, "الإشارة تحت العدّاد")
        let newCard = app.descendants(matching: .any)["track.new.card"]
        let screen = app.windows.firstMatch.frame
        // الترتيب: البطاقات ثم «تصفير» ثم الدائرة ثم الإشارة، وكله في الشاشة (§16.1، §16.6).
        XCTAssertLessThanOrEqual(newCard.frame.maxY, reset.frame.minY)
        XCTAssertLessThan(reset.frame.maxY, c.frame.minY)
        XCTAssertLessThanOrEqual(c.frame.maxY, hint.frame.minY)
        XCTAssertLessThanOrEqual(hint.frame.maxY, screen.maxY)
        // القطر ما بقي بين 76 و136، والدائرة دائرة.
        XCTAssertGreaterThanOrEqual(c.frame.width, 76)
        XCTAssertLessThanOrEqual(c.frame.width, 136)
        XCTAssertEqual(c.frame.width, c.frame.height, accuracy: 1)
        shot(app, "65-counter-zero")
    }

    /// سيناريو المعاين 2 و§16.2: خمس ضغطات متتابعة ← «5»، وضغطة على حافّة الدائرة لا على الرقم ← «6».
    func test_5_7_tapAnywhereAddsOne() {
        let app = launch()
        let c = circle(app)
        XCTAssertTrue(c.waitForExistence(timeout: 20))
        for _ in 0..<5 { c.tap() }
        expectCount(app, "5")
        // قرب الحافّة العليا داخل الدائرة: على بعد 0.42 من القطر من مركزها.
        c.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        expectCount(app, "6")
        // وقرب الحافّة اليمنى.
        c.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        expectCount(app, "7")
        shot(app, "66-counter-fold")
    }

    /// سيناريو المعاين 8 و§16.2: السحب الذي يبدأ على الدائرة تمرير لا ضغطة، فتظهر المفاتيح والعدد لم يزد.
    func test_5_7_dragIsNotATap() {
        let app = launch(counter: 33)
        let c = circle(app)
        XCTAssertTrue(c.waitForExistence(timeout: 20))
        expectCount(app, "33")
        let keys = app.descendants(matching: .any)["keys"]
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(keys.frame.minY, screen.maxY - 40, "المفاتيح لا تُرى عند الفتح")
        c.swipeUp()
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "frame.minY < %f", screen.maxY - 200), object: keys)
        XCTAssertEqual(XCTWaiter().wait(for: [shown], timeout: 20), .completed, "ظهرت المفاتيح بالسحب")
        expectCount(app, "33")
        shot(app, "67-counter-keys")
    }

    /// سيناريو المعاين 9 و§16.5: مع الأرشيف المفتوح العدّاد شريط أسفل الشاشة بالعدد نفسه، والضغطة فيه +1،
    /// وبالطيّ تعود الدائرة الكبيرة بالعدد نفسه.
    func test_5_7_barWithOpenArchive() {
        let app = launch(counter: 33)
        XCTAssertTrue(circle(app).waitForExistence(timeout: 20))
        let pull = app.buttons["track.farReview.pull"]
        XCTAssertTrue(pull.waitForExistence(timeout: 20))
        pull.tap()
        XCTAssertTrue(app.otherElements["track.farReview.archive"].waitForExistence(timeout: 20))
        let bar = app.descendants(matching: .any)["counter.bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 20), "العدّاد شريط مع الأرشيف المفتوح")
        let screen = app.windows.firstMatch.frame
        XCTAssertEqual(bar.frame.maxY, screen.maxY, accuracy: 1, "ملتصق بأسفل الشاشة")
        XCTAssertEqual(bar.frame.height, 88, accuracy: 1)
        expectCount(app, "33")
        XCTAssertEqual(circle(app).frame.width, 64, accuracy: 1)
        XCTAssertTrue(app.descendants(matching: .any)["counter.reset"].exists, "«تصفير» بجانب الدائرة")
        circle(app).tap()
        expectCount(app, "34")
        // التمرير لا يحرّك الشريط.
        app.swipeUp()
        XCTAssertEqual(bar.frame.maxY, screen.maxY, accuracy: 1)
        shot(app, "68-counter-bar")

        let fold = app.buttons["track.farReview.pull.sticky"].exists
            ? app.buttons["track.farReview.pull.sticky"] : app.buttons["track.farReview.pull"]
        fold.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: bar)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 20), .completed, "بالطيّ يعود العدّاد كبيراً")
        expectCount(app, "34")
        XCTAssertGreaterThanOrEqual(circle(app).frame.width, 76)
    }

    /// سيناريو المعاين 10 و§16.5: الإشعار مع الشريط فوقه لا يغطّيه، والعدد ظاهر.
    /// والإشعار هنا من إضافة الجزء 1 إلى البعيد من «⋯» وأرشيفه مفتوح.
    func test_5_7_toastAboveBar() {
        let app = launch(seed: "farReview:3-9;nearReview:10-11;new:12", counter: 33)
        let pull = app.buttons["track.farReview.pull"]
        XCTAssertTrue(pull.waitForExistence(timeout: 20))
        pull.tap()
        XCTAssertTrue(app.otherElements["track.farReview.archive"].waitForExistence(timeout: 20))
        let bar = app.descendants(matching: .any)["counter.bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 20))
        app.buttons["track.farReview.more"].tap()
        let item = app.buttons["إضافة"]
        XCTAssertTrue(item.waitForExistence(timeout: 20))
        item.tap()
        let juz = app.buttons["add.juz.1"]
        XCTAssertTrue(juz.waitForExistence(timeout: 20))
        juz.tap()
        let go = app.buttons["add.go"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true AND isHittable == true"), object: go)
        if XCTWaiter().wait(for: [enabled], timeout: 20) != .completed { juz.tap() }
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 20), .completed, "لم يتفعّل «أضف»")
        go.tap()
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 20))
        XCTAssertLessThanOrEqual(toast.frame.maxY, bar.frame.minY, "الإشعار فوق الشريط لا يغطّيه")
        expectCount(app, "33")
        shot(app, "69-counter-bar-toast")
    }

    /// سيناريو المعاين 11 وذ39: 9999 ثم ضغطة ← «10000» بلا فاصل آلاف، داخل الدائرة.
    func test_5_7_fiveDigitsInsideCircle() {
        let app = launch(counter: 9999)
        let c = circle(app)
        XCTAssertTrue(c.waitForExistence(timeout: 20))
        expectCount(app, "9999")
        shot(app, "70-counter-d4")
        c.tap()
        expectCount(app, "10000")
        shot(app, "71-counter-d5")
    }

    /// سيناريو المعاين 13: الدائرة تُقرأ «العدّاد» وقيمتها العدد، والتمرير للأعلى يزيدها.
    func test_5_7_voiceOverIncrement() {
        let app = launch(counter: 6)
        let c = circle(app)
        XCTAssertTrue(c.waitForExistence(timeout: 20))
        XCTAssertEqual(c.label, "العدّاد")
        expectCount(app, "6")
        // إجراء الزيادة لقارئ الشاشة (accessibilityAdjustableAction).
        c.increment()
        expectCount(app, "7")
    }
}
