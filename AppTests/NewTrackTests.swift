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

    /// §15.3: كل أوجه الحزب صفوفاً خمسة خمسة.
    func test_5_6_allRows() {
        XCTAssertEqual(NewTrackLayout.rows(ofHizb: 12), [Array(112...116), Array(117...121)])
        XCTAssertEqual(NewTrackLayout.rows(ofHizb: 60), [Array(591...595), Array(596...600), Array(600...604)])
        for hizb in 1...Quran.hizbCount {
            let rows = NewTrackLayout.rows(ofHizb: hizb)
            XCTAssertTrue(rows.allSatisfy { $0.count == 5 }, "ح \(hizb)")
            XCTAssertEqual(Set(rows.joined()), Set(Quran.pages(ofHizb: hizb)), "ح \(hizb)")
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
}
