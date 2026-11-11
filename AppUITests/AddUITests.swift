import XCTest

/// ش1 · المرحلة 2: إضافة جزء أو حزب (5.1، 7.2) ولقطاتها.
@MainActor
final class AddUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(seed: String? = nil, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + (seed.map { ["-seed", $0] } ?? []) + extra
        app.launch()
        return app
    }

    /// يضغط دائرة جزء أو خانة حزب، ويتحقّق من الاختيار في التطبيق نفسه وفي سمة الإتاحة.
    /// يقرأ ما يعرضه التطبيق في وضع الاختبار (`add.taps`: «عدد الضغطات|الأحزاب المختارة|ضغطات أضف»):
    /// - لم تصل الضغطة إلى التطبيق: تُعاد مرة واحدة وتُسجَّل.
    /// - وصلت ولم يتغيّر الاختيار في التطبيق: خطأ في التطبيق، فيفشل.
    /// - تغيّر الاختيار: نجحت الضغطة. وإن تأخّرت سمة «مختار» عن الظهور طُبع «تشخيص:» بالمدّة،
    ///   ثم يُنتظر ظهورها حتى 20 ث، فإن لم تظهر فشل الاختبار، لأن VoiceOver يعتمد عليها.
    private func tapUntilSelected(_ element: XCUIElement, in app: XCUIApplication,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 20), "لم يظهر \(element)", file: file, line: line)
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

    /// ينتظر أن يصير نصّ العنصر كما يُتوقّع. ما تقرؤه أداة الاختبار يتأخّر 2 إلى 4 ث عن التطبيق
    /// على محاكي CI (#43)، فلا يُقرأ النصّ مباشرة بعد ضغطة.
    private func expectLabel(_ element: XCUIElement, _ text: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", text), object: element)
        if XCTWaiter().wait(for: [match], timeout: 20) != .completed {
            XCTAssertEqual(element.label, text, file: file, line: line)
        }
    }

    /// يضغط الزرّ بعد أن تراه أداة الاختبار مفعّلاً. فـ«أضف» يتفعّل في التطبيق مع الاختيار،
    /// وتراه الأداة مفعّلاً بعد 2 إلى 4 ث على محاكي CI (#43).
    private func tapEnabled(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true AND isHittable == true"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 20), .completed, "لم يتفعّل \(element)", file: file, line: line)
        element.tap()
    }

    private func appState(_ app: XCUIApplication) -> (taps: Int, selected: String, go: Int, raw: String) {
        let raw = app.otherElements["add.taps"].value as? String ?? ""
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false)
        return (Int(parts.first ?? "") ?? -1, parts.count > 1 ? String(parts[1]) : "",
                parts.count > 2 ? Int(parts[2]) ?? -1 : -1, raw)
    }

    /// يضغط «أضف» وفي الاختيار حزب في مسار آخر، فينتظر سؤال النقل. على محاكي CI قد لا تصل الضغطة
    /// إلى التطبيق (فشل هكذا بعد #112: لم يظهر «انقله» 20 ث). فيُقرأ عدّاد «أضف» في التطبيق:
    /// لم تصل ← تُعاد مرة وتُسجَّل؛ وصلت ولم يظهر السؤال ← خطأ في التطبيق فيفشل.
    private func tapGoExpectingConflict(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let go = app.buttons["add.go"]
        let question = app.staticTexts["conflict.question"]
        for attempt in 1...2 {
            let before = appState(app)
            tapEnabled(go, file: file, line: line)
            if question.waitForExistence(timeout: 10) { return }
            let after = appState(app)
            if after.go > before.go {
                XCTFail("وصلت ضغطة «أضف» (\(before.raw) → \(after.raw)) ولم يظهر سؤال النقل", file: file, line: line)
                return
            }
            if attempt == 1 { print("تشخيص: ضغطة «أضف» لم تصل إلى التطبيق (\(before.raw))، تُعاد مرة") }
        }
        XCTFail("لم تصل ضغطة «أضف» إلى التطبيق مرتين: \(appState(app).raw)", file: file, line: line)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// 5.1، 7.2: من البطاقة الفارغة تُضاف الأجزاء 1–4 وح 9 إلى البعيد، فتُطوى البطاقة
    /// على ح 1 وفيه 36 ربعاً، ويؤكّد الإشعار ما جرى (سيناريو المعاين 2).
    func test_7_2_addJuzAndHizbFromEmptyCard() {
        let app = launch()
        let add = app.buttons["track.farReview.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 20))
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
        expectLabel(go, "أضف 9 أحزاب إلى مراجعة البعيد")
        XCTAssertTrue(app.buttons["add.juz.1"].isSelected)
        XCTAssertTrue(app.buttons["add.hizb.9"].isSelected)
        XCTAssertFalse(app.buttons["add.hizb.10"].isSelected)
        shot(app, "07-add-selected")

        tapEnabled(go)
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 20))
        expectLabel(toast, "أُضيف 9 أحزاب إلى مراجعة البعيد")
        expectLabel(app.otherElements["track.farReview.quarterCount"], "36")
        XCTAssertTrue(app.buttons["quarter.farReview.1"].exists)
        XCTAssertTrue(app.otherElements["track.nearReview.empty"].exists)
        shot(app, "08-added")
    }

    /// 7.2: في الورقة تظهر الأحزاب الموجودة موسومة: ما في هذا المسار محايد لا يُضغط،
    /// وما في مسار آخر بإطار متقطّع واسم مساره.
    func test_7_2_sheetMarksHizbsAlreadyPlaced() {
        let app = launch(seed: "farReview:1-8;nearReview:10-11")
        let more = app.buttons["track.farReview.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 20))
        // ينتظر استقرار الشاشة بعد الفتح قبل الضغط (فشل مرة لأن الضغطة سبقت ظهور البطاقة كاملة).
        XCTAssertTrue(app.otherElements["track.farReview.folded"].waitForExistence(timeout: 20))
        more.tap()
        let item = app.buttons["إضافة"]
        if !item.waitForExistence(timeout: 20) {
            let tree = app.debugDescription.replacingOccurrences(of: "\n", with: " ¦ ")
            XCTFail("لم تظهر «إضافة» في «⋯»: \(tree)")
        }
        item.tap()

        let here = app.buttons["add.hizb.1"]
        XCTAssertTrue(here.waitForExistence(timeout: 20))
        XCTAssertTrue(here.label.contains("في هذا المسار"), here.label)
        // ما في هذا المسار لا يُختار.
        here.tap()
        XCTAssertFalse(here.isSelected)
        XCTAssertTrue(app.buttons["add.hizb.10"].label.contains("في القريب"), app.buttons["add.hizb.10"].label)
        XCTAssertTrue(app.buttons["add.hizb.9"].label.contains("النساء"), app.buttons["add.hizb.9"].label)

        tapUntilSelected(app.buttons["add.juz.5"], in: app)
        XCTAssertTrue(app.buttons["add.hizb.9"].isSelected)
        XCTAssertTrue(app.buttons["add.hizb.10"].isSelected, "ما في مسار آخر يُختار، ويُسأل عنه عند «أضف»")
        XCTAssertFalse(app.buttons["add.hizb.11"].isSelected)
        shot(app, "09-add-states")
    }

    /// 7.2: تغيير المسار يمحو الاختيار، و«إلغاء» يغلق الورقة دون إضافة.
    func test_7_2_switchTrackClearsAndCancelAddsNothing() {
        let app = launch()
        let add = app.buttons["track.nearReview.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 20))
        add.tap()
        XCTAssertTrue(app.buttons["add.track.nearReview"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["add.track.nearReview"].isSelected)

        tapUntilSelected(app.buttons["add.juz.3"], in: app)
        expectLabel(app.buttons["add.go"], "أضف حزبين إلى مراجعة القريب")
        app.buttons["add.track.farReview"].tap()
        expectLabel(app.buttons["add.go"], "اختر جزءاً أو حزباً")
        XCTAssertFalse(app.buttons["add.go"].isEnabled)

        app.buttons["add.cancel"].tap()
        XCTAssertTrue(app.otherElements["track.farReview.empty"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.otherElements["track.nearReview.empty"].exists)
    }

    /// 5.1، 12.3: الجزء 5 إلى البعيد وح 10 في القريب: يُسأل «الحزب 10 موجود في مراجعة القريب. أتنقله؟».
    /// «اتركه» يضيف ح 9 وحده، و«انقله» ينقل ح 10 (سيناريو المعاين 3).
    func test_5_1_conflictAsksBeforeMoving() {
        let app = launch(seed: "farReview:1-8;nearReview:10-11")
        let more = app.buttons["track.farReview.more"]
        XCTAssertTrue(app.otherElements["track.farReview.folded"].waitForExistence(timeout: 20))
        more.tap()
        let item = app.buttons["إضافة"]
        XCTAssertTrue(item.waitForExistence(timeout: 20))
        item.tap()
        XCTAssertTrue(app.buttons["add.juz.5"].waitForExistence(timeout: 20))
        tapUntilSelected(app.buttons["add.juz.5"], in: app)
        tapGoExpectingConflict(app)

        let question = app.staticTexts["conflict.question"]
        XCTAssertEqual(question.label, "الحزب 10 موجود في مراجعة القريب. أتنقله؟")
        XCTAssertEqual(app.buttons["conflict.move"].label, "انقله إلى مراجعة البعيد")
        XCTAssertEqual(app.buttons["conflict.keep"].label, "اتركه في مراجعة القريب")
        shot(app, "14-conflict")

        // «اتركه»: يُضاف ح 9 وحده، ويبقى ح 10 في القريب.
        app.buttons["conflict.keep"].tap()
        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 20))
        expectLabel(app.staticTexts["toast"], "أُضيف ح 9 إلى مراجعة البعيد")
        expectLabel(app.otherElements["track.farReview.quarterCount"], "36")
        expectLabel(app.otherElements["track.nearReview.quarterCount"], "8")

        // ثم «انقله»: ح 10 ينتقل إلى البعيد، ولا يبقى في القريب.
        app.buttons["track.farReview.more"].tap()
        XCTAssertTrue(app.buttons["إضافة"].waitForExistence(timeout: 20))
        app.buttons["إضافة"].tap()
        XCTAssertTrue(app.buttons["add.hizb.10"].waitForExistence(timeout: 20))
        tapUntilSelected(app.buttons["add.hizb.10"], in: app)
        tapGoExpectingConflict(app)
        XCTAssertTrue(app.buttons["conflict.move"].waitForExistence(timeout: 20))
        app.buttons["conflict.move"].tap()
        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 20))
        expectLabel(app.staticTexts["toast"], "نُقل ح 10 إلى مراجعة البعيد")
        expectLabel(app.otherElements["track.farReview.quarterCount"], "40")
        expectLabel(app.otherElements["track.nearReview.quarterCount"], "4")
        shot(app, "15-moved-by-add")
    }

    /// يضيف أحزاباً إلى مسار من «⋯ ← إضافة».
    private func addFromMenu(_ hizbs: [Int], to track: String, in app: XCUIApplication) {
        let more = app.buttons["track.\(track).more"]
        XCTAssertTrue(more.waitForExistence(timeout: 20))
        more.tap()
        let item = app.buttons["إضافة"]
        XCTAssertTrue(item.waitForExistence(timeout: 20))
        item.tap()
        XCTAssertTrue(app.buttons["add.go"].waitForExistence(timeout: 20))
        for hizb in hizbs { tapUntilSelected(app.buttons["add.hizb.\(hizb)"], in: app) }
        let go = app.buttons["add.go"]
        tapEnabled(go)
        // لا يُسأل التطبيق عن شيء آخر حتى تُغلق الورقة: الاستعلام أثناء حركة الإغلاق يثقل خدمة الإتاحة.
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: go)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 20), .completed, "لم تُغلق ورقة الإضافة")
    }

    /// ش3 · المرحلة 4، §14.6 (ذ22): الحزب المضاف في منتصف الدورة بعد موضع التوقّف يدخلها في مكانه
    /// ويزيد العدد: «2 من 8» تصير «2 من 12»، والإشعار كما في §12.2 (سيناريو المعاين 10).
    /// وكانت هذه والتي بعدها اختباراً واحداً بإضافتين، يفشل أحياناً بمهلة kAXErrorIPCTimeout
    /// (main: 43012852418، 43111899475)، ففُصلتا ليبدأ كلٌّ بتطبيق جديد وشجرة إتاحة أصغر.
    func test_14_6_addAfterBookmark() {
        let app = launch(seed: "farReview:1-3;nearReview:10-11",
                         extra: ["-cycle", "farReview:20,nearReview:3", "-readings", "37:1,38:1"])
        let progress = app.staticTexts["track.nearReview.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 20))
        expectLabel(progress, "تقدّم الدورة: 2 من 8 ربعاً")

        addFromMenu([12], to: "nearReview", in: app)
        expectLabel(app.staticTexts["toast"], "أُضيف ح 12 إلى مراجعة القريب")
        expectLabel(progress, "تقدّم الدورة: 2 من 12 ربعاً")
        XCTAssertTrue(app.buttons["quarter.nearReview.39"].label.contains("موضع التوقّف"), "الموضع باقٍ على ح 10")
        shot(app, "41-add-after")
    }

    /// §14.6 (ذ22): والمضاف قبل موضع التوقّف ينتقل إليه الموضع والصفّ المطويّ، ويقول الإشعار
    /// «أُضيف ح 5 · وفيه الآن موضع التوقّف» (سيناريو المعاين 11). يبدأ من القريب 10–12، وهو
    /// ما ينتهي إليه الاختبار السابق.
    func test_14_6_addBeforeBookmark() {
        let app = launch(seed: "farReview:1-3;nearReview:10-12",
                         extra: ["-cycle", "farReview:20,nearReview:3", "-readings", "37:1,38:1"])
        let progress = app.staticTexts["track.nearReview.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 20))
        expectLabel(progress, "تقدّم الدورة: 2 من 12 ربعاً")

        addFromMenu([5], to: "nearReview", in: app)
        expectLabel(app.staticTexts["toast"], "أُضيف ح 5 · وفيه الآن موضع التوقّف")
        expectLabel(progress, "تقدّم الدورة: 2 من 16 ربعاً")
        let q17 = app.buttons.matching(identifier: "quarter.nearReview.17").firstMatch
        XCTAssertTrue(q17.waitForExistence(timeout: 20), "الصفّ المطويّ على ح 5")
        XCTAssertTrue(q17.label.contains("موضع التوقّف"))
        XCTAssertFalse(app.buttons["quarter.nearReview.39"].exists)
        shot(app, "42-add-before")
    }
}
