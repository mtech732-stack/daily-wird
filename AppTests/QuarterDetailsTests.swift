import Foundation
import XCTest
@testable import DailyWird

/// ش2 · المرحلة 6: تفاصيل الربع (7.3، 5.4، system.md §13.5).
@MainActor
final class QuarterDetailsTests: XCTestCase {

    private let tz = TimeZone(identifier: "Asia/Riyadh")!
    private var cal: Calendar { WirdDate.calendar(timeZone: tz) }
    private func date(_ text: String) -> Date { WirdClock.parse(text, timeZone: tz)! }

    /// 7.3، ذ13: المدى من أول آية إلى آخرها، وفي سورة واحدة لا يتكرّر اسمها.
    func test_7_3_range() {
        XCTAssertEqual(QuarterDetails.range(20), "من البقرة 283 إلى آل عمران 14")
        XCTAssertEqual(QuarterDetails.range(1), "من الفاتحة 1 إلى البقرة 25")
        XCTAssertEqual(QuarterDetails.range(2), "من البقرة 26 إلى 43")
    }

    /// 7.3: السور التي يضمّها، والأوجه التي يمسّها.
    func test_7_3_surasAndPages() {
        XCTAssertEqual(QuarterDetails.suras(20), "البقرة · آل عمران")
        XCTAssertEqual(QuarterDetails.suras(21), "آل عمران")
        XCTAssertEqual(QuarterDetails.pages(20), "49 · 50 · 51")
        XCTAssertEqual(QuarterDetails.pages(1), "1 · 2 · 3 · 4 · 5")
    }

    /// 7.3: السجلّ كله لعدد مرات التلاوة، الأحدث أولاً، وما لغير الربع لا يدخله.
    func test_7_3_historyAndCount() {
        let readings = [
            QuarterReading(quarter: 5, readAt: date("2026-10-01T05:00:00")),
            QuarterReading(quarter: 5, readAt: date("2026-11-08T05:00:00")),
            QuarterReading(quarter: 6, readAt: date("2026-11-09T05:00:00")),
            QuarterReading(quarter: 5, readAt: date("2026-09-01T05:00:00")),
        ]
        XCTAssertEqual(QuarterDetails.history(5, readings: readings),
                       [date("2026-11-08T05:00:00"), date("2026-10-01T05:00:00"), date("2026-09-01T05:00:00")])
        XCTAssertTrue(QuarterDetails.history(7, readings: readings).isEmpty, "لم يُتلَ: «مرات التلاوة 0»")
    }

    /// §13.5: آخر التواريخ حتى خمسة، الأحدث أولاً، وتظليل اليوم «اليوم»، والسنة إن خالفت سنة اليوم.
    func test_13_5_chips() {
        let now = date("2026-11-09T07:00:00")
        let history = [
            date("2026-11-09T05:12:00"), date("2026-11-06T05:34:00"), date("2026-10-20T05:00:00"),
            date("2026-09-01T05:00:00"), date("2025-12-30T05:00:00"), date("2025-11-01T05:00:00"),
        ]
        let chips = QuarterDetails.chips(history, now: now, calendar: cal)
        XCTAssertEqual(chips.map(\.text), ["اليوم", "6 نوفمبر", "20 أكتوبر", "1 سبتمبر", "30 ديسمبر 2025"])
        XCTAssertEqual(chips.map(\.isToday), [true, false, false, false, false])
        XCTAssertTrue(QuarterDetails.chips([], now: now, calendar: cal).isEmpty, "«لا تواريخ بعد»")
    }
}
