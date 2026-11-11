import Foundation
import SwiftData
import XCTest
@testable import DailyWird

/// ش4 · المرحلة 1: الحزب الذي يُحفظ الآن وأوجهه (5.6، design/system.md §15.1–15.2).
@MainActor
final class NewTrackTests: XCTestCase {

    private func context() throws -> ModelContext {
        ModelContext(try Persistence.makeContainer(inMemory: true))
    }

    /// §15.8: أوجه الحزب من أول وجه في ربعه الأول إلى آخر وجه في ربعه الرابع.
    func test_5_6_pagesOfHizb() {
        XCTAssertEqual(Quran.pages(ofHizb: 12), Array(112...121))
        XCTAssertEqual(Quran.pages(ofHizb: 60), Array(591...604))
        XCTAssertEqual(Quran.pages(ofHizb: 1), Array(1...11))
        // كل حزب 9 أوجه فأكثر، وأكثرها 14 (§15.5).
        for hizb in 1...Quran.hizbCount {
            XCTAssertTrue((9...14).contains(Quran.pages(ofHizb: hizb).count), "ح \(hizb)")
        }
    }

    /// §15.2: التقدّم على الأوجه بلا تكرار: الوجه 121 بين ح 12 وح 13 يُعدّ مرة (ذ37).
    func test_5_6_progressCountsSharedPageOnce() {
        let layout = NewTrackLayout(hizbs: [13, 12], completed: Set(112...116))
        XCTAssertEqual(layout.hizbs, [12, 13])
        XCTAssertEqual(layout.pages.count, 20)
        XCTAssertEqual(layout.progressText, "5 من 20")
        XCTAssertEqual(NewTrackLayout(hizbs: [12]).progressText, "0 من 10")
    }

    /// §15.3: موضع التوقّف أول وجه لم يتمّ، في أول حزب بقي فيه وجه؛ وحزب أُتمّ كله يُتخطّى.
    func test_5_6_bookmarkFirstIncompletePage() {
        XCTAssertEqual(NewTrackLayout(hizbs: [12]).bookmarkPage, 112)
        XCTAssertEqual(NewTrackLayout(hizbs: [12], completed: Set(112...116)).bookmarkPage, 117)
        // التخطّي: الإطار على أول ما لم يتمّ.
        XCTAssertEqual(NewTrackLayout(hizbs: [12], completed: [112, 114]).bookmarkPage, 113)
        let two = NewTrackLayout(hizbs: [12, 13], completed: Set(112...121))
        XCTAssertEqual(two.bookmarkHizb, 13)
        XCTAssertEqual(two.bookmarkPage, 122, "121 أُتمّ في ح 12 فهو متمّ في ح 13")
        XCTAssertNil(NewTrackLayout(hizbs: [12], completed: Set(112...121)).bookmark)
    }

    /// §15.2: الصفّ المطويّ خمسة أوجه من أول الحزب، وآخرها يُكمل من الذي قبله (ح 60: 591–595 · 596–600 · 600–604).
    func test_5_6_foldedRowOfFive() {
        XCTAssertEqual(NewTrackLayout(hizbs: [12]).foldedRow, FiveRow(hizb: 12, pages: Array(112...116)))
        XCTAssertEqual(NewTrackLayout(hizbs: [12], completed: Set(112...116)).foldedRow?.pages, Array(117...121))
        XCTAssertEqual(NewTrackLayout(hizbs: [60], completed: Set(591...596)).foldedRow?.pages, Array(596...600))
        // الموضع 600 في الصفّ الثاني، و601 في الثالث المكمَّل.
        XCTAssertEqual(NewTrackLayout(hizbs: [60], completed: Set(591...599)).foldedRow?.pages, Array(596...600))
        XCTAssertEqual(NewTrackLayout(hizbs: [60], completed: Set(591...600)).foldedRow?.pages, Array(600...604))
        // أُتمّت كلها: آخر صفّ.
        XCTAssertEqual(NewTrackLayout(hizbs: [12], completed: Set(112...121)).foldedRow?.pages, Array(117...121))
        XCTAssertNil(NewTrackLayout(hizbs: []).foldedRow)
    }

