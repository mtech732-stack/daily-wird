import Foundation
import SwiftData
import XCTest
@testable import DailyWird

/// ش2 · المرحلة 4: سطر «آخر إدخال» (7.1، 7.1.2، system.md §13.4).
@MainActor
final class LastEntryTests: XCTestCase {

    private let tz = TimeZone(identifier: "Asia/Riyadh")!
    private var cal: Calendar { WirdDate.calendar(timeZone: tz) }
    private func date(_ text: String) -> Date { WirdClock.parse(text, timeZone: tz)! }

    /// 7.1.2: صيغة المدّة بحدودها كلها، و«شهراً» من 11 فما فوق (§13.4).
    func test_7_1_2_relativeDurationTable() {
        let table: [(Int, String)] = [
            (0, "اليوم"), (1, "أمس"), (2, "قبل يومين"), (3, "قبل 3 أيام"), (6, "قبل 6 أيام"),
            (7, "قبل أسبوع"), (13, "قبل أسبوع"), (14, "قبل أسبوعين"), (20, "قبل أسبوعين"),
            (21, "قبل 3 أسابيع"), (29, "قبل 3 أسابيع"), (30, "قبل شهر"), (59, "قبل شهر"),
            (60, "قبل شهرين"), (89, "قبل شهرين"), (90, "قبل 3 أشهر"), (119, "قبل 3 أشهر"),
            (329, "قبل 10 أشهر"), (330, "قبل 11 شهراً"), (420, "قبل 14 شهراً"),
        ]
        for (days, text) in table {
            XCTAssertEqual(LastEntry.relative(days: days), text, "\(days) يوماً")
        }
    }

    /// §13.4: المدّة بالأيام التقويمية: ما ظُلّل أمس في 11 ليلاً «أمس» بعد منتصف الليل بدقائق.
    func test_7_1_2_calendarDays() {
        XCTAssertEqual(LastEntry.title(date("2026-11-09T23:00:00"), now: date("2026-11-10T00:05:00"), calendar: cal),
                       "آخر إدخال أمس")
        XCTAssertEqual(LastEntry.title(date("2026-11-10T00:01:00"), now: date("2026-11-10T23:59:00"), calendar: cal),
                       "آخر إدخال اليوم")
    }

    /// §13.4، القرار 1: ميلادي، واسم اليوم ثم اليوم ثم الشهر، والأرقام إنجليزية، والوقت 12 ساعة.
    /// والسنة لا تُكتب إلا إن خالفت سنة اليوم.
    func test_13_4_dateAndTimeFormat() {
        let now = date("2026-11-09T07:00:00")
        XCTAssertEqual(LastEntry.stamp(date("2026-11-06T05:34:00"), now: now, timeZone: tz), "الجمعة 6 نوفمبر · 5:34 ص")
        XCTAssertEqual(LastEntry.stamp(date("2026-11-06T21:40:00"), now: now, timeZone: tz), "الجمعة 6 نوفمبر · 9:40 م")
        XCTAssertEqual(LastEntry.stamp(date("2025-08-06T12:05:00"), now: now, timeZone: tz), "الأربعاء 6 أغسطس 2025 · 12:05 م")
    }

    /// §13.4: هو أحدث تظليل لأيّ ربع في أحزاب المسار الآن، وما في المسار الآخر لا يدخله.
    func test_13_4_latestInTrackOnly() {
        let readings = [
            QuarterReading(quarter: 2, readAt: date("2026-11-01T05:00:00")),
            QuarterReading(quarter: 3, readAt: date("2026-11-06T05:34:00")),
            QuarterReading(quarter: 3, readAt: date("2026-10-06T05:34:00")),
            QuarterReading(quarter: 40, readAt: date("2026-11-09T06:00:00")),
        ]
        let far = Quran.quarters(ofHizb: 1)
        XCTAssertEqual(LastEntry.latest(in: far, readings: readings), date("2026-11-06T05:34:00"))
        XCTAssertEqual(LastEntry.latest(in: Quran.quarters(ofHizb: 10), readings: readings), date("2026-11-09T06:00:00"))
        // ذ12: قبل أول إدخال في المسار لا سطر.
        XCTAssertNil(LastEntry.latest(in: Quran.quarters(ofHizb: 2), readings: readings))
    }

    /// §13.4: إن نُقل حزب انتقل سجلّه معه، فيتغيّر السطر في المسارين بحسبه.
    func test_13_4_movedHizbTakesItsRecord() {
        let readings = [
            QuarterReading(quarter: 1, readAt: date("2026-11-01T05:00:00"), track: .farReview),
            QuarterReading(quarter: 5, readAt: date("2026-11-08T05:00:00"), track: .farReview),
        ]
        // ح 2 (أرباعه 5–8) نُقل من البعيد إلى القريب.
        let farAfter = Quran.quarters(ofHizb: 1)
        let nearAfter = Quran.quarters(ofHizb: 2) + Quran.quarters(ofHizb: 10)
        XCTAssertEqual(LastEntry.latest(in: farAfter, readings: readings), date("2026-11-01T05:00:00"))
        XCTAssertEqual(LastEntry.latest(in: nearAfter, readings: readings), date("2026-11-08T05:00:00"))
    }

    /// 5.3، §13.2: التراجع يعيد السطر إلى ما قبله، وإن لم يبقَ إدخال لم يبقَ سطر.
    func test_13_4_undoRestoresPreviousEntry() throws {
        let ctx = ModelContext(try Persistence.makeContainer(inMemory: true))
        let earlier = date("2026-11-07T05:34:00")
        ctx.insert(QuarterReading(quarter: 1, readAt: earlier, track: .farReview))
        let now = date("2026-11-10T06:00:00")
        let quarters = Quran.quarters(ofHizb: 1)
        func latest() throws -> Date? { LastEntry.latest(in: quarters, readings: try ctx.fetch(FetchDescriptor<QuarterReading>())) }

        XCTAssertEqual(try Shading.tap(quarter: 2, track: .farReview, in: ctx, now: now, calendar: cal), .shaded)
        XCTAssertEqual(try latest(), now)
        XCTAssertEqual(try Shading.tap(quarter: 2, track: .farReview, in: ctx, now: now, calendar: cal), .undone)
        XCTAssertEqual(try latest(), earlier)

        let fresh = ModelContext(try Persistence.makeContainer(inMemory: true))
        _ = try Shading.tap(quarter: 2, track: .farReview, in: fresh, now: now, calendar: cal)
        _ = try Shading.tap(quarter: 2, track: .farReview, in: fresh, now: now, calendar: cal)
        XCTAssertNil(LastEntry.latest(in: quarters, readings: try fresh.fetch(FetchDescriptor<QuarterReading>())))
    }
}
