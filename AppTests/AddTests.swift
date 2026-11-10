import Foundation
import SwiftData
import XCTest
@testable import DailyWird

/// ش1 · المرحلة 2: إضافة جزء أو حزب (5.1، 7.2).
@MainActor
final class AddTests: XCTestCase {

    private func context() throws -> ModelContext {
        ModelContext(try Persistence.makeContainer(inMemory: true))
    }

    private func hizbs(_ track: Track, _ context: ModelContext) throws -> [Int] {
        Library.activeHizbs(in: track, from: try context.fetch(FetchDescriptor<HizbPlacement>()))
    }

    // MARK: 5.1 · الإضافة بالجزء أو بالحزب

    /// 5.1: الجزء الكامل يُضاف حزباه.
    func test_5_1_addingWholeJuzAddsBothHizbs() throws {
        var selection = AddSelection(track: .farReview, trackOf: [:])
        selection.toggleJuz(5)
        XCTAssertEqual(selection.sortedSelection, [9, 10])
        let ctx = try context()
        XCTAssertEqual(try Library.add(selection.sortedSelection, to: .farReview, in: ctx), [9, 10])
        XCTAssertEqual(try hizbs(.farReview, ctx), [9, 10])
    }

    /// 5.1: يُضاف حزب واحد من الجزء.
    func test_5_1_addingSingleHizb() throws {
        var selection = AddSelection(track: .nearReview, trackOf: [:])
        selection.toggle(10)
        let ctx = try context()
        try Library.add(selection.sortedSelection, to: .nearReview, in: ctx)
        XCTAssertEqual(try hizbs(.nearReview, ctx), [10])
        XCTAssertEqual(try hizbs(.farReview, ctx), [])
    }

    /// 5.1: الجزء قد ينقسم بين مسارين (ملاحظة المالك: ح 9 في البعيد، وح 10 في القريب).
    func test_5_1_juzMaySplitBetweenTracks() throws {
        let ctx = try context()
        try Library.add([9], to: .farReview, in: ctx)
        try Library.add([10], to: .nearReview, in: ctx)
        XCTAssertEqual(try hizbs(.farReview, ctx), [9])
        XCTAssertEqual(try hizbs(.nearReview, ctx), [10])
    }