    /// §15.3 (م50): كل أوجه الحزب صفوفاً خمسة خمسة بلا تكرار، وآخرها ما بقي.
    func test_5_6_allRows() {
        XCTAssertEqual(NewTrackLayout.rows(ofHizb: 12), [Array(112...116), Array(117...121)])
        XCTAssertEqual(NewTrackLayout.rows(ofHizb: 60), [Array(591...595), Array(596...600), Array(601...604)])
        XCTAssertEqual(NewTrackLayout.rows(ofHizb: 13), [Array(121...125), Array(126...130), [131]])
        for hizb in 1...Quran.hizbCount {
            let rows = NewTrackLayout.rows(ofHizb: hizb)
            XCTAssertTrue(rows.dropLast().allSatisfy { $0.count == 5 }, "ح \(hizb)")
            XCTAssertEqual(Array(rows.joined()), Quran.pages(ofHizb: hizb), "ح \(hizb)")
        }
    }

    /// §15.2 (ذ28): السورتان بأسمائهما، وأكثر «أولها ← آخرها».
    func test_5_6_hizbLine() {
        XCTAssertEqual(NewTrackLayout.hizbLine(12), "· المائدة · الجزء 6")
        XCTAssertEqual(NewTrackLayout.hizbLine(11), "· النساء · المائدة · الجزء 6")
        XCTAssertEqual(NewTrackLayout.hizbLine(60), "· الأعلى ← الناس · الجزء 30")
    }

    /// §15.8: تسمية الوجه لقارئ الشاشة.
    func test_5_6_pageLabel() {
        let layout = NewTrackLayout(hizbs: [12], completed: Set(112...117), today: [117])
        XCTAssertEqual(layout.pageLabel(118), "الوجه 118، لم يُحفظ، موضع التوقّف")
        XCTAssertEqual(layout.pageLabel(117), "الوجه 117، محفوظ، أتممته اليوم")
        XCTAssertEqual(layout.pageLabel(112), "الوجه 112، محفوظ")
    }

    /// 5.6: اختيار الحزب صفّ مفتوح بمسار `new`، بلا دورة (الدورة لمسارَي المراجعة، 5.5).
    /// وما في القريب لا ينتقل إلا بجواب النقل، ويُغلق صفّه هناك ولا يُحذف.
    func test_5_6_pickOpensRowWithoutCycle() throws {
        let ctx = try context()
        let t0 = Date(timeIntervalSince1970: 1_794_000_000)
        let t1 = t0.addingTimeInterval(3600)
        try Library.add([11], to: .nearReview, in: ctx, now: t0)
        XCTAssertEqual(try Library.add([12], to: .newMemorization, in: ctx, now: t1), [12])
        XCTAssertEqual(try Library.add([11], to: .newMemorization, in: ctx, now: t1), [], "بلا جواب النقل لا يُنقل")
        XCTAssertEqual(try Library.add([11], to: .newMemorization, in: ctx, moving: true, now: t1), [11])
        let rows = try ctx.fetch(FetchDescriptor<HizbPlacement>())
        XCTAssertEqual(Library.activeHizbs(in: .newMemorization, from: rows), [11, 12])
        XCTAssertEqual(rows.count, 3, "النقل يُغلق الصفّ ولا يحذفه")
        let cycles = try ctx.fetch(FetchDescriptor<ReviewCycle>())
        XCTAssertFalse(cycles.contains { $0.track == .newMemorization }, "لا دورة للمحفوظ الجديد")
        // فرغ القريب فانتهت دورته (م40).
        XCTAssertNil(Cycles.current(.nearReview, in: cycles))
    }

