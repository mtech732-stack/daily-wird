import XCTest
import UIKit

/// ش6 · المرحلة 1: الوضع الليلي كاملاً (8.2 · 8.3، design/system.md §17.1، ذ45 · ذ46 · ذ49).
/// فحص طلب الدمج نهاريّ (القرار 24)، فيُفرض الليل بـ`-dark`. والألوان تُقرأ من بكسل اللقطة نفسها.
@MainActor
final class NightUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private static let owner = "farReview:1-9;nearReview:10-11;new:12"

    private func launch(dark: Bool = true, counter: Int = 34) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed", Self.owner, "-counter", String(counter),
                               "-readings", "37:0", "-pages", "112-116:3"] + [dark ? "-dark" : "-light"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func wait(_ element: XCUIElement, _ format: String, timeout: TimeInterval = 20) -> Bool {
        let e = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
        return XCTWaiter().wait(for: [e], timeout: timeout) == .completed
    }

    /// لون البكسل في نقطة من الشاشة (بالنقاط)، من لقطة الآن.
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

    private func circle(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "counter.circle").firstMatch
    }

    /// يضغط «ح [رقم]» مطوّلاً حتى تظهر قائمة الحزب، ويعيد الضغط مرة إن لم تظهر (#43).
    private func pressHizb(_ app: XCUIApplication, _ track: String, _ hizb: Int, item: String,
                           file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let label = app.descendants(matching: .any)["hizb.\(track).\(hizb)"]
        XCTAssertTrue(label.waitForExistence(timeout: 20), "لم يظهر ح \(hizb)", file: file, line: line)
        XCTAssertTrue(wait(label, "isHittable == true"), "لا يُضغط ح \(hizb)", file: file, line: line)
        let entry = app.buttons[item]
        label.press(forDuration: 1.0)
        if entry.waitForExistence(timeout: 20) { return entry }
        if label.isHittable { label.press(forDuration: 1.0) }
        XCTAssertTrue(entry.waitForExistence(timeout: 20), "لم يظهر «\(item)» في قائمة ح \(hizb)", file: file, line: line)
        return entry
    }

    /// ذ45: العدّاد ليلاً حلقة لا قرص: داخل الدائرة `card` الليلي #1B3450، وحافّتها `ink` الليلي #F2EDE2.
    /// ونهاراً لا يتغيّر: قرص `ink` #0F3F6E.
    func test_8_2_counterIsRingAtNight() {
        let app = launch()
        let c = circle(app)
        XCTAssertTrue(c.waitForExistence(timeout: 20))
        let f = c.frame
        // يسار المركز بربع القطر: لا رقم فيه ولا «+».
        expectColor(app, at: CGPoint(x: f.minX + f.width * 0.18, y: f.midY), 0x1B3450, "داخل الدائرة ليلاً")
        expectColor(app, at: CGPoint(x: f.minX + 0.75, y: f.midY), 0xF2EDE2, "حلقة الدائرة ليلاً")
        shot(app, "74-night-counter")
        app.terminate()

        let day = launch(dark: false)
        let d = circle(day)
        XCTAssertTrue(d.waitForExistence(timeout: 20))
        let g = d.frame
        expectColor(day, at: CGPoint(x: g.minX + g.width * 0.18, y: g.midY), 0x0F3F6E, "الدائرة نهاراً قرص كما كانت")
    }

    /// ذ46: قائمة الحزب ليلاً `raised` #22405F، أفتح من البطاقة #1B3450 تحتها فلا تذوب فيها.
    func test_8_2_hizbMenuIsRaisedAtNight() {
        let app = launch()
        _ = pressHizb(app, "farReview", 1, item: "hizbmenu.remove")
        let menu = app.descendants(matching: .any)["hizbmenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        let header = app.descendants(matching: .any)["hizbmenu.header"]
        // بين رأس القائمة وحدّها الأيسر: أرضية القائمة لا نصّ.
        let f = menu.frame
        let y = header.exists ? header.frame.midY : f.minY + 18
        expectColor(app, at: CGPoint(x: f.minX + 8, y: y), 0x22405F, "أرضية قائمة الحزب ليلاً")
        shot(app, "75-night-hmenu")
    }

    /// ذ46: الحوار ليلاً `raised` #22405F فوق التعتيم.
    func test_8_2_dialogIsRaisedAtNight() {
        let app = launch()
        pressHizb(app, "farReview", 1, item: "hizbmenu.remove").tap()
        let question = app.staticTexts["remove.question"]
        XCTAssertTrue(question.waitForExistence(timeout: 20), "لم يظهر سؤال الإزالة")
        // الحوار من 28 إلى عرض الشاشة ناقص 28، فبعد حدّه بـ6 أرضيته لا نصّ.
        expectColor(app, at: CGPoint(x: 34, y: question.frame.midY), 0x22405F, "أرضية الحوار ليلاً")
        shot(app, "76-night-remove")
    }

    /// ذ49: والعدّاد كبير يظهر الإشعار في أعلى الشاشة فوق الرأس، لا عند أسفل الدائرة.
    func test_8_2_toastOnTopWithBigCounter() {
        let app = launch()
        let c = circle(app)
        XCTAssertTrue(c.waitForExistence(timeout: 20))
        pressHizb(app, "farReview", 1, item: "hizbmenu.move.nearReview").tap()
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 20))
        XCTAssertLessThan(toast.frame.minY, 110, "الإشعار في أعلى الشاشة")
        XCTAssertLessThan(toast.frame.maxY, c.frame.minY, "الإشعار لا يلامس الدائرة")
        shot(app, "77-night-toast")
    }
}
