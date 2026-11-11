import Foundation
import XCTest
@testable import DailyWird

/// ش5 · المرحلة 1: الدائرة والعدد (5.7، design/system.md §16.1–16.2، §16.7–16.8).
final class CounterTests: XCTestCase {

    /// §16.1: القطر ما بقي بين 76 و136، وأقلّ من 76 صفّ أفقي (ذ44).
    func test_5_7_diameterFromRoom() {
        XCTAssertNil(CounterLayout.diameter(room: 75.9), "أقلّ من 76: صفّ أفقي بدائرة 64")
        XCTAssertNil(CounterLayout.diameter(room: -20))
        XCTAssertEqual(CounterLayout.diameter(room: 76), 76)
        XCTAssertEqual(CounterLayout.diameter(room: 98.7), 98, "s5-fold: 98 على محفوظ المالك")
        XCTAssertEqual(CounterLayout.diameter(room: 136), 136)
        XCTAssertEqual(CounterLayout.diameter(room: 400), 136, "s5-440-fold وs5-empty: لا يزيد عن 136")
        XCTAssertEqual(CounterLayout.small, 64)
    }

    /// ذ39: حتى ثلاث خانات 0.39 من القطر، وأربع 0.31، وخمس فأكثر 0.25.
    func test_5_7_numberSizeByDigits() {
        XCTAssertEqual(CounterLayout.numberRatio(0), 0.39)
        XCTAssertEqual(CounterLayout.numberRatio(33), 0.39)
        XCTAssertEqual(CounterLayout.numberRatio(999), 0.39)
        XCTAssertEqual(CounterLayout.numberRatio(1000), 0.31)
        XCTAssertEqual(CounterLayout.numberRatio(9999), 0.31)
        XCTAssertEqual(CounterLayout.numberRatio(10000), 0.25)
        XCTAssertEqual(CounterLayout.numberRatio(123_456), 0.25)
        // s5-fold: «33» في الدائرة 98 بحجم 38، و«+» 18. والشريط (§6): «33» 24، و«+» 14.
        XCTAssertEqual(CounterLayout.numberSize(count: 33, diameter: 98, isBar: false), 38)
        XCTAssertEqual(CounterLayout.plusSize(diameter: 98, isBar: false), 18)
        XCTAssertEqual(CounterLayout.numberSize(count: 33, diameter: 64, isBar: true), 24)
        XCTAssertEqual(CounterLayout.plusSize(diameter: 64, isBar: true), 14)
        // s5-d5: «12500» في الدائرة 98 بحجم 25 (0.25).
        XCTAssertEqual(CounterLayout.numberSize(count: 12500, diameter: 98, isBar: false), 25)
    }

    /// ذ39: أرقام إنجليزية بلا فاصل آلاف.
    func test_5_7_numberWithoutGrouping() {
        XCTAssertEqual(CounterLayout.text(1250), "1250")
        XCTAssertEqual(CounterLayout.text(12500), "12500")
        XCTAssertEqual(CounterLayout.text(0), "0")
    }

    /// §16.8 والقرار 10: العدد في UserDefaults وحده، لا نموذج له في SwiftData ولا في SchemaV1.
    func test_5_7_countOutsideSwiftData() {
        XCTAssertEqual(CounterStore.key, "counter.count")
        let names = SchemaV1.models.map { String(describing: $0) }
        XCTAssertEqual(names.count, 4, "\(names)")
        XCTAssertFalse(names.contains { $0.localizedCaseInsensitiveContains("count") }, "\(names)")
    }

    /// اختبارات الواجهة تبدأ بعدد معلوم، و`-keep-counter` يُبقي المحفوظ لاختبار الحفظ.
    func test_5_7_uiTestingStart() throws {
        let suite = "counter.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(7, forKey: CounterStore.key)
        CounterStore.prepareForUITesting(["app"], defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: CounterStore.key), 7, "خارج اختبارات الواجهة لا يُمسّ")
        CounterStore.prepareForUITesting(["-ui-testing", "-keep-counter"], defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: CounterStore.key), 7)
        CounterStore.prepareForUITesting(["-ui-testing", "-counter", "9999"], defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: CounterStore.key), 9999)
        CounterStore.prepareForUITesting(["-ui-testing"], defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: CounterStore.key), 0)
    }
}
