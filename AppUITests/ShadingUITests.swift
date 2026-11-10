import XCTest

/// ش2 · المرحلتان 1 و2: التظليل بالتاريخ وعلامة «اليوم»، والتراجع (5.3، §13.1، §13.2) ولقطاتهما.
/// سيناريوهات المعاين في docs/reports/ش2-التصميم.md §5: 1 (التظليل)، 2 (التراجع)، 3 (منتصف الليل)، 5 (المشترك).
@MainActor
final class ShadingUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(seed: String, readings: String? = nil, now: String? = nil, testClock: Bool = false,
                        locale: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed", seed] + (testClock ? ["-test-clock"] : [])
            + (readings.map { ["-readings", $0] } ?? [])
            + (now.map { ["-now", $0] } ?? [])
            + (locale.map { ["-AppleLocale", $0] } ?? [])
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

    private func lastEntry(_ track: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["track.\(track).lastEntry"]
    }

    /// ينتظر نصّ سطر «آخر إدخال».
    private func expectLastEntry(_ track: String, _ text: String, _ app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let element = lastEntry(track, app)
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", text), object: element)
        if XCTWaiter().wait(for: [match], timeout: 20) != .completed {
            XCTAssertEqual(element.exists ? element.label : "(لا سطر)", text, file: file, line: line)
        }
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
        // تظليل الأمس عمره يوم: ممتلئ بلا علامة «اليوم» (5.4).
        expectValue(q1, "خلال 7 أيام")
        XCTAssertTrue(lastEntry("farReview", app).label.hasPrefix("آخر إدخال أمس"), "السطر «أمس» بعد منتصف الليل")
        shot(app, "24-after-midnight")
        q1.tap()
        expectValue(q1, "تلوته اليوم")
    }

    /// 5.4، القرار 14: الدرجات الخمس بالأيام والحدود شاملة: 7 ممتلئ · 8 و15 نصف · 16 و22 ربع ·
    /// 23 مخطّط · بلا تظليل فارغ (سيناريو المعاين 4). ولقطتها تُفحص بالرمادي.
    func test_5_4_fiveAgeLevels() {
        let app = launch(seed: "farReview:1-2", readings: "1:7,2:8,3:15,4:16,5:22,6:23,8:0")
        let q1 = app.buttons["quarter.farReview.1"]
        XCTAssertTrue(q1.waitForExistence(timeout: 20))
        expectValue(q1, "خلال 7 أيام")
        XCTAssertEqual(app.buttons["quarter.farReview.2"].value as? String, "خلال 15 يوماً")
        XCTAssertEqual(app.buttons["quarter.farReview.3"].value as? String, "خلال 15 يوماً")
        XCTAssertEqual(app.buttons["quarter.farReview.4"].value as? String, "خلال 22 يوماً")
        open("farReview", app)
        XCTAssertEqual(app.buttons["quarter.farReview.5"].value as? String, "خلال 22 يوماً")
        XCTAssertEqual(app.buttons["quarter.farReview.6"].value as? String, "أكثر من 22 يوماً")
        XCTAssertEqual(app.buttons["quarter.farReview.7"].value as? String, "لم يُتلَ")
        XCTAssertEqual(app.buttons["quarter.farReview.8"].value as? String, "تلوته اليوم")
        shot(app, "26-age-levels")

        // الضغط على ربع مخطّط يملؤه بعلامة «اليوم»، والتراجع يعيده مخطّطاً.
        let q6 = app.buttons["quarter.farReview.6"]
        q6.tap()
        expectValue(q6, "تلوته اليوم")
        q6.tap()
        expectValue(q6, "أكثر من 22 يوماً")
    }

    /// 7.1، 7.1.2، §13.4: فوق كل بطاقة مراجعة سطر «آخر إدخال» بالمدّة ثم اليوم والتاريخ والوقت،
    /// وهو أحدث تظليل في المسار. وقبل أول إدخال لا سطر (ذ12) ومكانه محجوز، فلا تنزل البطاقة مع أول ضغطة (ذ17).
    /// والتراجع يعيده إلى ما قبله، وإن لم يبقَ إدخال زال (سيناريوا المعاين 1 و2).
    /// والجهاز بمنطقة السعودية وتقويمها الهجري، والتاريخ ميلادي بأرقام إنجليزية (سيناريو المعاين 8، القرار 1).
    func test_13_4_lastEntryLine() {
        let app = launch(seed: "farReview:1-9;nearReview:10-11", readings: "1:3@05:34,2:10@06:00",
                         now: "2026-11-09T07:00:00", locale: "ar_SA@calendar=islamic-umalqura")
        let near = app.buttons["quarter.nearReview.37"]
        XCTAssertTrue(near.waitForExistence(timeout: 20))
        expectLastEntry("farReview", "آخر إدخال قبل 3 أيام، الجمعة 6 نوفمبر · 5:34 ص", app)
        XCTAssertFalse(lastEntry("nearReview", app).exists, "لا سطر قبل أول إدخال (ذ12)")
        let top = near.frame.minY

        near.tap()
        expectValue(near, "تلوته اليوم")
        let entry = lastEntry("nearReview", app)
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        XCTAssertTrue(entry.label.hasPrefix("آخر إدخال اليوم، الاثنين 9 نوفمبر · "), entry.label)
        XCTAssertEqual(near.frame.minY, top, accuracy: 0.5, "مكان السطر محجوز، فلم تنزل البطاقة (ذ17)")
        shot(app, "27-last-entry")

        near.tap()
        expectValue(near, "لم يُتلَ")
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: entry)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 20), .completed, "التراجع أزال السطر، فلم يبقَ إدخال")

        // وفي البعيد يعود السطر إلى ما قبل التراجع.
        let q1 = app.buttons["quarter.farReview.1"]
        q1.tap()
        expectValue(q1, "تلوته اليوم")
        q1.tap()
        expectValue(q1, "خلال 7 أيام")
        expectLastEntry("farReview", "آخر إدخال قبل 3 أيام، الجمعة 6 نوفمبر · 5:34 ص", app)
    }

    /// 7.1.3، §13.6: عند الفتح لا تُرى المفاتيح، وفي أسفل الشاشة إشارة «اسحب للأعلى»؛ وبعد السحب تُرى
    /// الدرجات الخمس بمعانيها بالأيام (ذ15) والعلامات على مربّع محايد ومجموعة المحفوظ الجديد (سيناريو المعاين 7).
    func test_7_1_3_keysBySwipe() {
        let app = launch(seed: "farReview:1-2", readings: "1:7,2:8,3:15,4:16,5:22,6:23,8:0")
        let keys = app.descendants(matching: .any)["keys"]
        XCTAssertTrue(app.buttons["quarter.farReview.1"].waitForExistence(timeout: 20))
        XCTAssertTrue(keys.waitForExistence(timeout: 20))
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(keys.frame.minY, screen.maxY - 40, "المفاتيح لا تُرى عند الفتح")
        XCTAssertTrue(app.descendants(matching: .any)["keys.hint"].exists, "إشارة «اسحب للأعلى»")

        app.swipeUp()
        XCTAssertLessThan(keys.frame.minY, screen.maxY - 200, "ظهرت المفاتيح بالسحب")
        for meaning in ["خلال 7 أيام", "خلال 15 يوماً", "خلال 22 يوماً", "أكثر من 22", "لم يُتلَ",
                        "تلوته اليوم", "موضع التوقّف", "بين سورتين", "وجه محفوظ", "لم يُحفظ"] {
            XCTAssertTrue(keys.descendants(matching: .any)[meaning].exists, meaning)
        }
        shot(app, "28-keys")
    }
}
