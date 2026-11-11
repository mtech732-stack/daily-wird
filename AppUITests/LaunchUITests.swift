import XCTest
import UIKit

/// ش6 · المرحلة 4: شاشة البداية (8.3، design/system.md §17.2، ذ47). النظام يعرضها لحظة قبل التطبيق،
/// فتُعرض هنا من `LaunchScreen.storyboard` نفسه بـ`-launch-preview`، ويُقرأ لونها من بكسل اللقطة.
@MainActor
final class LaunchUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(dark: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-launch-preview"] + (dark ? ["-dark"] : [])
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
        XCTAssertTrue(near, "\(what): \(c) والمطلوب #\(String(hex, radix: 16, uppercase: true))", file: file, line: line)
    }

    /// يفحص الأرضية، والمسطرة العليا للشريط، والعلامة على 68% من العرض، وما يسارها.
    private func check(_ app: XCUIApplication, paper: Int, gilt: Int) {
        XCTAssertTrue(app.descendants(matching: .any)["launch.preview"].waitForExistence(timeout: 20)
                      || app.windows.firstMatch.waitForExistence(timeout: 20))
        let w = app.frame.width, h = app.frame.height
        expectColor(app, at: CGPoint(x: 20, y: 160), paper, "الأرضية")
        expectColor(app, at: CGPoint(x: 60, y: h / 2 - 42.5 + 1.8), gilt, "المسطرة الغليظة فوق الشريط")
        expectColor(app, at: CGPoint(x: w * 0.68, y: 160), gilt, "العلامة على 68% من العرض")
        expectColor(app, at: CGPoint(x: w * 0.5, y: 160), paper, "لا شيء يسار العلامة فوق الشريط")
        expectColor(app, at: CGPoint(x: w * 0.68, y: h / 2 + 42.5 + 60), paper, "العلامة تنتهي بعد الشريط بنحو 38")
    }

    /// ذ47: الشريط والعلامة على `paper`، بلا نصّ.
    func test_8_3_launchScreenLight() {
        let app = launch(dark: false)
        check(app, paper: 0xF7F4EC, gilt: 0xDF8C16)
        XCTAssertEqual(app.staticTexts.count, 0, "لا نصّ في شاشة البداية")
        shot(app, "87-launch")
    }

    /// §17.2 ليلاً: الأرضية #13283E، والذهبي #E39A33.
    func test_8_3_launchScreenDark() {
        let app = launch(dark: true)
        check(app, paper: 0x13283E, gilt: 0xE39A33)
        shot(app, "88-launch-dark")
    }
}