    /// §15.6: الإزالة تُغلق الصفّ، وسجلّ الأوجه باقٍ فتعود كما كانت.
    func test_5_6_removeKeepsPages() throws {
        let ctx = try context()
        let t0 = Date(timeIntervalSince1970: 1_794_000_000)
        try Library.add([12], to: .newMemorization, in: ctx, now: t0)
        for page in 112...116 { ctx.insert(PageCompletion(page: page, completedAt: t0)) }
        try ctx.save()
        XCTAssertEqual(try Library.remove([12], from: .newMemorization, in: ctx, now: t0.addingTimeInterval(60)), [12])
        XCTAssertTrue(Library.activeHizbs(in: .newMemorization, from: try ctx.fetch(FetchDescriptor<HizbPlacement>())).isEmpty)
        try Library.add([12], to: .newMemorization, in: ctx, now: t0.addingTimeInterval(120))
        let pages = try ctx.fetch(FetchDescriptor<PageCompletion>())
        let layout = NewTrackLayout(hizbs: [12], completed: Set(pages.map(\.page)))
        XCTAssertEqual(layout.progressText, "5 من 10")
    }

    /// §15.2: «آخر إدخال» أحدث إتمام بين أوجه أحزاب الجديد الآن.
    func test_5_6_lastEntryFromPages() {
        let t0 = Date(timeIntervalSince1970: 1_794_000_000)
        let list = [PageCompletion(page: 112, completedAt: t0), PageCompletion(page: 300, completedAt: t0.addingTimeInterval(99)),
                    PageCompletion(page: 113, completedAt: t0.addingTimeInterval(60))]
        XCTAssertEqual(LastEntry.latest(inPages: Quran.pages(ofHizb: 12), completions: list), t0.addingTimeInterval(60))
        XCTAssertNil(LastEntry.latest(inPages: Quran.pages(ofHizb: 13), completions: list))
    }

    /// §15.1، §15.6: نصوص الورقة والسؤال والإزالة في المحفوظ الجديد.
    func test_5_6_phrases() {
        XCTAssertEqual(Phrase.addButton([], to: .newMemorization), "اختر حزباً")
        XCTAssertEqual(Phrase.addButton([12], to: .newMemorization), "أضف الحزب 12 إلى المحفوظ الجديد")
        XCTAssertEqual(Phrase.addedToast([12], to: .newMemorization), "أُضيف ح 12 إلى المحفوظ الجديد")
        XCTAssertEqual(Phrase.inThisTrack(.newMemorization), "تحفظه الآن")
        XCTAssertEqual(Phrase.inThisTrack(.farReview), "في هذا المسار")
        XCTAssertEqual(Phrase.conflictNote(1, hasOthers: false, from: .newMemorization), "سجلّ حفظه يبقى كما هو.")
        XCTAssertEqual(Phrase.conflictNote(1, hasOthers: false, from: .nearReview), "سجلّ تلاوته ينتقل معه كما هو.")
        XCTAssertEqual(Phrase.conflictQuestion([11], in: .nearReview), "الحزب 11 موجود في مراجعة القريب. أتنقله؟")
        XCTAssertEqual(Phrase.removeQuestion([12], from: .newMemorization), "أتزيل الحزب 12 من المحفوظ الجديد؟")
        XCTAssertEqual(Phrase.removeNote(1, from: .newMemorization), "يبقى سجلّ حفظه محفوظاً، فإن أعدته ظهرت أوجهه كما كانت.")
        XCTAssertEqual(Phrase.removeSheetNote(.newMemorization), "يبقى سجلّ حفظ ما تزيله محفوظاً.")
    }

    /// وسيط اختبارات الواجهة `-pages`.
    func test_5_6_seedPages() {
        let list = UITestSeed.parsePages("112-114:3,117:0@05:00")
        XCTAssertEqual(list.map(\.quarter), [112, 113, 114, 117])
        XCTAssertEqual(list.last?.hour, 5)
        XCTAssertEqual(list.first?.daysAgo, 3)
        XCTAssertTrue(UITestSeed.parsePages("700:1").isEmpty)
    }

    // MARK: المرحلة 2 (§15.3)

