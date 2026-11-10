import Foundation
import SwiftData
import XCTest
@testable import DailyWird

/// ش2 · المرحلة 3: درجات العمر الخمس (5.4، القرار 14، system.md §13.3).
@MainActor
final class AgeTests: XCTestCase {

    private let tz = TimeZone(identifier: "Asia/Riyadh")!
    private var cal: Calendar { WirdDate.calendar(timeZone: tz) }
    private func date(_ text: String) -> Date { WirdClock.parse(text, timeZone: tz)! }

    /// 5.4، القرار 14: الحدود شاملة: 0–7 ممتلئ · 8–15 نصف · 16–22 ربع · 23 فأكثر مخطّط · لا تظليل فارغ.
    func test_5_4_fiveLevelsInclusiveThresholds() {
        let expected: [(Int?, AgeLevel)] = [
            (0, .full), (7, .full), (8, .half), (15, .half), (16, .quarter), (22, .quarter),
            (23, .faded), (400, .faded), (nil, .empty),
        ]
        for (days, level) in expected {
            XCTAssertEqual(AgeLevel.from(days: days), level, "\(String(describing: days)) يوماً")
        }
    }

    /// §13.3: العمر بالأيام التقويمية لا بالساعات: ما ظُلّل أمس في 11 ليلاً عمره يوم واحد صباح اليوم،
    /// وما ظُلّل قبل ثمانية أيام في 11:59 م يصير نصفاً عند 12:00 ص لا قبلها.
    func test_5_4_calendarDaysNotHours() {
        XCTAssertEqual(Age.days(from: date("2026-11-09T23:00:00"), to: date("2026-11-10T06:00:00"), calendar: cal), 1)
        XCTAssertEqual(Age.days(from: date("2026-11-10T00:00:00"), to: date("2026-11-10T23:59:59"), calendar: cal), 0)
        let read = [QuarterReading(quarter: 1, readAt: date("2026-11-02T23:59:00"))]
        XCTAssertEqual(Age.levels(read, now: date("2026-11-09T23:59:59"), calendar: cal)[1], .full, "اليوم السابع")
        XCTAssertEqual(Age.levels(read, now: date("2026-11-10T00:00:00"), calendar: cal)[1], .half, "اليوم الثامن")
    }

    /// 5.4: الدرجة تتغيّر وحدها مع مرور الأيام، بلا إدخال من المالك.
    func test_5_4_levelChangesByItself() {
        let read = [QuarterReading(quarter: 5, readAt: date("2026-10-01T09:00:00"))]
        let seq = ["2026-10-01T10:00:00": AgeLevel.full, "2026-10-12T10:00:00": .half,
                   "2026-10-20T10:00:00": .quarter, "2026-10-24T10:00:00": .faded]
        for (now, level) in seq {
            XCTAssertEqual(Age.levels(read, now: date(now), calendar: cal)[5], level, now)
        }
        XCTAssertNil(Age.levels(read, now: date("2026-10-24T10:00:00"), calendar: cal)[6], "ما لا تظليل له «لم يُتلَ»")
    }

    /// 5.4: الدرجة من آخر تظليل، وتعود ممتلئة إذا ظُلّل الربع من جديد.
    func test_5_4_latestReadingCountsAndRefills() {
        let list = [
            QuarterReading(quarter: 2, readAt: date("2026-10-01T09:00:00")),
            QuarterReading(quarter: 2, readAt: date("2026-11-08T09:00:00")),
            QuarterReading(quarter: 2, readAt: date("2026-09-01T09:00:00")),
        ]
        XCTAssertEqual(Age.lastRead(list)[2], date("2026-11-08T09:00:00"))
        XCTAssertEqual(Age.levels(list, now: date("2026-11-10T09:00:00"), calendar: cal)[2], .full)
    }

    /// 5.3، 5.4: التراجع يعيد الربع إلى عمره السابق (قبل عشرة أيام: نصف)، لا إلى «لم يُتلَ».
    func test_5_4_undoRestoresPreviousAge() throws {
        let ctx = ModelContext(try Persistence.makeContainer(inMemory: true))
        let now = date("2026-11-10T09:00:00")
        try Shading.tap(quarter: 4, track: .farReview, in: ctx, now: date("2026-10-31T09:00:00"), calendar: cal)
        try Shading.tap(quarter: 4, track: .farReview, in: ctx, now: now, calendar: cal)
        XCTAssertEqual(Age.levels(try ctx.fetch(FetchDescriptor<QuarterReading>()), now: now, calendar: cal)[4], .full)
        try Shading.tap(quarter: 4, track: .farReview, in: ctx, now: now.addingTimeInterval(30), calendar: cal)
        XCTAssertEqual(Age.levels(try ctx.fetch(FetchDescriptor<QuarterReading>()), now: now, calendar: cal)[4], .half)
    }

    /// 7.1.3، ذ15: معاني الدرجات بالأيام كما في المفاتيح.
    func test_5_4_meanings() {
        XCTAssertEqual(AgeLevel.allCases.map(\.meaning),
                       ["خلال 7 أيام", "خلال 15 يوماً", "خلال 22 يوماً", "أكثر من 22 يوماً", "لم يُتلَ"])
    }
}
