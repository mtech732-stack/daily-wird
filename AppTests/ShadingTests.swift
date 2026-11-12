import Foundation
import SwiftData
import XCTest
@testable import DailyWird

/// ش2 · المرحلتان 1 و2: التظليل بالتاريخ وعلامة «اليوم»، والتراجع (5.3، §13.1، §13.2).
@MainActor
final class ShadingTests: XCTestCase {

    /// توقيت ثابت للاختبار (الرياض)، فلا تتغيّر النتائج بتوقيت جهاز الاختبار.
    private let tz = TimeZone(identifier: "Asia/Riyadh")!
    private var cal: Calendar { WirdDate.calendar(timeZone: tz) }

    private func context() throws -> ModelContext {
        ModelContext(try Persistence.makeContainer(inMemory: true))
    }

    private func date(_ text: String) -> Date { WirdClock.parse(text, timeZone: tz)! }

    private func readings(_ ctx: ModelContext) throws -> [QuarterReading] {
        try ctx.fetch(FetchDescriptor<QuarterReading>())
    }

    /// 5.3: ضغطة على الربع = تلوته اليوم: تظليل واحد بتاريخه ووقته كاملين، والمسار للتاريخ وحده.
    func test_5_3_tapRecordsReadingWithDateAndTime() throws {
        let ctx = try context()
        let at = date("2026-11-06T05:34:12")
        XCTAssertEqual(try Shading.tap(quarter: 2, track: .farReview, in: ctx, now: at, calendar: cal), .shaded)
        let all = try readings(ctx)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].quarter, 2)
        XCTAssertEqual(all[0].readAt, at, "التاريخ والوقت كما هما، بالثانية")
        XCTAssertEqual(all[0].trackRaw, Track.farReview.rawValue)
    }

    /// 5.3: لا يُظلَّل الربع مرتين في اليوم الواحد: الضغطة الثانية في اليوم نفسه تراجع لا تظليل.
    func test_5_3_noSecondShadingSameDay() throws {
        let ctx = try context()
        try Shading.tap(quarter: 7, track: .nearReview, in: ctx, now: date("2026-11-06T00:00:00"), calendar: cal)
        XCTAssertEqual(try Shading.tap(quarter: 7, track: .nearReview, in: ctx, now: date("2026-11-06T23:59:59"), calendar: cal),
                       .undone)
        XCTAssertEqual(try readings(ctx).count, 0)
    }

    /// 5.3: التراجع يحذف تظليل اليوم وحده، فيعود الربع إلى عمره السابق، ولا يُمسّ ما قبله.
    func test_5_3_undoRemovesTodayOnly() throws {
        let ctx = try context()
        let before = date("2026-11-03T09:00:00")
        try Shading.tap(quarter: 5, track: .farReview, in: ctx, now: before, calendar: cal)
        try Shading.tap(quarter: 6, track: .farReview, in: ctx, now: date("2026-11-06T05:00:00"), calendar: cal)
        try Shading.tap(quarter: 5, track: .farReview, in: ctx, now: date("2026-11-06T05:34:00"), calendar: cal)
        XCTAssertEqual(try Shading.tap(quarter: 5, track: .farReview, in: ctx, now: date("2026-11-06T05:35:00"), calendar: cal), .undone)
        let all = try readings(ctx)
        XCTAssertEqual(all.filter { $0.quarter == 5 }.map(\.readAt), [before], "تظليل ما قبل اليوم باقٍ")
        XCTAssertEqual(all.filter { $0.quarter == 6 }.count, 1, "التراجع عن ربع لا يمسّ غيره")
        XCTAssertEqual(Shading.readToday(all, now: date("2026-11-06T05:36:00"), calendar: cal), [6])
    }

    /// 5.3: بعد التراجع تظلّله الضغطة من جديد بوقتها الجديد.
    func test_5_3_tapAfterUndoShadesAgain() throws {
        let ctx = try context()
        try Shading.tap(quarter: 9, track: .farReview, in: ctx, now: date("2026-11-06T05:00:00"), calendar: cal)
        try Shading.tap(quarter: 9, track: .farReview, in: ctx, now: date("2026-11-06T05:01:00"), calendar: cal)
        let again = date("2026-11-06T05:02:00")
        XCTAssertEqual(try Shading.tap(quarter: 9, track: .farReview, in: ctx, now: again, calendar: cal), .shaded)
        XCTAssertEqual(try readings(ctx).map(\.readAt), [again])
    }

    /// 5.3: تظليل الأمس لا يُتراجع عنه بضغطة اليوم؛ الضغطة بعد منتصف الليل تظليل جديد.
    func test_5_3_noUndoOfYesterday() throws {
        let ctx = try context()
        try Shading.tap(quarter: 3, track: .farReview, in: ctx, now: date("2026-11-06T23:50:00"), calendar: cal)
        XCTAssertEqual(try Shading.tap(quarter: 3, track: .farReview, in: ctx, now: date("2026-11-07T00:10:00"), calendar: cal), .shaded)
        XCTAssertEqual(try readings(ctx).count, 2)
    }

    /// 5.3، القرار 2: اليوم يبدأ عند منتصف الليل بتوقيت الجهاز: تظليل 11:59 م ليس من «اليوم» بعد 12:00 ص،
    /// والضغطة بعد منتصف الليل تظليل جديد لا تكرار.
    func test_5_3_dayStartsAtMidnight() throws {
        let ctx = try context()
        try Shading.tap(quarter: 1, track: .farReview, in: ctx, now: date("2026-11-06T23:59:00"), calendar: cal)
        let all = try readings(ctx)
        XCTAssertEqual(Shading.readToday(all, now: date("2026-11-06T23:59:59"), calendar: cal), [1])
        XCTAssertEqual(Shading.readToday(all, now: date("2026-11-07T00:00:00"), calendar: cal), [])
        XCTAssertEqual(try Shading.tap(quarter: 1, track: .farReview, in: ctx, now: date("2026-11-07T00:01:00"), calendar: cal), .shaded)
        XCTAssertEqual(try readings(ctx).count, 2, "تظليل كل يوم باقٍ في السجلّ")
    }

    /// 5.3: علامة «اليوم» على ما ظُلّل اليوم وحده، لا على ما ظُلّل قبله.
    func test_5_3_todayMarkOnlyOnTodaysReadings() {
        let now = date("2026-11-10T09:00:00")
        let list = [
            QuarterReading(quarter: 1, readAt: date("2026-11-10T00:00:00")),
            QuarterReading(quarter: 2, readAt: date("2026-11-09T23:59:59")),
            QuarterReading(quarter: 3, readAt: date("2026-11-03T09:00:00")),
            QuarterReading(quarter: 4, readAt: date("2026-11-10T08:59:00")),
        ]
        XCTAssertEqual(Shading.readToday(list, now: now, calendar: cal), [1, 4])
    }

    /// 7.1.1، 3: الربع المشترك ربع واحد في السجلّ: يظهر في قسمين، وتظليله في أحدهما يظلّله في الآخر.
    func test_5_3_sharedQuarterIsOneRecord() throws {
        let ctx = try context()
        let layout = ReviewTrackLayout(track: .farReview, hizbs: [5])
        // ح 5 الربع 4 (الربع 20) بين البقرة وآل عمران.
        XCTAssertTrue(layout.sharedQuarters.contains(20))
        let places = layout.sections.flatMap { s in s.rows.flatMap { $0.slots.compactMap { $0 } } }.filter { $0 == 20 }
        XCTAssertEqual(places.count, 2, "يظهر في الموضعين")
        let now = date("2026-11-10T09:00:00")
        try Shading.tap(quarter: 20, track: .farReview, in: ctx, now: now, calendar: cal)
        XCTAssertEqual(Shading.readToday(try readings(ctx), now: now, calendar: cal), [20])
        XCTAssertEqual(try Shading.tap(quarter: 20, track: .farReview, in: ctx, now: now, calendar: cal), .undone,
                       "الضغطة في الموضع الآخر تراجع عن الربع نفسه، لا تظليل ثانٍ")
        XCTAssertEqual(try readings(ctx).count, 0)
    }

    /// 5.2، 5.3: التظليل بالربع لا بالمسار: ينتقل الحزب فتبقى علامة «اليوم» على ربعه.
    func test_5_3_readingFollowsQuarterAcrossMove() throws {
        let ctx = try context()
        let now = date("2026-11-10T09:00:00")
        try Library.add([10], to: .nearReview, in: ctx, now: now)
        try Shading.tap(quarter: 38, track: .nearReview, in: ctx, now: now, calendar: cal)
        try Library.move([10], from: .nearReview, to: .farReview, in: ctx, now: now.addingTimeInterval(60))
        XCTAssertEqual(Shading.readToday(try readings(ctx), now: now.addingTimeInterval(120), calendar: cal), [38])
        XCTAssertEqual(try readings(ctx).count, 1, "النقل لا يمسّ السجلّ")
    }

    /// §13.2: الشاشة تتحدّث عند منتصف الليل التالي بتوقيت الجهاز.
    func test_5_3_nextMidnight() {
        XCTAssertEqual(Shading.nextMidnight(after: date("2026-11-06T23:59:50"), calendar: cal), date("2026-11-07T00:00:00"))
        XCTAssertEqual(Shading.nextMidnight(after: date("2026-11-07T00:00:00"), calendar: cal), date("2026-11-08T00:00:00"))
    }

    /// ساعة الاختبار: تبدأ من الوقت المثبّت في اختبارات الواجهة وحدها، ولا تمسّ ساعة المالك.
    func test_uiTestClockOnlyWhenTesting() {
        let real = date("2026-11-10T09:00:00")
        XCTAssertEqual(WirdClock.offset(from: ["-now", "2026-11-06T23:59:50"], realNow: real, timeZone: tz), 0)
        XCTAssertEqual(WirdClock.offset(from: ["-ui-testing", "-now", "2026-11-10T08:00:00"], realNow: real, timeZone: tz), -3600)
    }

    /// بذرة اختبارات الواجهة: «1:0,5:3@23:30».
    func test_uiTestSeedReadings() {
        let list = UITestSeed.parseReadings("1:0,5:3@23:30,999:1,x")
        XCTAssertEqual(list, [UITestSeed.Reading(quarter: 1, daysAgo: 0),
                              UITestSeed.Reading(quarter: 5, daysAgo: 3, hour: 23, minute: 30)])
        let now = date("2026-11-10T09:00:00")
        XCTAssertEqual(UITestSeed.date(of: list[1], now: now, calendar: cal), date("2026-11-07T23:30:00"))
        // «اليوم» قبل دقيقة لا يسبق بداية اليوم، فلا يقع في الأمس قبل بداية دورة بدأت اليوم.
        XCTAssertEqual(UITestSeed.date(of: list[0], now: now, calendar: cal), date("2026-11-10T08:59:00"))
        let justAfterMidnight = date("2026-11-10T00:00:30")
        XCTAssertEqual(UITestSeed.date(of: list[0], now: justAfterMidnight, calendar: cal), date("2026-11-10T00:00:00"))
    }

    /// §14: ما أُخفي في ش2 (ذ10، ذ16) يظهر في ش3: تقدّم الدورة وعلامة موضع التوقّف.
    func test_s3_cycleProgressAndBookmarkShown() {
        XCTAssertTrue(Slice.showsCycleProgress)
        XCTAssertTrue(Slice.showsBookmark)
    }
}
