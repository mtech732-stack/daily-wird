import XCTest

/// ش6 · المرحلة 2: حجم الخط (8.3، design/system.md §17.4، م46 · م54).
/// يُفرض حجم الخط بوسيط التشغيل `-UIPreferredContentSizeCategoryName`، فلا يُمسّ إعداد المحاكي.
/// ولا محاكي 375 في الفحص، فيُرى على 390 (والكبير 440 في الفحص الكامل).
@MainActor
final class TypeSizeUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// القريب أُكملت دورته اليوم في 19 يوماً، والجديد «5 من 10»، وسطور «آخر إدخال» كلها.
    private func launch(_ size: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed", "farReview:1-9;nearReview:10;new:12",
                               "-cycle", "farReview:20,nearReview:18",
                               "-readings", "1:0,37:5,38:5,39:5,40:0", "-pages", "112-116:1",
                               "-UIPreferredContentSizeCategoryName", size]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func title(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    /// يتحقّق أن `below` تحت `above` لا بجانبه.
    private func expectBelow(_ below: XCUIElement, _ above: XCUIElement, _ what: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(below.waitForExistence(timeout: 20), "لم يظهر \(what)", file: file, line: line)
        XCTAssertTrue(above.exists, "لم يظهر ما فوق \(what)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(below.frame.minY, above.frame.maxY - 2,
                                    "\(what) تحت ما فوقه: \(below.frame) و\(above.frame)", file: file, line: line)
    }

    /// م46 و§17.4 على AX5: التاريخ تحت «الورد اليومي»، وفي كل بطاقة سطر التقدّم أو الاكتمال تحت العنوان،
    /// والعنوان يلتفّ ولا يُقطع، والاكتمال بصيغته الكاملة. والمربّعات ثابتة 44.
    func test_8_3_largestTypeHeaders() {
        let app = launch("UICTContentSizeCategoryAccessibilityXXXL")
        let homeTitle = app.staticTexts["home.title"]
        XCTAssertTrue(homeTitle.waitForExistence(timeout: 20))
        expectBelow(app.staticTexts["home.date"], homeTitle, "التاريخ")

        let farTitle = title(app, "مراجعة البعيد")
        XCTAssertTrue(farTitle.waitForExistence(timeout: 20))
        // العنوان لا يُقطع بنقاط.
        XCTAssertEqual(farTitle.label, "مراجعة البعيد")
        let more = app.buttons["track.farReview.more"]
        XCTAssertTrue(more.exists)
        XCTAssertLessThanOrEqual(more.frame.minY, farTitle.frame.minY + 4, "«⋯» في أعلى الرأس")
        shot(app, "78-ax5-top")

        let done = app.descendants(matching: .any)["track.nearReview.completed"]
        XCTAssertTrue(done.waitForExistence(timeout: 20))
        XCTAssertEqual(done.label, "اكتملت دورة مراجعة القريب في 19 يوماً")
        expectBelow(done, title(app, "مراجعة القريب"), "سطر الاكتمال")

        let progress = app.staticTexts["track.new.progress"]
        expectBelow(progress, title(app, "المحفوظ الجديد"), "سطر التقدّم في الجديد")

        let tile = app.buttons["quarter.farReview.1"]
        XCTAssertTrue(tile.exists)
        XCTAssertEqual(tile.frame.width, 44, accuracy: 1, "المربّعات ثابتة مع أكبر الخطوط")

        // ما تحت: سطر الاكتمال وسطور «آخر إدخال» بفاصلها كسرَ سطر (م54).
        app.swipeUp()
        _ = app.staticTexts["home.title"].waitForExistence(timeout: 2)
        shot(app, "79-ax5-near")
        app.swipeUp()
        shot(app, "80-ax5-new")
    }

    /// §17.4 على AX1: الرأس سطران، وسطر الاكتمال كاملاً تحت العنوان.
    func test_8_3_ax1Headers() {
        let app = launch("UICTContentSizeCategoryAccessibilityM")
        let homeTitle = app.staticTexts["home.title"]
        XCTAssertTrue(homeTitle.waitForExistence(timeout: 20))
        expectBelow(app.staticTexts["home.date"], homeTitle, "التاريخ")
        let done = app.descendants(matching: .any)["track.nearReview.completed"]
        expectBelow(done, title(app, "مراجعة القريب"), "سطر الاكتمال")
        shot(app, "81-ax1")
    }

    /// والحجم الافتراضي كما كان: التاريخ بجانب «الورد اليومي»، والتقدّم بجانب العنوان.
    func test_8_3_defaultSizeKeepsOneLine() {
        let app = launch("UICTContentSizeCategoryL")
        let homeTitle = app.staticTexts["home.title"]
        XCTAssertTrue(homeTitle.waitForExistence(timeout: 20))
        let date = app.staticTexts["home.date"]
        XCTAssertTrue(date.exists)
        XCTAssertLessThan(date.frame.minY, homeTitle.frame.maxY, "التاريخ بجانب العنوان")
        let progress = app.staticTexts["track.new.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 20))
        let newTitle = title(app, "المحفوظ الجديد")
        XCTAssertLessThan(progress.frame.minY, newTitle.frame.maxY, "التقدّم بجانب العنوان")
    }
}
