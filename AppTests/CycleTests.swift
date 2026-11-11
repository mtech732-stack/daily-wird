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

    // MARK: المرحلة 3: اكتمال الدورة و«ابدأ دورة جديدة» (§14.4، §14.5)

    private func cycles(_ ctx: ModelContext) throws -> [ReviewCycle] { try ctx.fetch(FetchDescriptor<ReviewCycle>()) }

    /// §14.4: تظليل آخر ربع يتمّ الدورة، وتبدأ غيرها من لحظته؛ والتظليل الذي أتمّها لا يُعدّ في الجديدة (م41).
    /// والأيام من يوم البداية إلى يوم الاكتمال محسوبين معاً (ذ23)، وسطر الاكتمال حتى أول تظليل في الجديدة.
    func test_14_4_completionStartsNewCycle() throws {
        let ctx = try context()
        try Library.add([10], to: .nearReview, in: ctx, now: date("2026-10-23T08:00:00"))
        for q in 37...39 { _ = try Cycles.tap(quarter: q, track: .nearReview, in: ctx, now: date("2026-11-05T08:00:00"), calendar: cal) }
        let at = date("2026-11-10T09:30:00")
        let (result, changes) = try Cycles.tap(quarter: 40, track: .nearReview, in: ctx, now: at, calendar: cal)
        XCTAssertEqual(result, .shaded)
        XCTAssertEqual(changes[.nearReview], .completed(days: 19))
        let all = try cycles(ctx)
        XCTAssertEqual(all.count, 2)
        let old = try XCTUnwrap(all.first { $0.endedAt != nil })
        XCTAssertEqual(old.endReasonRaw, CycleEnd.completed.rawValue)
        XCTAssertEqual(old.endedAt, at)
        XCTAssertEqual(Cycles.current(.nearReview, in: all)?.startedAt, at)
        let near = try layout(ctx, .nearReview)
        XCTAssertEqual(near.progressText, "0 من 4", "التظليل الذي أتمّها للمنتهية وحدها (م41)")
        XCTAssertEqual(near.bookmarkQuarter, 37)
        let readings = try ctx.fetch(FetchDescriptor<QuarterReading>())
        XCTAssertEqual(Cycles.completedDays(.nearReview, quarters: near.quarters, cycles: all, readings: readings,
                                            now: date("2026-11-10T20:00:00"), calendar: cal), 19)
        XCTAssertNil(Cycles.completedDays(.nearReview, quarters: near.quarters, cycles: all, readings: readings,
                                          now: date("2026-11-11T00:00:01"), calendar: cal), "يذهب بمنتصف الليل")
        // أول تظليل في الجديدة يُذهب السطر، والتقدّم «1 من 4».
        _ = try Cycles.tap(quarter: 37, track: .nearReview, in: ctx, now: date("2026-11-10T10:00:00"), calendar: cal)
        XCTAssertEqual(try layout(ctx, .nearReview).progressText, "1 من 4")
        XCTAssertNil(Cycles.completedDays(.nearReview, quarters: near.quarters, cycles: try cycles(ctx),
                                          readings: try ctx.fetch(FetchDescriptor<QuarterReading>()),
                                          now: date("2026-11-10T20:00:00"), calendar: cal))
    }

    /// ذ23: ما بدأ واكتمل اليوم «يوم واحد»، وصيغ العدد.
    func test_14_4_daysPhrase() {
        XCTAssertEqual(Cycles.days(from: date("2026-11-10T01:00:00"), to: date("2026-11-10T23:00:00"), calendar: cal), 1)
        XCTAssertEqual(Cycles.days(from: date("2026-11-09T23:00:00"), to: date("2026-11-10T01:00:00"), calendar: cal), 2)
        XCTAssertEqual(Phrase.days(1), "يوم واحد")
        XCTAssertEqual(Phrase.days(2), "يومان")
        XCTAssertEqual(Phrase.days(3), "3 أيام")
        XCTAssertEqual(Phrase.days(10), "10 أيام")
        XCTAssertEqual(Phrase.days(11), "11 يوماً")
        XCTAssertEqual(Phrase.days(19), "19 يوماً")
    }

    /// §14.4: التراجع في يوم الاكتمال عن تظليل في الدورة المكتملة يعيدها كما كانت، وما ظُلّل بعد
    /// الاكتمال يبقى ويُعدّ فيها. والتراجع عن تظليل في الجديدة لا يعيدها.
    func test_14_4_undoOnCompletionDayRestores() throws {
        let ctx = try context()
        try Library.add([10], to: .nearReview, in: ctx, now: date("2026-11-01T08:00:00"))
        for q in 37...39 { _ = try Cycles.tap(quarter: q, track: .nearReview, in: ctx, now: date("2026-11-05T08:00:00"), calendar: cal) }
        _ = try Cycles.tap(quarter: 40, track: .nearReview, in: ctx, now: date("2026-11-10T09:00:00"), calendar: cal)
        // ظُلّل بعد الاكتمال ثم تراجع عنه: تراجع في الجديدة، فلا استعادة.
        _ = try Cycles.tap(quarter: 37, track: .nearReview, in: ctx, now: date("2026-11-10T09:05:00"), calendar: cal)
        var (result, changes) = try Cycles.tap(quarter: 37, track: .nearReview, in: ctx, now: date("2026-11-10T09:06:00"), calendar: cal)
        XCTAssertEqual(result, .undone)
        XCTAssertEqual(changes[.nearReview], Cycles.Change.none)
        XCTAssertEqual(try cycles(ctx).count, 2)
        // ثم ظُلّل 38 في الجديدة، وتراجع عن 40 الذي أتمّها: تعود المكتملة، و38 يُعدّ فيها.
        _ = try Cycles.tap(quarter: 38, track: .nearReview, in: ctx, now: date("2026-11-10T09:10:00"), calendar: cal)
        (result, changes) = try Cycles.tap(quarter: 40, track: .nearReview, in: ctx, now: date("2026-11-10T09:20:00"), calendar: cal)
        XCTAssertEqual(result, .undone)
        XCTAssertEqual(changes[.nearReview], .restored)
        let all = try cycles(ctx)
        XCTAssertEqual(all.count, 1)
        XCTAssertNil(all[0].endedAt)
        XCTAssertNil(all[0].endReasonRaw)
        let near = try layout(ctx, .nearReview)
        XCTAssertEqual(near.bookmarkQuarter, 40)
        XCTAssertEqual(near.progressText, "3 من 4")
        XCTAssertNil(near.completedDays)
    }

    /// §14.4 (s3-complete-small، م39): حزب واحد تُليت أرباعه اليوم: بعد الاكتمال الإطار على الربع 1
    /// وعليه علامة «اليوم»، وضغطه تراجع لا تظليل يعيد الدورة المكتملة.
    func test_14_4_completeSmallUndoFirstQuarter() throws {
        let ctx = try context()
        try Library.add([1], to: .farReview, in: ctx, now: date("2026-11-10T06:00:00"))
        for (i, q) in (1...4).enumerated() {
            _ = try Cycles.tap(quarter: q, track: .farReview, in: ctx, now: date("2026-11-10T07:0\(i):00"), calendar: cal)
        }
        XCTAssertEqual(try cycles(ctx).count, 2)
        XCTAssertEqual(try layout(ctx, .farReview).bookmarkQuarter, 1)
        let (result, changes) = try Cycles.tap(quarter: 1, track: .farReview, in: ctx, now: date("2026-11-10T08:00:00"), calendar: cal)
        XCTAssertEqual(result, .undone)
        XCTAssertEqual(changes[.farReview], .restored)
        let far = try layout(ctx, .farReview)
        XCTAssertEqual(far.bookmarkQuarter, 1)
        XCTAssertEqual(far.progressText, "3 من 4")
    }

    /// §14.4: الاكتمال بالإزالة: خرج آخر ما لم يُظلَّل فاكتملت. وم40: إن فرغ المسار انتهت دورته بلا اكتمال،
    /// وأول إضافة بعده تبدأ دورة جديدة لا تُعدّ فيها التلاوات القديمة.
    func test_14_4_completionByRemovalAndEmptyTrack() throws {
        let ctx = try context()
        try Library.add([10, 11], to: .nearReview, in: ctx, now: date("2026-11-01T08:00:00"))
        for q in 37...40 { _ = try Cycles.tap(quarter: q, track: .nearReview, in: ctx, now: date("2026-11-05T08:00:00"), calendar: cal) }
        try Library.remove([11], from: .nearReview, in: ctx, now: date("2026-11-06T08:00:00"))
        var all = try cycles(ctx)
        XCTAssertEqual(all.filter { $0.endReasonRaw == CycleEnd.completed.rawValue }.count, 1)
        XCTAssertEqual(Cycles.current(.nearReview, in: all)?.startedAt, date("2026-11-06T08:00:00"))
        try Library.remove([10], from: .nearReview, in: ctx, now: date("2026-11-07T08:00:00"))
        all = try cycles(ctx)
        XCTAssertNil(Cycles.current(.nearReview, in: all), "فرغ المسار فانتهت دورته")
        XCTAssertEqual(all.filter { $0.endReasonRaw == CycleEnd.emptied.rawValue }.count, 1)
        try Library.add([10], to: .nearReview, in: ctx, now: date("2026-11-08T08:00:00"))
        all = try cycles(ctx)
        XCTAssertEqual(Cycles.current(.nearReview, in: all)?.startedAt, date("2026-11-08T08:00:00"))
        XCTAssertEqual(try layout(ctx, .nearReview).progressText, "0 من 4")
    }

    /// §14.5: «ابدأ دورة جديدة» تنهي الحالية بيد المالك، فـ«0 من …» بلا سطر اكتمال.
    func test_14_5_manualRestart() throws {
        let ctx = try context()
        try Library.add([10, 11], to: .nearReview, in: ctx, now: date("2026-11-01T08:00:00"))
        _ = try Cycles.tap(quarter: 37, track: .nearReview, in: ctx, now: date("2026-11-05T08:00:00"), calendar: cal)
        try Cycles.restart(.nearReview, in: ctx, now: date("2026-11-05T09:00:00"))
        let all = try cycles(ctx)
        XCTAssertEqual(all.filter { $0.endReasonRaw == CycleEnd.manual.rawValue }.count, 1)
        let near = try layout(ctx, .nearReview)
        XCTAssertEqual(near.progressText, "0 من 8")
        XCTAssertEqual(near.bookmarkQuarter, 37)
        XCTAssertNil(Cycles.completedDays(.nearReview, quarters: near.quarters, cycles: all,
                                          readings: try ctx.fetch(FetchDescriptor<QuarterReading>()),
                                          now: date("2026-11-05T10:00:00"), calendar: cal))
    }

    // MARK: المرحلة 4: الإضافة في منتصف الدورة (§14.6)

    /// المضاف يدخل الدورة الحالية في مكانه ويزيد العدد، فإن كان قبل الموضع انتقل إليه الموضع.
    /// وتظليلاته بعد بداية الدورة تُعدّ فيها (س7).
    func test_14_6_addMidCycle() throws {
        let ctx = try context()
        try Library.add([10, 11], to: .nearReview, in: ctx, now: date("2026-11-01T08:00:00"))
        for q in 37...38 { ctx.insert(QuarterReading(quarter: q, readAt: date("2026-11-05T08:00:00"))) }
        ctx.insert(QuarterReading(quarter: 17, readAt: date("2026-10-01T08:00:00")))
        try ctx.save()
        try Library.add([12], to: .nearReview, in: ctx, now: date("2026-11-06T08:00:00"))
        var near = try layout(ctx, .nearReview)
        XCTAssertEqual(near.progressText, "2 من 12")
        XCTAssertEqual(near.bookmarkQuarter, 39)
        try Library.add([5], to: .nearReview, in: ctx, now: date("2026-11-06T09:00:00"))
        near = try layout(ctx, .nearReview)
        XCTAssertEqual(near.progressText, "2 من 16", "تظليل ح 5 قبل الدورة لا يُعدّ")
        XCTAssertEqual(near.bookmarkQuarter, 17)
        XCTAssertEqual(near.foldedRow?.hizb, 5)
        XCTAssertEqual(try cycles(ctx).count, 1, "الدورة نفسها")
    }

    /// س7: الحزب المنقول من مسار آخر وفيه تظليلات بعد بداية الدورة تُعدّ فيها.
    func test_14_6_movedHizbReadingsCount() throws {
        let ctx = try context()
        try Library.add([10], to: .nearReview, in: ctx, now: date("2026-11-01T08:00:00"))
        try Library.add([1], to: .farReview, in: ctx, now: date("2026-11-01T08:00:00"))
        ctx.insert(QuarterReading(quarter: 1, readAt: date("2026-11-03T08:00:00")))
        try ctx.save()
        try Library.move([1], from: .farReview, to: .nearReview, in: ctx, now: date("2026-11-04T08:00:00"))
        XCTAssertEqual(try layout(ctx, .nearReview).progressText, "1 من 8")
    }

    /// ذ22: نصّ الإشعار.
    func test_14_6_addedWithBookmarkToast() {
        XCTAssertEqual(Phrase.addedWithBookmark(added: [4], moved: [], bookmark: 4, to: .nearReview),
                       "أُضيف ح 4 · وفيه الآن موضع التوقّف")
        XCTAssertEqual(Phrase.addedWithBookmark(added: [4, 5], moved: [], bookmark: 4, to: .nearReview),
                       "أُضيف حزبان إلى مراجعة القريب · وفي ح 4 الآن موضع التوقّف")
    }
}
