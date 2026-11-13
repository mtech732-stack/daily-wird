import XCTest
import UIKit

/// ش6 · المرحلة 4: شاشة البداية (8.3، design/system.md §17.2، ذ47). النظام يعرضها لحظة قبل التطبيق،
/// فتُعرض هنا من `LaunchScreen.storyboard` نفسه بـ`-launch-preview`، ويُقرأ لونها من بكسل اللقطة.
@MainActor
final class LaunchUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(dark: Bool, _ extra: [String] = ["-launch-preview"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", dark ? "-dark" : "-light"] + extra
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func color(_ app: XCUIApplication, at point: CGPoint) -> (r: Int, g: Int, b: Int) {
        guard let cg = app.screenshot().image.cgImage else { return (-1, -1, -1) }
        let scale = CGFloat(cg.width) / app.frame.width
        let x = Int(point.x * scale), y = Int(point.y * scale)
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: -x, y: y - cg.height + 1, width: cg.width, height: cg.height))
        return (Int(px[0]), Int(px[1]), Int(px[2]))
    }

    private func expectColor(_ app: XCUIApplication, at point: CGPoint, _ hex: Int, _ what: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        let c = color(app, at: point)
        let want = (r: hex >> 16 & 0xFF, g: hex >> 8 & 0xFF, b: hex & 0xFF)
        let near = abs(c.r - want.r) <= 12 && abs(c.g - want.g) <= 12 && abs(c.b - want.b) <= 12
        XCTAssertTrue(near, "\(what): \(c) والمطلوب #\(String(format: "%06X", hex))", file: file, line: line)
    }

    /// يفحص الأرضية، والمسطرة العليا للشريط، والعلامة على 68% من العرض إن كانت، وما يسارها.
    private func check(_ app: XCUIApplication, paper: Int, gilt: Int, ribbon: Bool) {
        let w = app.frame.width, h = app.frame.height
        expectColor(app, at: CGPoint(x: 20, y: 160), paper, "الأرضية")
        expectColor(app, at: CGPoint(x: 60, y: h / 2 - 42.5 + 1.8), gilt, "المسطرة الغليظة فوق الشريط")
        if ribbon {
            expectColor(app, at: CGPoint(x: w * 0.68, y: 160), gilt, "العلامة على 68% من العرض")
        } else {
            expectColor(app, at: CGPoint(x: w * 0.68, y: 160), paper, "لا علامة قبل انسدالها")
        }
        expectColor(app, at: CGPoint(x: w * 0.5, y: 160), paper, "لا شيء يسار العلامة فوق الشريط")
        expectColor(app, at: CGPoint(x: w * 0.68, y: h / 2 + 42.5 + 60), paper, "العلامة تنتهي بعد الشريط بنحو 38")
    }

    private func waitFor(_ app: XCUIApplication, _ id: String) {
        XCTAssertTrue(app.descendants(matching: .any)[id].waitForExistence(timeout: 20), id)
        // يُنتظر أول رسم قبل قراءة البكسل.
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// ذ47: الشاشة الثابتة الشريط وحده على `paper`، بلا نصّ؛ والعلامة تنسدل بعدها في الحركة.
    func test_8_3_launchScreenLight() {
        let app = launch(dark: false)
        waitFor(app, "launch.preview")
        check(app, paper: 0xF7F4EC, gilt: 0xDF8C16, ribbon: false)
        XCTAssertEqual(app.staticTexts.count, 0, "لا نصّ في شاشة البداية")
        shot(app, "87-launch")
    }

    /// §17.2 ليلاً: الأرضية #13283E، والذهبي #E39A33.
    func test_8_3_launchScreenDark() {
        let app = launch(dark: true)
        waitFor(app, "launch.preview")
        check(app, paper: 0x13283E, gilt: 0xE39A33, ribbon: false)
        shot(app, "88-launch-dark")
    }

    /// حركة البداية بعد انسدال العلامة: الأيقونة مبسوطة كما كانت شاشة البداية في ش6، ثم التلاشي إلى الشاشة الرئيسية.
    func test_launchSplashRibbonSettled() {
        let app = launch(dark: false, ["-launch-splash", "-splash-freeze", "ribbon"])
        waitFor(app, "splash.ribbon")
        check(app, paper: 0xF7F4EC, gilt: 0xDF8C16, ribbon: true)
        shot(app, "89-splash-ribbon")
    }

    /// التلاشي هادئ لا ومضة: في منتصفه تُرى الحركة والشاشة الرئيسية معاً (ملاحظة المالك 21:04 UTC).
    func test_launchSplashFadesGently() {
        let app = launch(dark: false, ["-launch-splash", "-splash-freeze", "fading-half"])
        waitFor(app, "splash.fading")
        // تُرى الحركة والشاشة الرئيسية معاً في اللقطة 90، والتلاشي نفسه في المعاينة المتحرّكة.
        XCTAssertTrue(app.staticTexts["home.title"].exists)
        shot(app, "90-splash-fading")
    }

    /// الحركة كاملة تنتهي وحدها إلى الشاشة الرئيسية في ثوانٍ.
    func test_launchSplashEndsOnHome() {
        let app = launch(dark: false, ["-launch-splash"])
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 20))
        let splash = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'splash.'"))
        let gone = expectation(for: NSPredicate(format: "count == 0"), evaluatedWith: splash)
        wait(for: [gone], timeout: 8)
        XCTAssertTrue(app.staticTexts["home.title"].isHittable)
    }
}
