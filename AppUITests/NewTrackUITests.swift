import XCTest

/// ش4 · المرحلة 1: اختيار الحزب الذي يُحفظ الآن، وأوجهه في البطاقة (5.6، design/system.md §15.1–15.2).
/// سيناريوهات المعاين في docs/reports/ش4-التصميم.md §5: 1، 2، 3، 4، 15، 16.
@MainActor
final class NewTrackUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(seed: String? = nil, pages: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + (seed.map { ["-seed", $0] } ?? []) + (pages.map { ["-pages", $0] } ?? [])
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func wait(_ element: XCUIElement, _ format: String, _ text: String = "", timeout: TimeInterval = 20) -> Bool {
        let predicate = text.isEmpty ? NSPredicate(format: format) : NSPredicate(format: format, text)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    private func expectLabel(_ element: XCUIElement, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        if !wait(element, "label == %@", text) {
            XCTAssertEqual(element.exists ? element.label : "(غير موجود)", text, file: file, line: line)
        }
    }

    private func tapSelecting(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 20), "لم يظهر \(element)", file: file, line: line)
        XCTAssertTrue(wait(element, "isHittable == true"), "لا يُضغط \(element)", file: file, line: line)
        element.tap()
        if !wait(element, "isSelected == true", timeout: 10) {
            print("تشخيص: لم يُختر بعد الضغطة الأولى، تُعاد مرة: \(element)")
            element.tap()
            XCTAssertTrue(wait(element, "isSelected == true"), "لم يُختر \(element)", file: file, line: line)
        }
    }

    private func tapEnabled(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(wait(element, "isEnabled == true AND isHittable == true"), "لم يتفعّل \(element)", file: file, line: line)
        element.tap()
    }

    private func page(_ app: XCUIApplication, _ n: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "page.\(n)").firstMatch
    }

    private func expectBookmark(_ app: XCUIApplication, _ n: Int, file: StaticString = #filePath, line: UInt = #line) {
        let element = page(app, n)
        if !wait(element, "label CONTAINS %@", "موضع التوقّف") {
            XCTFail("الإطار ليس على الوجه \(n): \(element.exists ? element.label : "غير موجود")", file: file, line: line)
        }
    }

    private func expectProgress(_ app: XCUIApplication, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        expectLabel(app.staticTexts["track.new.progress"], "الأوجه المحفوظة: \(text)", file: file, line: line)
    }

    /// يفتح ورقة «الحزب الذي تحفظه» من زرّ البطاقة الفارغة.
    private func openPick(_ app: XCUIApplication) {
        let add = app.buttons["track.new.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 20))
        add.tap()
        XCTAssertTrue(app.buttons["add.go"].waitForExistence(timeout: 20))
    }

    /// سيناريوا المعاين 1 و2 (§15.1): الجديد فارغ بسطره وزرّه، و«⋯» فيها «إضافة» وحدها.
    /// ورقة «الحزب الذي تحفظه» بلا مقطع مسار ولا دائرة جزء، وزرّها المعطّل «اختر حزباً».
    /// يختار ح 12 ← «0 من 10» والإطار على 112، والإشعار، وسطر «آخر إدخال» محجوز فارغ.
    func test_5_6_emptyCardAndPick() {
        let app = launch()
        let text = app.staticTexts["track.new.emptyText"]
        XCTAssertTrue(text.waitForExistence(timeout: 20))
        XCTAssertEqual(text.label, "لم تحدّد بعدُ الحزب الذي تحفظه.")
        expectLabel(app.buttons["track.new.add"], "اختر الحزب الذي تحفظه")
        shot(app, "43-new-empty")

        app.buttons["track.new.more"].tap()
        let item = app.buttons["إضافة"]
        XCTAssertTrue(item.waitForExistence(timeout: 20), "لم تظهر «إضافة» في «⋯» الجديد")
        XCTAssertFalse(app.buttons["إزالة"].exists, "في الفارغ «إضافة» وحدها")
        XCTAssertFalse(app.buttons["نقل"].exists, "في الفارغ «إضافة» وحدها")
        item.tap()

        let go = app.buttons["add.go"]
        XCTAssertTrue(go.waitForExistence(timeout: 20))
        expectLabel(go, "اختر حزباً")
        XCTAssertFalse(go.isEnabled)
        XCTAssertFalse(app.buttons["add.track.farReview"].exists, "لا اختيار مسار في ورقة الجديد")
        XCTAssertFalse(app.buttons["add.juz.1"].exists, "الجزء نصّ بلا دائرة")
        XCTAssertTrue(app.staticTexts["add.juz.1"].exists)
        shot(app, "44-new-pick")

        tapSelecting(app.buttons["add.hizb.12"])
        expectLabel(go, "أضف الحزب 12 إلى المحفوظ الجديد")
        tapEnabled(go)

        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 20))
        expectLabel(toast, "أُضيف ح 12 إلى المحفوظ الجديد")
        expectProgress(app, "0 من 10")
        expectBookmark(app, 112)
        XCTAssertTrue(page(app, 116).exists)
        XCTAssertFalse(page(app, 117).exists, "الصفّ المطويّ خمسة أوجه")
        XCTAssertFalse(app.descendants(matching: .any)["track.new.lastEntry"].exists, "قبل أول إتمام لا سطر (ذ17)")
        shot(app, "45-new-picked")

        // في الورقة من جديد: ح 12 «تحفظه الآن» لا يُختار.
        app.buttons["track.new.more"].tap()
        XCTAssertTrue(app.buttons["إضافة"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["إزالة"].exists)
        app.buttons["إضافة"].tap()
        let here = app.buttons["add.hizb.12"]
        XCTAssertTrue(here.waitForExistence(timeout: 20))
        XCTAssertTrue(here.label.contains("تحفظه الآن"), here.label)
    }

    /// سيناريو المعاين 3 (§15.1): يختار ح 11 وهو في القريب ← سؤال النقل؛ «اتركه» لا يغيّر شيئاً،
    /// و«انقله» يضعه في الجديد ويُخرجه من القريب.
    func test_5_6_pickFromNearAsksToMove() {
        let app = launch(seed: "nearReview:10-11")
        openPick(app)
        let chip = app.buttons["add.hizb.11"]
        XCTAssertTrue(chip.waitForExistence(timeout: 20))
        XCTAssertTrue(chip.label.contains("في القريب"), chip.label)
        tapSelecting(chip)
        tapEnabled(app.buttons["add.go"])

        let question = app.staticTexts["conflict.question"]
        XCTAssertTrue(question.waitForExistence(timeout: 20))
        XCTAssertEqual(question.label, "الحزب 11 موجود في مراجعة القريب. أتنقله؟")
        expectLabel(app.buttons["conflict.move"], "انقله إلى المحفوظ الجديد")
        expectLabel(app.buttons["conflict.keep"], "اتركه في مراجعة القريب")
        XCTAssertTrue(app.staticTexts["سجلّ تلاوته ينتقل معه كما هو."].exists)
        shot(app, "46-new-pick-conflict")
        app.buttons["conflict.keep"].tap()
        XCTAssertTrue(app.otherElements["track.new.empty"].waitForExistence(timeout: 20))
        expectLabel(app.otherElements["track.nearReview.quarterCount"], "8")

        openPick(app)
        tapSelecting(app.buttons["add.hizb.11"])
        tapEnabled(app.buttons["add.go"])
        XCTAssertTrue(app.buttons["conflict.move"].waitForExistence(timeout: 20))
        app.buttons["conflict.move"].tap()
        expectLabel(app.staticTexts["toast"], "نُقل ح 11 إلى المحفوظ الجديد")
        expectProgress(app, "0 من 11")
        expectBookmark(app, 102)
        expectLabel(app.otherElements["track.nearReview.quarterCount"], "4")
    }

    /// سيناريو المعاين 4 (§15.2): أتمّ 112–116 قبل ثلاثة أيام ← «5 من 10»، والصفّ 117–121 والإطار على 117،
    /// وعلامة الكتاب بجانب «ح 12»، وسطر «آخر إدخال». ثم «عرض كل أوجه الحزب» وطيّ ← كما هو.
    func test_5_6_foldedRowAndAllPages() {
        let app = launch(seed: "new:12", pages: "112-116:3")
        expectProgress(app, "5 من 10")
        expectBookmark(app, 117)
        XCTAssertTrue(page(app, 121).exists)
        XCTAssertFalse(page(app, 116).exists, "الصفّ المطويّ 117–121")
        expectLabel(app.descendants(matching: .any)["hizb.new.12"], "الحزب 12، فيه موضع التوقّف")
        expectLabel(app.staticTexts["hizb.new.12.line"], "· المائدة · الجزء 6")
        let last = app.descendants(matching: .any)["track.new.lastEntry"]
        XCTAssertTrue(wait(last, "label BEGINSWITH %@", "آخر إدخال قبل 3 أيام"), last.label)
        shot(app, "47-new-folded")

        let pull = app.buttons["track.new.pull"]
        expectLabel(pull, "عرض كل أوجه الحزب")
        if !pull.isHittable { app.swipeUp() }
        pull.tap()
        // مع حزب واحد يدمج SwiftUI قسمه في «track.new.archive» في شجرة الإتاحة، فلا يظهر «section.new.12»
        // عنصراً مستقلّاً (#101، والقسم ظاهر على الشاشة). فيُتحقّق من الأرشيف ومن أوجه الحزب كلها.
        XCTAssertTrue(app.otherElements["track.new.archive"].waitForExistence(timeout: 20), "لم تُفتح البطاقة")
        XCTAssertTrue(page(app, 112).waitForExistence(timeout: 20))
        expectLabel(page(app, 112), "الوجه 112، محفوظ")
        expectLabel(page(app, 117), "الوجه 117، لم يُحفظ، موضع التوقّف")
        XCTAssertTrue(page(app, 121).exists)
        shot(app, "48-new-all-pages")

        // «طيّ» في أسفل البطاقة، أو ملتصقاً بأسفل الشاشة إن نزل تحتها (م23).
        let sticky = app.buttons["track.new.pull.sticky"]
        if sticky.exists && sticky.isHittable { sticky.tap() } else {
            let fold = app.buttons["track.new.pull"]
            if !fold.isHittable { app.swipeUp() }
            fold.tap()
        }
        XCTAssertTrue(wait(page(app, 112), "exists == false"), "طُويت البطاقة")
        expectBookmark(app, 117)
        expectProgress(app, "5 من 10")
    }

    /// سيناريو المعاين 15 (§15.6): يزيل ح 12 من «⋯» ← البطاقة فارغة؛ يعيده ← أوجهه كما كانت.
    func test_5_6_removeAndReAdd() {
        let app = launch(seed: "new:12", pages: "112-116:3")
        expectProgress(app, "5 من 10")
        app.buttons["track.new.more"].tap()
        let item = app.buttons["إزالة"]
        XCTAssertTrue(item.waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["نقل"].exists, "النقل بين المسارات الثلاثة في المرحلة 4")
        item.tap()
        expectLabel(app.staticTexts["manage.title"], "إزالة من المحفوظ الجديد")
        XCTAssertTrue(app.staticTexts["يبقى سجلّ حفظ ما تزيله محفوظاً."].exists)
        tapSelecting(app.buttons["manage.hizb.12"])
        tapEnabled(app.buttons["manage.go"])
        let question = app.staticTexts["remove.question"]
        XCTAssertTrue(question.waitForExistence(timeout: 20))
        XCTAssertEqual(question.label, "أتزيل الحزب 12 من المحفوظ الجديد؟")
        XCTAssertTrue(app.staticTexts["يبقى سجلّ حفظه محفوظاً، فإن أعدته ظهرت أوجهه كما كانت."].exists)
        shot(app, "49-new-remove")
        app.buttons["remove.confirm"].tap()
        expectLabel(app.staticTexts["toast"], "أُزيل ح 12 · سجلّه محفوظ")
        XCTAssertTrue(app.otherElements["track.new.empty"].waitForExistence(timeout: 20))

        openPick(app)
        tapSelecting(app.buttons["add.hizb.12"])
        tapEnabled(app.buttons["add.go"])
        expectProgress(app, "5 من 10")
        expectBookmark(app, 117)
    }

    /// سيناريو المعاين 16 (§15.2): ح 60 أوجهه 14. أتمّ 591–596 ← الصفّ 596–600 والإطار على 597،
    /// والسطر «· الأعلى ← الناس · الجزء 30».
    func test_5_6_hizb60RowOfFive() {
        let app = launch(seed: "new:60", pages: "591-596:2")
        expectProgress(app, "6 من 14")
        expectBookmark(app, 597)
        XCTAssertTrue(page(app, 596).exists)
        XCTAssertTrue(page(app, 600).exists)
        XCTAssertFalse(page(app, 595).exists)
        XCTAssertFalse(page(app, 601).exists)
        expectLabel(app.staticTexts["hizb.new.60.line"], "· الأعلى ← الناس · الجزء 30")
        shot(app, "50-new-hizb60")
    }

    /// سيناريو المعاين 16 (§15.2): أتمّ حتى 600 ← آخر صفّ يُكمل ممّا قبله: 600–604 والإطار على 601.
    func test_5_6_hizb60LastRowBackfills() {
        let app = launch(seed: "new:60", pages: "591-600:2")
        expectProgress(app, "10 من 14")
        expectBookmark(app, 601)
        XCTAssertTrue(page(app, 600).exists)
        XCTAssertTrue(page(app, 604).exists)
        XCTAssertFalse(page(app, 599).exists)
        shot(app, "51-new-hizb60-last")
    }
}
