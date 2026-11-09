import XCTest

/// ش0 · المرحلة 2: الشاشة الوحيدة، ولقطتها لصفحة اللقطات.
@MainActor
final class HomeScreenUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func test_home_showsAppName() {
        let app = XCUIApplication()
        app.launch()

        let title = app.staticTexts["home.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "الورد اليومي")

        // اللقطة تُستخرج في سير العمل وتُنشر في صفحة اللقطات.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "01-home"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
