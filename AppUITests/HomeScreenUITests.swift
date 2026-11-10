import XCTest

/// الشاشة الرئيسية (7.1) ولقطاتها لصفحة اللقطات.
/// كل اختبار يبدأ التطبيق بمخزن في الذاكرة (`-ui-testing`)، فلا يمسّ مخزناً حقيقياً.
@MainActor
final class HomeScreenUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// محفوظ المثال في النماذج المعتمدة: البعيد ح 1–9، والقريب ح 10–11.
    static let sampleSeed = "farReview:1-9;nearReview:10-11"

    private func launch(seed: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + (seed.map { ["-seed", $0] } ?? [])
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        // اللقطة تُستخرج في سير العمل وتُنشر في صفحة اللقطات.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// 7.1، 5.1: أول فتحة: الاسم والتاريخ، وثلاث بطاقات فارغة بترتيب المالك،
    /// وزرّ الإضافة في البعيد والقريب وحدهما (سيناريو المعاين 1).
    func test_7_1_firstLaunchShowsThreeEmptyTracks() {
        let app = launch()

        let title = app.staticTexts["home.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        XCTAssertEqual(title.label, "الورد اليومي")
        let date = app.staticTexts["home.date"]
        XCTAssertTrue(date.exists)
        XCTAssertNil(date.label.range(of: "[٠-٩۰-۹]", options: .regularExpression), "أرقام مشرقية في التاريخ: \(date.label)")

        for track in ["farReview", "nearReview", "new"] {
            XCTAssertTrue(app.otherElements["track.\(track).empty"].exists, "البطاقة الفارغة: \(track)")
        }
        XCTAssertTrue(app.buttons["track.farReview.add"].exists)
        XCTAssertTrue(app.buttons["track.nearReview.add"].exists)
        XCTAssertFalse(app.buttons["track.new.add"].exists)

        // الترتيب من أعلى: البعيد ثم القريب ثم الجديد.
        let far = app.otherElements["track.farReview.empty"].frame.minY
        let near = app.otherElements["track.nearReview.empty"].frame.minY
        let new = app.otherElements["track.new.empty"].frame.minY
        XCTAssertLessThan(far, near)
        XCTAssertLessThan(near, new)

        shot(app, "01-home-empty")
    }

    /// 7.1: «⋯» في مسار فارغ فيها «إضافة» وحدها (م21).
    func test_7_1_1_emptyTrackMenuHasAddOnly() {
        let app = launch()
        let more = app.buttons["track.nearReview.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 20))
        more.tap()
        XCTAssertTrue(app.buttons["إضافة"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["نقل"].exists)
        XCTAssertFalse(app.buttons["إزالة"].exists)
        shot(app, "02-empty-menu")
    }

    /// 7.1: كل بطاقة مطويّة على موضع توقّفها: صفّ الحزب بأرباعه الأربعة،
    /// وتقدّم الدورة، والسورة ووسم الجزء، وشريط «عرض كامل المراجعة».
    func test_7_1_cardsFoldOnBookmark() {
        let app = launch(seed: Self.sampleSeed)

        // تقدّم الدورة مخفيّ في ش2 حتى يُبنى مع الدورة في ش3 (ذ10).
        let farCount = app.otherElements["track.farReview.quarterCount"]
        XCTAssertTrue(farCount.waitForExistence(timeout: 20))
        XCTAssertEqual(farCount.label, "36")
        XCTAssertEqual(app.otherElements["track.nearReview.quarterCount"].label, "8")
        XCTAssertFalse(app.staticTexts["track.farReview.progress"].exists)

        // البعيد مطويّ على ح 1 (الأرباع 1–4)، والقريب على ح 10 (الأرباع 37–40).
        for q in 1...4 { XCTAssertTrue(app.buttons["quarter.farReview.\(q)"].exists, "الربع \(q)") }
        XCTAssertFalse(app.buttons["quarter.farReview.5"].exists)
        for q in 37...40 { XCTAssertTrue(app.buttons["quarter.nearReview.\(q)"].exists, "الربع \(q)") }
        XCTAssertTrue(app.buttons["track.farReview.pull"].exists)
        XCTAssertTrue(app.buttons["track.nearReview.pull"].exists)
        XCTAssertTrue(app.otherElements["track.new.empty"].exists)

        shot(app, "03-folded")
    }

    /// 7.1: الشريط يفتح الأرشيف كاملاً داخل البطاقة، ولا يُفتح إلا مسار واحد،
    /// و«طيّ» يعيدها مطويّة (سيناريو المعاين 6).
    func test_7_1_openArchiveOneTrackAtATime() {
        let app = launch(seed: Self.sampleSeed)

        let farPull = app.buttons["track.farReview.pull"]
        XCTAssertTrue(farPull.waitForExistence(timeout: 20))
        farPull.tap()

        let farArchive = app.otherElements["track.farReview.archive"]
        XCTAssertTrue(farArchive.waitForExistence(timeout: 20))
        // الأرشيف فيه الأحزاب كلها، لا حزب موضع التوقّف وحده.
        XCTAssertTrue(app.buttons["quarter.farReview.5"].exists)
        XCTAssertEqual(app.buttons["track.farReview.pull"].label, "طيّ")
        shot(app, "04-archive-far")

        // فتح القريب يطوي البعيد.
        app.swipeUp()
        let nearPull = app.buttons["track.nearReview.pull"]
        XCTAssertTrue(nearPull.waitForExistence(timeout: 20))
        nearPull.tap()
        XCTAssertTrue(app.otherElements["track.nearReview.archive"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.otherElements["track.farReview.archive"].exists)
        // م23: الأرشيف القصير شريطه «طيّ» في أسفل بطاقته، فلا شريط ملتصق بأسفل الشاشة.
        XCTAssertTrue(app.buttons["track.nearReview.pull"].isHittable)
        XCTAssertFalse(app.buttons["track.nearReview.pull.sticky"].exists)
        shot(app, "05-archive-near")

        // «طيّ» يعيده مطويّاً.
        app.buttons["track.nearReview.pull"].tap()
        XCTAssertTrue(app.otherElements["track.nearReview.folded"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.otherElements["track.nearReview.archive"].exists)
    }

    /// 7.1: يفتح التطبيق دائماً مطويّاً، ولو أُغلق والأرشيف مفتوح.
    func test_7_1_relaunchOpensFolded() {
        var app = launch(seed: Self.sampleSeed)
        let farPull = app.buttons["track.farReview.pull"]
        XCTAssertTrue(farPull.waitForExistence(timeout: 20))
        farPull.tap()
        XCTAssertTrue(app.otherElements["track.farReview.archive"].waitForExistence(timeout: 20))
        app.terminate()

        app = launch(seed: Self.sampleSeed)
        XCTAssertTrue(app.otherElements["track.farReview.folded"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.otherElements["track.farReview.archive"].exists)
    }
}
