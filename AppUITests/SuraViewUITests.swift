import XCTest

/// ش1 · المرحلة 3: العرض بالسور في الأرشيف (7.1.1) ولقطاته.
@MainActor
final class SuraViewUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(seed: String) -> XCUIApplication {
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

    private func open(_ track: String, _ app: XCUIApplication) {
        let pull = app.buttons["track.\(track).pull"]
        XCTAssertTrue(pull.waitForExistence(timeout: 10))
        if !pull.isHittable { app.swipeUp() }
        pull.tap()
        XCTAssertTrue(app.otherElements["track.\(track).archive"].waitForExistence(timeout: 5))
    }

    /// 7.1.1: قسم لكل سورة، والربع المشترك (ح 1 الربع 1) تحت الفاتحة والبقرة معاً،
    /// ووسم الجزء عند أول حزب فيه (سيناريو المعاين 6).
    func test_7_1_1_archiveIsOrderedBySura() {
        let app = launch(seed: "farReview:1-9;nearReview:10-11")
        open("farReview", app)
        XCTAssertTrue(app.otherElements["section.farReview.1"].exists)
        XCTAssertTrue(app.otherElements["section.farReview.2"].exists)
        XCTAssertEqual(app.otherElements.matching(identifier: "quarter.farReview.1").count, 2, "الربع المشترك في الموضعين")
        XCTAssertEqual(app.otherElements.matching(identifier: "quarter.farReview.2").count, 1)
        shot(app, "10-suras-top")

        // ح 5 مقسوم بين البقرة وآل عمران بربع مشترك، وح 8 بين آل عمران والنساء.
        let imran = app.otherElements["section.farReview.3"]
        for _ in 0..<4 where !imran.isHittable { app.swipeUp() }
        XCTAssertTrue(imran.exists)
        XCTAssertEqual(app.otherElements.matching(identifier: "quarter.farReview.20").count, 2)
        shot(app, "11-suras-split")
    }

    /// 7.1.1: سورة في مسارين: النساء في البعيد (ح 8–9) وفي القريب (ح 10–11)، ولكلٍّ أرباعه.
    func test_7_1_1_suraInTwoTracks() {
        let app = launch(seed: "farReview:1-9;nearReview:10-11")
        open("nearReview", app)
        XCTAssertTrue(app.otherElements["section.nearReview.4"].exists)
        XCTAssertTrue(app.otherElements["section.nearReview.5"].exists)
        XCTAssertTrue(app.otherElements["quarter.nearReview.37"].exists)
        XCTAssertFalse(app.otherElements["quarter.nearReview.33"].exists)
        shot(app, "12-suras-two-tracks")
    }

    /// 7.1.1: السور القصيرة المتجاورة في الأرباع نفسها قسم واحد عنوانه أسماؤها.
    func test_7_1_1_shortSurasGrouped() {
        let app = launch(seed: "farReview:59-60")
        open("farReview", app)
        XCTAssertTrue(app.otherElements["section.farReview.78"].exists)
        XCTAssertFalse(app.otherElements["section.farReview.79"].exists, "النازعات مجموعة مع النبأ")
        shot(app, "13-suras-amma")
    }
}