    /// 5.6: ضغطة = أتممته الآن؛ ثانية في اليوم = تراجع يحذف إتمام اليوم وحده؛ وعلى ما أُتمّ قبل اليوم لا تغيير (ذ29).
    func test_5_6_tapCompletesUndoesAndKeepsOld() throws {
        let ctx = try context()
        let cal = WirdDate.calendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 5, minute: 12))!
        let before = cal.date(byAdding: .day, value: -3, to: now)!
        ctx.insert(PageCompletion(page: 113, completedAt: before))
        try ctx.save()

        XCTAssertEqual(try Pages.tap(page: 117, in: ctx, now: now, calendar: cal), .completed)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<PageCompletion>()).filter { $0.page == 117 }.map(\.completedAt), [now])
        XCTAssertEqual(try Pages.tap(page: 117, in: ctx, now: now.addingTimeInterval(60), calendar: cal), .undone)
        XCTAssertTrue(try ctx.fetch(FetchDescriptor<PageCompletion>()).filter { $0.page == 117 }.isEmpty)

        XCTAssertEqual(try Pages.tap(page: 113, in: ctx, now: now, calendar: cal), .completedBefore(before))
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<PageCompletion>()).count, 1, "ما أُتمّ قبل اليوم لا يتغيّر")
    }

    /// 5.6: التراجع يحذف إتمام اليوم وحده، ولو جاءت المزامنة بصفّين، ويبقى إتمام سابق للوجه نفسه.
    func test_5_6_undoRemovesTodayOnly() throws {
        let ctx = try context()
        let cal = WirdDate.calendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 22))!
        let old = cal.date(byAdding: .day, value: -40, to: now)!
        ctx.insert(PageCompletion(page: 200, completedAt: old))
        ctx.insert(PageCompletion(page: 200, completedAt: now.addingTimeInterval(-3600)))
        ctx.insert(PageCompletion(page: 200, completedAt: now.addingTimeInterval(-60)))
        try ctx.save()
        XCTAssertEqual(try Pages.tap(page: 200, in: ctx, now: now, calendar: cal), .undone)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<PageCompletion>()).map(\.completedAt), [old])
    }

    /// ذ29: نصّ الإشعار.
    func test_5_6_oldPageToast() {
        let cal = WirdDate.calendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 5))!
        let thursday = cal.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 5))!
        XCTAssertEqual(Phrase.pageDoneBefore(113, on: thursday, now: now), "أتممت الوجه 113 الخميس 5 نوفمبر")
    }

    /// ذ30: في المهلة يُعرض الصفّ بلا إطار، فتسميته بلا «موضع التوقّف».
    func test_5_6_labelWithoutBookmarkInWindow() {
        let layout = NewTrackLayout(hizbs: [12], completed: Set(112...115))
        XCTAssertEqual(layout.pageLabel(116, showsBookmark: false), "الوجه 116، لم يُحفظ")
        XCTAssertEqual(layout.pageLabel(116), "الوجه 116، لم يُحفظ، موضع التوقّف")
    }

    // MARK: المرحلة 3 (§15.4)

    /// §15.8: الوجه المشترك: أول وجه في الحزب وهو آخر وجه في الذي قبله، أو آخره وهو أول وجه في الذي بعده.
    func test_5_6_sharingHizb() {
        XCTAssertEqual(Quran.sharingHizb(page: 112, inHizb: 12), 11)
        XCTAssertEqual(Quran.sharingHizb(page: 121, inHizb: 12), 13)
        XCTAssertEqual(Quran.sharingHizb(page: 121, inHizb: 13), 12)
        XCTAssertNil(Quran.sharingHizb(page: 116, inHizb: 12))
        XCTAssertNil(Quran.sharingHizb(page: 1, inHizb: 1))
        XCTAssertNil(Quran.sharingHizb(page: 604, inHizb: 60))
        // متناظر: إن شارك ح أ ح ب في وجه شاركه ح ب فيه.
        for hizb in 1...Quran.hizbCount {
            for page in Quran.pages(ofHizb: hizb) {
                if let other = Quran.sharingHizb(page: page, inHizb: hizb) {
                    XCTAssertEqual(Quran.sharingHizb(page: page, inHizb: other), hizb, "الوجه \(page)")
                    XCTAssertTrue(Quran.pages(ofHizb: other).contains(page))
                }
            }
        }
    }

    /// §15.4: إتمامه مرة يُتمّه في الحزبين؛ وإن أُتمّ في حزب سابق ظهر ممتلئاً من أول يوم.
    func test_5_6_sharedPageCountsInBoth() {
        let layout = NewTrackLayout(hizbs: [13], completed: [121])
        XCTAssertEqual(layout.progressText, "1 من 11")
        XCTAssertEqual(layout.bookmarkPage, 122)
        XCTAssertEqual(layout.pageLabel(121, inHizb: 13), "الوجه 121، محفوظ، مشترك مع الحزب 12")
        let two = NewTrackLayout(hizbs: [12, 13], completed: Set(112...121), today: [121])
        XCTAssertEqual(two.progressText, "10 من 20")
        XCTAssertEqual(two.pageLabel(121, inHizb: 12), "الوجه 121، محفوظ، أتممته اليوم، مشترك مع الحزب 13")
    }

    // MARK: المرحلة 4 (§15.5–15.6)

    /// §15.6 (ذ32): وجهتا النقل من كل مسار بترتيبهما.
    func test_5_6_destinations() {
        XCTAssertEqual(Library.destinations(from: .newMemorization), [.nearReview, .farReview])
        XCTAssertEqual(Library.destinations(from: .farReview), [.nearReview, .newMemorization])
        XCTAssertEqual(Library.destinations(from: .nearReview), [.farReview, .newMemorization])
    }

    /// §15.5: الرفع يُغلق صفّ الجديد ويفتح صفّاً في القريب، ويبدأ دورة القريب الفارغ (5.5)،
    /// وسجلّ الأوجه باقٍ تاريخاً للحفظ.
    func test_5_6_raiseKeepsPagesAndStartsNearCycle() throws {
        let ctx = try context()
        let t0 = Date(timeIntervalSince1970: 1_794_000_000)
        try Library.add([12], to: .newMemorization, in: ctx, now: t0)
        for page in 112...121 { ctx.insert(PageCompletion(page: page, completedAt: t0)) }
        try ctx.save()
        XCTAssertEqual(try Library.move([12], from: .newMemorization, to: .nearReview, in: ctx, now: t0.addingTimeInterval(60)), [12])
        let rows = try ctx.fetch(FetchDescriptor<HizbPlacement>())
        XCTAssertEqual(Library.activeHizbs(in: .nearReview, from: rows), [12])
        XCTAssertTrue(Library.activeHizbs(in: .newMemorization, from: rows).isEmpty)
        XCTAssertEqual(rows.count, 2, "يُغلق الصفّ ولا يُحذف")
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<PageCompletion>()).count, 10, "سجلّ الأوجه باقٍ")
        let cycles = try ctx.fetch(FetchDescriptor<ReviewCycle>())
        XCTAssertEqual(Cycles.current(.nearReview, in: cycles)?.startedAt, t0.addingTimeInterval(60))
        XCTAssertNil(Cycles.current(.newMemorization, in: cycles))
    }

    /// م49: الحزب المرفوع يدخل القريب بأرباعه الأربعة غير مظلّلة (5.6)، ولو تُلي فيه في الدورة الجارية
    /// قبل نقله إلى الجديد. وما يُتلى منه بعد الرفع يُعدّ كالعادة.
    func test_5_6_raisedHizbEntersUnshaded_m49() throws {
        let ctx = try context()
        let t0 = Date(timeIntervalSince1970: 1_794_000_000)
        try Library.add([10, 12], to: .nearReview, in: ctx, now: t0)
        // تُلي ح 12 كله في دورة القريب الجارية، وح 10 ربعه الأول.
        for q in Quran.quarters(ofHizb: 12) + [37] { ctx.insert(QuarterReading(quarter: q, readAt: t0.addingTimeInterval(3600))) }
        try ctx.save()
        try Library.move([12], from: .nearReview, to: .newMemorization, in: ctx, now: t0.addingTimeInterval(7200))
        try Library.move([12], from: .newMemorization, to: .nearReview, in: ctx, now: t0.addingTimeInterval(9000))

        let rows = try ctx.fetch(FetchDescriptor<HizbPlacement>())
        let cycles = try ctx.fetch(FetchDescriptor<ReviewCycle>())
        let readings = try ctx.fetch(FetchDescriptor<QuarterReading>())
        let start = Cycles.current(.nearReview, in: cycles)?.startedAt
        XCTAssertEqual(start, t0, "الدورة نفسها لم تكتمل ولم تنتهِ")
        let quarters = Library.activeHizbs(in: .nearReview, from: rows).flatMap(Quran.quarters(ofHizb:))
        let floors = Library.leftNew(from: rows)
        XCTAssertEqual(Cycles.done(quarters: quarters, readings: readings, since: start, floors: floors), [37],
                       "أرباع ح 12 غير مظلّلة في الدورة")
        // وبلا الحدّ كانت تُعدّ (س7)، فهذا ما يغيّره م49 وحده.
        XCTAssertEqual(Cycles.done(quarters: quarters, readings: readings, since: start).count, 5)

        // ما يُتلى بعد الرفع يُعدّ.
        ctx.insert(QuarterReading(quarter: 45, readAt: t0.addingTimeInterval(10_000)))
        try ctx.save()
        XCTAssertEqual(Cycles.done(quarters: quarters, readings: try ctx.fetch(FetchDescriptor<QuarterReading>()),
                                   since: start, floors: floors), [37, 45])
    }

    /// م49 مع الاكتمال: لا تكتمل دورة القريب بأرباع حزب تُليت قبل رفعه.
    func test_5_6_raisedHizbDoesNotCompleteCycle_m49() throws {
        let ctx = try context()
        let t0 = Date(timeIntervalSince1970: 1_794_000_000)
        try Library.add([10, 12], to: .nearReview, in: ctx, now: t0)
        for q in Quran.quarters(ofHizb: 12).prefix(3) { ctx.insert(QuarterReading(quarter: q, readAt: t0.addingTimeInterval(60))) }
        try ctx.save()
        try Library.move([12], from: .nearReview, to: .newMemorization, in: ctx, now: t0.addingTimeInterval(120))
        try Library.move([12], from: .newMemorization, to: .nearReview, in: ctx, now: t0.addingTimeInterval(180))
        for q in Quran.quarters(ofHizb: 10) + [48] {
            _ = try Cycles.tap(quarter: q, track: .nearReview, in: ctx, now: t0.addingTimeInterval(240))
        }
        let cycles = try ctx.fetch(FetchDescriptor<ReviewCycle>())
        XCTAssertFalse(cycles.contains { $0.track == .nearReview && $0.endReasonRaw == CycleEnd.completed.rawValue },
                       "ثلاثة أرباع من ح 12 تُليت قبل رفعه فلا تُعدّ")
    }

    /// §15.5: نصوص الحوار والزرّ والإشعار.
    func test_5_6_raisePhrases() {
        XCTAssertEqual(Phrase.hizbCompleteTitle(12), "اكتمل الحزب 12")
        XCTAssertEqual(Phrase.hizbCompleteNote(12), "أتممت أوجهه كلها، من 112 إلى 121.")
        XCTAssertEqual(Phrase.raiseQuestion, "أترفعه إلى مراجعة القريب؟")
        XCTAssertEqual(Phrase.raiseAnswer, "ارفعه إلى مراجعة القريب")
        XCTAssertEqual(Phrase.raiseButton(12), "ارفع ح 12 إلى مراجعة القريب")
        XCTAssertEqual(Phrase.raisedToast(12, bookmark: false), "رُفع ح 12 إلى مراجعة القريب")
        XCTAssertEqual(Phrase.raisedToast(4, bookmark: true), "رُفع ح 4 إلى مراجعة القريب · وفيه الآن موضع التوقّف")
        XCTAssertEqual(Phrase.hizbMenuMove(to: .newMemorization), "نقل إلى المحفوظ الجديد")
    }

    /// §15.5: الحزب مكتمل ما دامت أوجهه كلها متمّة.
    func test_5_6_isComplete() {
        let layout = NewTrackLayout(hizbs: [12, 13], completed: Set(112...121))
        XCTAssertTrue(layout.isComplete(12))
        XCTAssertFalse(layout.isComplete(13))
        XCTAssertEqual(layout.completeHizbs, [12])
    }
}
