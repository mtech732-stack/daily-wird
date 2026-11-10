import Foundation
import SwiftData
import XCTest
@testable import DailyWird

/// ش1 · المرحلة 4: منع الحزب في مسارين (5.1)، وتحمّل التكرار من المزامنة (م18).
@MainActor
final class ConflictTests: XCTestCase {

    private func context() throws -> ModelContext {
        ModelContext(try Persistence.makeContainer(inMemory: true))
    }

    private func rows(_ ctx: ModelContext) throws -> [HizbPlacement] {
        try ctx.fetch(FetchDescriptor<HizbPlacement>())
    }

    /// 5.1: الحزب الموجود في مسار آخر يُسأل عنه، ولا يُضاف إليه بلا جواب.
    func test_5_1_hizbInOtherTrackIsAskedAbout() throws {
        let ctx = try context()
        try Library.add([10, 11], to: .nearReview, in: ctx)
        XCTAssertEqual(Library.conflicts([9, 10], with: .farReview, placements: try rows(ctx)), [10])
        XCTAssertEqual(Library.conflicts([10], with: .nearReview, placements: try rows(ctx)), [])
    }

    /// 5.1، 12.3: «اتركه» يضيف ما سواه وحده، ويبقى الحزب في مساره.
    func test_5_1_keepAddsOnlyTheOthers() throws {
        let ctx = try context()
        try Library.add([10], to: .nearReview, in: ctx)
        XCTAssertEqual(try Library.add([9, 10], to: .farReview, in: ctx, moving: false), [9])
        XCTAssertEqual(Library.activeHizbs(in: .farReview, from: try rows(ctx)), [9])
        XCTAssertEqual(Library.activeHizbs(in: .nearReview, from: try rows(ctx)), [10])
    }

    /// 5.1، 5.2: «انقله» ينقل الحزب: يُغلق صفّه القديم ولا يُحذف، ويُفتح في المسار الجديد،
    /// فلا يكون الحزب في مسارين أبداً.
    func test_5_1_moveAnswerMovesWithoutDeleting() throws {
        let ctx = try context()
        let t0 = Date(timeIntervalSince1970: 1_794_000_000)
        let t1 = t0.addingTimeInterval(3600)
        try Library.add([10], to: .nearReview, in: ctx, now: t0)
        XCTAssertEqual(try Library.add([9, 10], to: .farReview, in: ctx, moving: true, now: t1), [9, 10])
        let all = try rows(ctx)
        XCTAssertEqual(Library.activeHizbs(in: .farReview, from: all), [9, 10])
        XCTAssertEqual(Library.activeHizbs(in: .nearReview, from: all), [])
        let ten = all.filter { $0.hizb == 10 }.sorted { $0.addedAt < $1.addedAt }
        XCTAssertEqual(ten.count, 2, "الصفّ القديم باقٍ تاريخاً")
        XCTAssertEqual(ten[0].track, .nearReview)
        XCTAssertEqual(ten[0].removedAt, t1)
        XCTAssertEqual(ten[1].track, .farReview)
        XCTAssertNil(ten[1].removedAt)
    }

