import Foundation
import SwiftData
import XCTest
@testable import DailyWird

/// ش3 · المرحلة 1: الدورة وموضع التوقّف في القريب والبعيد (5.5، design/system.md §14.1–14.2).
@MainActor
final class CycleTests: XCTestCase {

    private let tz = TimeZone(identifier: "Asia/Riyadh")!
    private var cal: Calendar { WirdDate.calendar(timeZone: tz) }
    private func date(_ text: String) -> Date { WirdClock.parse(text, timeZone: tz)! }
    private func context() throws -> ModelContext { ModelContext(try Persistence.makeContainer(inMemory: true)) }

    private func layout(_ ctx: ModelContext, _ track: Track) throws -> ReviewTrackLayout {
        let placements = try ctx.fetch(FetchDescriptor<HizbPlacement>())
        let readings = try ctx.fetch(FetchDescriptor<QuarterReading>())
        let cycles = try ctx.fetch(FetchDescriptor<ReviewCycle>())
        let hizbs = Library.activeHizbs(in: track, from: placements)
        return ReviewTrackLayout(track: track, hizbs: hizbs,
                                 done: Cycles.done(quarters: hizbs.flatMap(Quran.quarters(ofHizb:)), readings: readings,
                                                   since: Cycles.current(track, in: cycles)?.startedAt))
    }

    /// 5.5: تبدأ الدورة حين يُضاف أول حزب إلى المسار، ولا تبدأ دورة ثانية بإضافة أخرى.
    func test_5_5_cycleStartsWithFirstHizb() throws {
        let ctx = try context()
        try Library.add([1, 2], to: .farReview, in: ctx, now: date("2026-11-01T08:00:00"))
        try Library.add([3], to: .farReview, in: ctx, now: date("2026-11-02T08:00:00"))
        let cycles = try ctx.fetch(FetchDescriptor<ReviewCycle>())
        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(cycles[0].track, .farReview)
        XCTAssertEqual(cycles[0].startedAt, date("2026-11-01T08:00:00"))
        XCTAssertNil(cycles[0].endedAt)
    }

    /// النقل إلى مسار فارغ يبدأ دورته.
    func test_5_5_moveStartsTargetCycle() throws {
        let ctx = try context()
        try Library.add([1, 2], to: .farReview, in: ctx, now: date("2026-11-01T08:00:00"))
        try Library.move([2], from: .farReview, to: .nearReview, in: ctx, now: date("2026-11-03T08:00:00"))
        let cycles = try ctx.fetch(FetchDescriptor<ReviewCycle>())
        XCTAssertEqual(Cycles.current(.nearReview, in: cycles)?.startedAt, date("2026-11-03T08:00:00"))
    }

    /// بيانات ما قبل ش3: أحزاب بلا دورة تبدأ دورتها من أقدم إضافة، ولا تتكرّر.
    func test_5_5_ensureStartsMissingCycles() throws {
        let ctx = try context()
        ctx.insert(HizbPlacement(hizb: 5, track: .nearReview, addedAt: date("2026-10-20T10:00:00")))
        ctx.insert(HizbPlacement(hizb: 4, track: .nearReview, addedAt: date("2026-10-10T10:00:00")))
        try ctx.save()
        XCTAssertEqual(try Cycles.ensure(in: ctx), [.nearReview])
        XCTAssertEqual(try Cycles.ensure(in: ctx), [])
        let cycles = try ctx.fetch(FetchDescriptor<ReviewCycle>())
        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(cycles[0].startedAt, date("2026-10-10T10:00:00"))
    }

    /// §14.1–14.2: التقدّم ما ظُلّل في الدورة، وما قبلها لا يُعدّ؛ والموضع أول ربع لم يُظلَّل فيها
    /// بترتيب الأرقام، ولو ظُلّل ما بعده (التخطّي).
    func test_14_progressAndBookmarkFromCycle() throws {
        let ctx = try context()
        try Library.add(Array(1...9), to: .farReview, in: ctx, now: date("2026-11-01T08:00:00"))
        // قبل الدورة: لا يُعدّ.
        ctx.insert(QuarterReading(quarter: 1, readAt: date("2026-10-30T08:00:00")))
        for q in 2...22 { ctx.insert(QuarterReading(quarter: q, readAt: date("2026-11-05T08:00:00"))) }
        ctx.insert(QuarterReading(quarter: 24, readAt: date("2026-11-05T08:00:00")))
        try ctx.save()
        var far = try layout(ctx, .farReview)
        XCTAssertEqual(far.bookmarkQuarter, 1, "ما ظُلّل قبل الدورة لا يُعدّ فيها")
        XCTAssertEqual(far.progressText, "22 من 36")
        ctx.insert(QuarterReading(quarter: 1, readAt: date("2026-11-06T08:00:00")))
        try ctx.save()
        far = try layout(ctx, .farReview)
        XCTAssertEqual(far.bookmarkQuarter, 23, "التخطّي: ح6 الربع 3 والربع 4 مظلّل")
        XCTAssertEqual(far.bookmarkHizb, 6)
        XCTAssertEqual(far.foldedRow?.hizb, 6)
        XCTAssertEqual(far.progressText, "23 من 36")
    }

    /// الربع يُعدّ مرة واحدة ولو ظُلّل في أيام كثيرة من الدورة.
    func test_14_1_quarterCountsOnce() throws {
        let ctx = try context()
        try Library.add([10, 11], to: .nearReview, in: ctx, now: date("2026-11-01T08:00:00"))
        ctx.insert(QuarterReading(quarter: 37, readAt: date("2026-11-02T08:00:00")))
        ctx.insert(QuarterReading(quarter: 37, readAt: date("2026-11-03T08:00:00")))
        try ctx.save()
        let near = try layout(ctx, .nearReview)
        XCTAssertEqual(near.progressText, "1 من 8")
        XCTAssertEqual(near.bookmarkQuarter, 38)
    }

    /// الصفّ المطويّ لحزب بعينه (مهلة §14.3) لا يكون لحزب ليس في المسار.
    func test_14_3_foldedRowForPinnedHizb() {
        let far = ReviewTrackLayout(track: .farReview, hizbs: [6, 7], done: Set(21...24))
        XCTAssertEqual(far.bookmarkHizb, 7)
        XCTAssertEqual(far.foldedRow(hizb: 6)?.hizb, 6)
        XCTAssertNil(far.foldedRow(hizb: 8))
    }

    /// تظليل كل الأرباع: الموضع يعود إلى أول المسار (والاكتمال في المرحلة 3).
    func test_14_2_allDoneBookmarkFirst() {
        let near = ReviewTrackLayout(track: .nearReview, hizbs: [10], done: Set(37...40))
        XCTAssertEqual(near.bookmarkQuarter, 37)
        XCTAssertEqual(near.progressText, "4 من 4")
    }
}
