import Foundation
import SwiftData
import XCTest
@testable import DailyWird

/// ش1 · المرحلة 5: النقل والإزالة مع حفظ السجلّ (5.1، 5.2، §12.5).
@MainActor
final class ManageTests: XCTestCase {

    private func context() throws -> ModelContext {
        ModelContext(try Persistence.makeContainer(inMemory: true))
    }

    private func rows(_ ctx: ModelContext) throws -> [HizbPlacement] {
        try ctx.fetch(FetchDescriptor<HizbPlacement>())
    }

    /// 5.2: في ش1 «المسار الآخر» من مسارَي المراجعة واحد.
    func test_5_2_otherReviewTrack() {
        XCTAssertEqual(Library.otherReviewTrack(.farReview), .nearReview)
        XCTAssertEqual(Library.otherReviewTrack(.nearReview), .farReview)
    }

    /// 5.2: النقل يدوي: يُغلق الصفّ في المصدر ولا يُحذف، ويُفتح في الوجهة.
    func test_5_2_moveClosesAndOpensWithoutDeleting() throws {
        let ctx = try context()
        let t0 = Date(timeIntervalSince1970: 1_794_000_000)
        let t1 = t0.addingTimeInterval(3600)
        try Library.add([10, 11], to: .nearReview, in: ctx, now: t0)
        XCTAssertEqual(try Library.move([10], from: .nearReview, to: .farReview, in: ctx, now: t1), [10])
        let all = try rows(ctx)
        XCTAssertEqual(Library.activeHizbs(in: .farReview, from: all), [10])
        XCTAssertEqual(Library.activeHizbs(in: .nearReview, from: all), [11])
        let ten = all.filter { $0.hizb == 10 }.sorted { $0.addedAt < $1.addedAt }
        XCTAssertEqual(ten.count, 2, "الصفّ القديم باقٍ تاريخاً")
        XCTAssertEqual(ten[0].removedAt, t1)
        XCTAssertNil(ten[1].removedAt)
    }

    /// 5.2: لا يُنقل إلا ما في المصدر فعلاً؛ فلا يصل حزب من مسار ثالث إلى الوجهة.
    func test_5_2_moveOnlyWhatIsInSource() throws {
        let ctx = try context()
        try Library.add([9], to: .farReview, in: ctx)
        try Library.add([10], to: .nearReview, in: ctx)
        XCTAssertEqual(try Library.move([9, 10, 12], from: .nearReview, to: .farReview, in: ctx), [10])
        XCTAssertEqual(Library.activeHizbs(in: .farReview, from: try rows(ctx)), [9, 10])
    }