    /// 5.2: النقل لا يمحو سجلّ تظليلات الحزب، فهو بالربع لا بالمسار.
    func test_5_2_moveKeepsReadings() throws {
        let ctx = try context()
        try Library.add([10], to: .nearReview, in: ctx)
        ctx.insert(QuarterReading(quarter: 37, track: .nearReview))
        try ctx.save()
        try Library.add([10], to: .farReview, in: ctx, moving: true)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<QuarterReading>()).map(\.quarter), [37])
    }

    /// 5.1: بعد أي سلسلة إضافة ونقل، لا حزب في مسارين.
    func test_5_1_noHizbEverInTwoTracks() throws {
        let ctx = try context()
        try Library.add(Array(1...10), to: .farReview, in: ctx)
        try Library.add(Array(5...20), to: .nearReview, in: ctx, moving: true)
        try Library.add([1, 15], to: .nearReview, in: ctx, moving: false)
        try Library.add([15, 16], to: .farReview, in: ctx, moving: true)
        let all = try rows(ctx)
        let far = Set(Library.activeHizbs(in: .farReview, from: all))
        let near = Set(Library.activeHizbs(in: .nearReview, from: all))
        XCTAssertTrue(far.isDisjoint(with: near))
        XCTAssertEqual(far, Set(1...4).union([15, 16]))
        XCTAssertEqual(near, Set(5...20).subtracting([15, 16]))
    }

    // MARK: م18 · التكرار من المزامنة

    /// م18: صفّان مفتوحان للحزب نفسه من جهازين: يُعرض في مسار واحد، هو الأحدث إضافةً.
    func test_m18_duplicateOpenRowsShowInNewestTrackOnly() throws {
        let t0 = Date(timeIntervalSince1970: 1_794_000_000)
        let older = HizbPlacement(hizb: 10, track: .nearReview, addedAt: t0)
        let newer = HizbPlacement(hizb: 10, track: .farReview, addedAt: t0.addingTimeInterval(60))
        let same = HizbPlacement(hizb: 3, track: .farReview, addedAt: t0)
        let sameAgain = HizbPlacement(hizb: 3, track: .farReview, addedAt: t0)
        let all = [older, newer, same, sameAgain]
        XCTAssertEqual(Library.activeHizbs(in: .farReview, from: all), [3, 10])
        XCTAssertEqual(Library.activeHizbs(in: .nearReview, from: all), [])
    }

    /// م18: التسوية تغلق الأقدم ولا تحذف شيئاً، ولا تغيّر ما يُعرض.
    func test_m18_reconcileClosesStaleRowsWithoutDeleting() throws {
        let ctx = try context()
        let t0 = Date(timeIntervalSince1970: 1_794_000_000)
        let t1 = t0.addingTimeInterval(60)
        ctx.insert(HizbPlacement(hizb: 10, track: .nearReview, addedAt: t0))
        ctx.insert(HizbPlacement(hizb: 10, track: .farReview, addedAt: t1))
        ctx.insert(HizbPlacement(hizb: 3, track: .farReview, addedAt: t0))
        try ctx.save()
        let before = Library.activeHizbs(in: .farReview, from: try rows(ctx))
        XCTAssertEqual(try Library.reconcile(in: ctx), 1)
        let all = try rows(ctx)
        XCTAssertEqual(all.count, 3, "لا يُحذف صفّ")
        XCTAssertEqual(all.filter { $0.removedAt == nil }.count, 2)
        XCTAssertEqual(all.first { $0.hizb == 10 && $0.track == .nearReview }?.removedAt, t1)
        XCTAssertEqual(Library.activeHizbs(in: .farReview, from: all), before)
        XCTAssertEqual(try Library.reconcile(in: ctx), 0, "التسوية الثانية لا تغيّر شيئاً")
    }

    // MARK: صياغة السؤال (§12.3، م20)

    func test_5_1_conflictPhrasing() {
        XCTAssertEqual(Phrase.conflictQuestion([10], in: .nearReview), "الحزب 10 موجود في مراجعة القريب. أتنقله؟")
        XCTAssertEqual(Phrase.conflictQuestion([10, 11], in: .nearReview), "الحزبان 10 و11 موجودان في مراجعة القريب. أتنقلهما؟")
        XCTAssertEqual(Phrase.conflictQuestion([1, 2, 3], in: .farReview), "3 أحزاب موجودة في مراجعة البعيد. أتنقلها؟")
        XCTAssertEqual(Phrase.conflictNote(1, hasOthers: true), "سجلّ تلاوته ينتقل معه كما هو. ويُضاف ما سواه في الحالين.")
        XCTAssertEqual(Phrase.conflictNote(2, hasOthers: false), "سجلّ تلاوتهما ينتقل معهما كما هو.")
        XCTAssertEqual(Phrase.moveAnswer(1, to: .farReview), "انقله إلى مراجعة البعيد")
        XCTAssertEqual(Phrase.keepAnswer(2, in: .nearReview), "اتركهما في مراجعة القريب")
    }
}