    /// 4.4: الإضافة تُحفظ بتاريخها ووقتها كاملين.
    func test_5_1_addKeepsFullDateAndTime() throws {
        let ctx = try context()
        let when = Date(timeIntervalSince1970: 1_794_200_000.25)
        try Library.add([3], to: .farReview, in: ctx, now: when)
        let rows = try ctx.fetch(FetchDescriptor<HizbPlacement>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].addedAt, when)
        XCTAssertNil(rows[0].removedAt)
    }

    /// 5.1: ما هو في المسار أصلاً لا يُضاف مرة ثانية.
    func test_5_1_hizbAlreadyInTrackIsNotAddedTwice() throws {
        let ctx = try context()
        try Library.add([1, 2], to: .farReview, in: ctx)
        XCTAssertEqual(try Library.add([1, 2, 3], to: .farReview, in: ctx), [3])
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<HizbPlacement>()).count, 3)
    }

    /// 5.1: الحزب لا يكون في مسارين؛ فلا يُضاف ما في مسار آخر دون سؤال.
    func test_5_1_hizbInOtherTrackIsNeverAddedSilently() throws {
        let ctx = try context()
        try Library.add([10], to: .nearReview, in: ctx)
        XCTAssertEqual(try Library.add([9, 10], to: .farReview, in: ctx), [9])
        XCTAssertEqual(try hizbs(.farReview, ctx), [9])
        XCTAssertEqual(try hizbs(.nearReview, ctx), [10])
    }

    /// 5.1: لا شيء مضاف مسبقاً، ولا رقم حزب خارج 1–60.
    func test_5_1_rejectsOutOfRangeHizbs() throws {
        let ctx = try context()
        XCTAssertEqual(try Library.add([0, 61, 60], to: .farReview, in: ctx), [60])
    }

    // MARK: 7.2 · ورقة الإضافة

    /// 7.2: حالات خانة الحزب: متاح · مختار · في هذا المسار · في مسار آخر.
    func test_7_2_chipStates() {
        var selection = AddSelection(track: .farReview, trackOf: [1: .farReview, 10: .nearReview])
        selection.toggle(9)
        XCTAssertEqual(selection.state(of: 1), .here)
        XCTAssertEqual(selection.state(of: 10), .other(.nearReview))
        XCTAssertEqual(selection.state(of: 9), .selected)
        XCTAssertEqual(selection.state(of: 2), .available)
        // ما في هذا المسار لا يُضغط.
        selection.toggle(1)
        XCTAssertFalse(selection.sortedSelection.contains(1))
    }

    /// 7.2: دائرة الجزء تختار ما يُختار من حزبيه (وفيه ما في مسار آخر، فيُسأل عنه عند «أضف»)،
    /// وتمتلئ حين يُختار كلّه، وتُلغيه بضغطة ثانية. وما في هذا المسار لا يُختار.
    func test_7_2_juzCircleSelectsWhatIsPickable() {
        var selection = AddSelection(track: .farReview, trackOf: [10: .nearReview, 11: .farReview])
        selection.toggleJuz(6)
        XCTAssertEqual(selection.sortedSelection, [12])
        selection.toggleJuz(6)
        selection.toggleJuz(5)
        XCTAssertEqual(selection.sortedSelection, [9, 10])
        XCTAssertEqual(selection.conflicts, [10])
        XCTAssertEqual(selection.conflictTrack, .nearReview)
        XCTAssertTrue(selection.isJuzSelected(5))
        selection.toggleJuz(5)
        XCTAssertEqual(selection.sortedSelection, [])
        XCTAssertFalse(selection.isJuzSelected(5))
    }

    /// 7.2: الجزء الذي لم يبقَ فيه ما يُختار لا تُختار دائرته.
    func test_7_2_juzWithNothingPickable() {
        var selection = AddSelection(track: .farReview, trackOf: [1: .farReview, 2: .farReview])
        XCTAssertTrue(selection.pickable(inJuz: 1).isEmpty)
        selection.toggleJuz(1)
        XCTAssertEqual(selection.sortedSelection, [])
        XCTAssertFalse(selection.isJuzSelected(1))
    }

    /// 7.2: تغيير المسار يمحو الاختيار.
    func test_7_2_changingTrackClearsSelection() {
        var selection = AddSelection(track: .farReview, trackOf: [:])
        selection.toggleJuz(1)
        selection.setTrack(.nearReview)
        XCTAssertEqual(selection.track, .nearReview)
        XCTAssertEqual(selection.sortedSelection, [])
    }

    /// ذ3: تحت رقم الحزب اسم السورة التي يبدأ بها.
    func test_7_2_hizbShowsItsFirstSura() {
        XCTAssertEqual(Quran.suraName(Quran.firstSura(ofHizb: 1)), "الفاتحة")
        XCTAssertEqual(Quran.suraName(Quran.firstSura(ofHizb: 9)), "النساء")
    }

    // MARK: م20 · صياغة العدد

    func test_7_2_countPhrasing() {
        XCTAssertEqual(Phrase.addButton([], to: .farReview), "اختر جزءاً أو حزباً")
        XCTAssertEqual(Phrase.addButton([9], to: .farReview), "أضف الحزب 9 إلى مراجعة البعيد")
        XCTAssertEqual(Phrase.addButton([9, 10], to: .nearReview), "أضف حزبين إلى مراجعة القريب")
        XCTAssertEqual(Phrase.addButton([1, 2, 3], to: .farReview), "أضف 3 أحزاب إلى مراجعة البعيد")
        XCTAssertEqual(Phrase.addButton(Array(1...11), to: .farReview), "أضف 11 حزباً إلى مراجعة البعيد")
        XCTAssertEqual(Phrase.addedToast([9], to: .farReview), "أُضيف ح 9 إلى مراجعة البعيد")
        XCTAssertEqual(Phrase.addedToast([9, 10], to: .farReview), "أُضيف حزبان إلى مراجعة البعيد")
        XCTAssertEqual(Phrase.addedToast(Array(1...10), to: .farReview), "أُضيف 10 أحزاب إلى مراجعة البعيد")
        XCTAssertEqual(Phrase.addedToast(Array(1...60), to: .farReview), "أُضيف 60 حزباً إلى مراجعة البعيد")
    }
}