    /// 5.1: الإزالة تُغلق الصفّ ولا تحذفه، ولا تمسّ سجلّ التظليل.
    func test_5_1_removeKeepsRowAndReadings() throws {
        let ctx = try context()
        let t1 = Date(timeIntervalSince1970: 1_794_003_600)
        try Library.add([11], to: .nearReview, in: ctx)
        ctx.insert(QuarterReading(quarter: 41, track: .nearReview))
        try ctx.save()
        XCTAssertEqual(try Library.remove([11], from: .nearReview, in: ctx, now: t1), [11])
        let all = try rows(ctx)
        XCTAssertEqual(Library.activeHizbs(in: .nearReview, from: all), [])
        XCTAssertEqual(all.count, 1, "لا يُحذف صفّ")
        XCTAssertEqual(all[0].removedAt, t1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<QuarterReading>()).map(\.quarter), [41])
    }

    /// 5.1: «فإن أُعيد ظهر عمره كما كان»: إعادة الحزب بعد إزالته تجد سجلّه كما هو.
    func test_5_1_readdAfterRemoveFindsHistory() throws {
        let ctx = try context()
        try Library.add([11], to: .nearReview, in: ctx)
        let read = Date(timeIntervalSince1970: 1_794_000_000)
        ctx.insert(QuarterReading(quarter: 42, readAt: read, track: .nearReview))
        try ctx.save()
        try Library.remove([11], from: .nearReview, in: ctx)
        try Library.add([11], to: .farReview, in: ctx)
        XCTAssertEqual(Library.activeHizbs(in: .farReview, from: try rows(ctx)), [11])
        let readings = try ctx.fetch(FetchDescriptor<QuarterReading>())
        XCTAssertEqual(readings.map(\.quarter), [42])
        XCTAssertEqual(readings.first?.readAt, read)
    }

    /// 5.1: لا يُزال إلا ما في المسار؛ وما في المسار الآخر يبقى.
    func test_5_1_removeOnlyFromThatTrack() throws {
        let ctx = try context()
        try Library.add([9], to: .farReview, in: ctx)
        try Library.add([10], to: .nearReview, in: ctx)
        XCTAssertEqual(try Library.remove([9, 10], from: .nearReview, in: ctx), [10])
        XCTAssertEqual(Library.activeHizbs(in: .farReview, from: try rows(ctx)), [9])
    }

    /// §12.5، م20: صياغة النقل والإزالة بالعدد والضمير.
    func test_12_5_phrasing() {
        XCTAssertEqual(Phrase.movedToast([10], to: .farReview), "نُقل ح 10 إلى مراجعة البعيد")
        XCTAssertEqual(Phrase.movedToast([1, 2, 3], to: .nearReview), "نُقل 3 أحزاب إلى مراجعة القريب")
        XCTAssertEqual(Phrase.removedToast([11]), "أُزيل ح 11 · سجلّه محفوظ")
        XCTAssertEqual(Phrase.removedToast([10, 11]), "أُزيل حزبان · سجلّهما محفوظ")
        XCTAssertEqual(Phrase.removedToast(Array(1...11)), "أُزيل 11 حزباً · سجلّها محفوظ")
        XCTAssertEqual(Phrase.removeQuestion([11], from: .nearReview), "أتزيل الحزب 11 من مراجعة القريب؟")
        XCTAssertEqual(Phrase.removeQuestion([10, 11], from: .nearReview), "أتزيل الحزبين 10 و11 من مراجعة القريب؟")
        XCTAssertEqual(Phrase.removeQuestion([1, 2, 3], from: .farReview), "أتزيل 3 أحزاب من مراجعة البعيد؟")
        XCTAssertEqual(Phrase.removeNote(1), "يبقى سجلّ تلاوته محفوظاً، فإن أعدته ظهر عمره كما كان.")
        XCTAssertEqual(Phrase.removeNote(2), "يبقى سجلّ تلاوتهما محفوظاً، فإن أعدتهما ظهر عمرهما كما كان.")
        XCTAssertEqual(Phrase.removeAnswer(1), "أزله")
        XCTAssertEqual(Phrase.removeAnswer(2), "أزلهما")
        XCTAssertEqual(Phrase.removeAnswer(5), "أزلها")
        XCTAssertEqual(Phrase.manageTitle(removing: false, from: .nearReview), "نقل من مراجعة القريب")
        XCTAssertEqual(Phrase.manageTitle(removing: true, from: .nearReview), "إزالة من مراجعة القريب")
        XCTAssertEqual(Phrase.manageButton([9], removing: false, to: .nearReview), "انقل الحزب 9 إلى مراجعة القريب")
        XCTAssertEqual(Phrase.manageButton([10, 11], removing: true, to: .farReview), "أزل حزبين")
        XCTAssertEqual(Phrase.manageButton([], removing: true, to: .farReview), "اختر جزءاً أو حزباً")
        XCTAssertEqual(Phrase.hizbMenuHeader(10), "ح 10 · النساء · الجزء 5")
        // نصّ البند بلا علامتي العزل الخفيّتين (⁨…⁩) اللتين يضيفهما الإقحام في مفتاح الترجمة (#48).
        XCTAssertEqual(Phrase.hizbMenuMove(to: .farReview), "نقل إلى مراجعة البعيد")
        XCTAssertEqual(Phrase.hizbMenuMove(to: .nearReview), "نقل إلى مراجعة القريب")
    }
}
