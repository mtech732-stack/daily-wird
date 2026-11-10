import XCTest

/// ش1 · المرحلة 2: إضافة جزء أو حزب (5.1، 7.2) ولقطاتها.
@MainActor
final class AddUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(seed: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + (seed.map { ["-seed", $0] } ?? [])
        app.launch()
        return app
    }

    /// يضغط دائرة جزء أو خانة حزب، ويتحقّق من الاختيار في التطبيق نفسه وفي سمة الإتاحة.
    /// يقرأ ما يعرضه التطبيق في وضع الاختبار (`add.taps`: «عدد الضغطات|الأحزاب المختارة»):
    /// - لم تصل الضغطة إلى التطبيق: تُعاد مرة واحدة وتُسجَّل.
    /// - وصلت ولم يتغيّر الاختيار في التطبيق: خطأ في التطبيق، فيفشل.
    /// - تغيّر الاختيار: نجحت الضغطة. وإن تأخّرت سمة «مختار» عن الظهور طُبع «تشخيص:» بالمدّة،
    ///   ثم يُنتظر ظهورها حتى 20 ث، فإن لم تظهر فشل الاختبار، لأن VoiceOver يعتمد عليها.
    private func tapUntilSelected(_ element: XCUIElement, in app: XCUIApplication,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "لم يظهر \(element)", file: file, line: line)
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: element)
        if XCTWaiter().wait(for: [hittable], timeout: 10) != .completed { app.swipeUp() }
        for attempt in 1...2 {
            let before = appState(app)
            XCTAssertGreaterThanOrEqual(before.taps, 0, "عدّاد الضغطات add.taps غير ظاهر", file: file, line: line)
            let start = Date()
            element.tap()
            // الحقيقة في التطبيق أولاً: هل تغيّر الاختيار؟
            var after = appState(app)
            while after.selected == before.selected, Date().timeIntervalSince(start) < 15 {
                _ = XCTWaiter().wait(for: [XCTestExpectation()], timeout: 0.5)
                after = appState(app)
            }
            if after.selected != before.selected {
                let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: element)
                if XCTWaiter().wait(for: [selected], timeout: 1) != .completed {
                    print("تشخيص: تغيّر الاختيار في التطبيق (\(before.raw) → \(after.raw)) وتأخّرت سمة «مختار»: \(element)")
                    // توقّع جديد: لا يُنتظر التوقّع الواحد مرتين (فشل هكذا في #43).
                    let late = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: element)
                    XCTAssertEqual(XCTWaiter().wait(for: [late], timeout: 20), .completed,
                                   "تغيّر الاختيار في التطبيق ولم تظهر سمة «مختار» خلال 20 ث: \(element)", file: file, line: line)
                    print("تشخيص: ظهرت السمة بعد \(Int(Date().timeIntervalSince(start))) ث")
                }
                return
            }
            if after.taps > before.taps {
                XCTFail("وصلت الضغطة (\(before.raw) → \(after.raw)) ولم يتغيّر الاختيار في التطبيق: \(element)",
                        file: file, line: line)
                return
            }
            if attempt == 1 {
                print("تشخيص: الضغطة لم تصل إلى التطبيق (\(before.raw))، تُعاد مرة: \(element)")
            }
        }
        XCTFail("لم تصل الضغطة إلى التطبيق مرتين: \(element)", file: file, line: line)
    }

    private func appState(_ app: XCUIApplication) -> (taps: Int, selected: String, raw: String) {
        let raw = app.otherElements["add.taps"].value as? String ?? ""
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false)
        return (Int(parts.first ?? "") ?? -1, parts.count > 1 ? String(parts[1]) : "", raw)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// 5.1، 7.2: من البطاقة الفارغة تُضاف الأجزاء 1–4 وح 9 إلى البعيد، فتُطوى البطاقة
    /// على ح 1 بـ «0 من 36»، ويؤكّد الإشعار ما جرى (سيناريو المعاين 2).
    func test_7_2_addJuzAndHizbFromEmptyCard() {
        let app = launch()
        let add = app.buttons["track.farReview.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()

        let go = app.buttons["add.go"]
        // أول ورقة بعد إقلاع المحاكي بارداً قد تتأخّر أكثر من 5 ث (فشل هكذا في #43).
        XCTAssertTrue(go.waitForExistence(timeout: 20))
        XCTAssertFalse(go.isEnabled)
        XCTAssertTrue(app.buttons["add.track.farReview"].isSelected)
        shot(app, "06-add-sheet")

        // كل ضغطة تنتظر أن يصير العنصر قابلاً للضغط، ثم تتحقّق أنه اختير. فشلت مرة بـ «7 أحزاب»
        // لأن ضغطة على دائرة جزء وقعت والورقة ما زالت تتحرّك فلم تصل.
        for juz in 1...4 { tapUntilSelected(app.buttons["add.juz.\(juz)"], in: app) }
        tapUntilSelected(app.buttons["add.hizb.9"], in: app)
        XCTAssertTrue(go.isEnabled)
        XCTAssertEqual(go.label, "أضف 9 أحزاب إلى مراجعة البعيد")
        XCTAssertTrue(app.buttons["add.juz.1"].isSelected)
        XCTAssertTrue(app.buttons["add.hizb.9"].isSelected)
        XCTAssertFalse(app.buttons["add.hizb.10"].isSelected)
        shot(app, "07-add-selected")

        go.tap()
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertEqual(toast.label, "أُضيف 9 أحزاب إلى مراجعة البعيد")
        XCTAssertEqual(app.staticTexts["track.farReview.progress"].label, "0 من 36")
        XCTAssertTrue(app.otherElements["quarter.farReview.1"].exists)
        XCTAssertTrue(app.otherElements["track.nearReview.empty"].exists)
        shot(app, "08-added")
    }

    /// 7.2: في الورقة تظهر الأحزاب الموجودة موسومة: ما في هذا المسار محايد لا يُضغط،
    /// وما في مسار آخر بإطار متقطّع واسم مساره.
    func test_7_2_sheetMarksHizbsAlreadyPlaced() {
        let app = launch(seed: "farReview:1-8;nearReview:10-11")
        let more = app.buttons["track.farReview.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        // ينتظر استقرار الشاشة بعد الفتح قبل الضغط (فشل مرة لأن الضغطة سبقت ظهور البطاقة كاملة).
        XCTAssertTrue(app.otherElements["track.farReview.folded"].waitForExistence(timeout: 10))
        more.tap()
        let item = app.buttons["إضافة"]
        if !item.waitForExistence(timeout: 5) {
            let tree = app.debugDescription.replacingOccurrences(of: "\n", with: " ¦ ")
            XCTFail("لم تظهر «إضافة» في «⋯»: \(tree)")
        }
        item.tap()

        let here = app.buttons["add.hizb.1"]
        XCTAssertTrue(here.waitForExistence(timeout: 5))
        XCTAssertTrue(here.label.contains("في هذا المسار"), here.label)
        // ما في هذا المسار لا يُختار.
        here.tap()
        XCTAssertFalse(here.isSelected)
        XCTAssertTrue(app.buttons["add.hizb.10"].label.contains("في القريب"), app.buttons["add.hizb.10"].label)
        XCTAssertTrue(app.buttons["add.hizb.9"].label.contains("النساء"), app.buttons["add.hizb.9"].label)

        app.buttons["add.juz.5"].tap()
        XCTAssertTrue(app.buttons["add.hizb.9"].isSelected)
        XCTAssertFalse(app.buttons["add.hizb.10"].isSelected)
        shot(app, "09-add-states")
    }

    /// 7.2: تغيير المسار يمحو الاختيار، و«إلغاء» يغلق الورقة دون إضافة.
    func test_7_2_switchTrackClearsAndCancelAddsNothing() {
        let app = launch()
        let add = app.buttons["track.nearReview.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.buttons["add.track.nearReview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["add.track.nearReview"].isSelected)

        app.buttons["add.juz.3"].tap()
        XCTAssertEqual(app.buttons["add.go"].label, "أضف حزبين إلى مراجعة القريب")
        app.buttons["add.track.farReview"].tap()
        XCTAssertFalse(app.buttons["add.go"].isEnabled)
        XCTAssertEqual(app.buttons["add.go"].label, "اختر جزءاً أو حزباً")

        app.buttons["add.cancel"].tap()
        XCTAssertTrue(app.otherElements["track.farReview.empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["track.nearReview.empty"].exists)
    }
}
