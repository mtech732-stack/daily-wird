import XCTest
@testable import DailyWird

/// ش1 · المرحلة 3: العرض بالسور (7.1.1).
final class SuraViewTests: XCTestCase {

    private let far = ReviewTrackLayout(track: .farReview, hizbs: Array(1...9))

    private func section(_ layout: ReviewTrackLayout, _ title: String) throws -> SuraSection {
        try XCTUnwrap(layout.sections.first { $0.title == title }, "لا قسم: \(title)")
    }

    /// 7.1.1: قسم لكل سورة فيها ربع من المسار، بترتيب المصحف، ومدى أحزابها بجانب اسمها.
    func test_7_1_1_sectionPerSuraWithHizbRange() throws {
        XCTAssertEqual(far.sections.map(\.title), ["الفاتحة", "البقرة", "آل عمران", "النساء"])
        XCTAssertEqual(try section(far, "البقرة").hizbRange, "ح 1 ← ح 5")
        XCTAssertEqual(try section(far, "الفاتحة").hizbRange, "ح 1")
        XCTAssertEqual(try section(far, "البقرة").rows.map(\.hizb), [1, 2, 3, 4, 5])
    }

    /// 7.1.1: لا يظهر في الصفّ إلا أرباع الحزب الواقعة في السورة، والباقي فراغ في مكانه الثابت.
    func test_7_1_1_onlyQuartersOfThisSuraInFixedSlots() throws {
        let fatiha = try section(far, "الفاتحة")
        XCTAssertEqual(fatiha.rows[0].slots, [1, nil, nil, nil])
        let baqara = try section(far, "البقرة")
        XCTAssertEqual(baqara.rows[0].slots, [1, 2, 3, 4])
    }

    /// 7.1.1: الحزب الذي تبدأ في منتصفه سورة يُقسَم صفّه بين السورتين، كلٌّ في مكانه.
    func test_7_1_1_splitHizbRowsAcrossSuras() throws {
        // ح 8: الربعان 29–30 في آل عمران، و31–32 في النساء.
        let imran = try section(far, "آل عمران")
        let nisa = try section(far, "النساء")
        XCTAssertEqual(imran.rows.first { $0.hizb == 8 }?.slots, [29, 30, nil, nil])
        XCTAssertEqual(nisa.rows.first { $0.hizb == 8 }?.slots, [nil, nil, 31, 32])
    }

    /// 7.1.1، ت8: الربع المشترك يظهر في الموضعين، ويُعلَّم فيهما، وهو ربع واحد.
    func test_7_1_1_sharedQuarterAppearsUnderBothSuras() throws {
        let baqara = try section(far, "البقرة")
        let imran = try section(far, "آل عمران")
        XCTAssertEqual(baqara.rows.first { $0.hizb == 5 }?.slots, [17, 18, 19, 20])
        XCTAssertEqual(imran.rows.first { $0.hizb == 5 }?.slots, [nil, nil, nil, 20])
        XCTAssertTrue(baqara.shared.contains(20))
        XCTAssertTrue(imran.shared.contains(20))
        XCTAssertTrue(far.sharedQuarters.contains(1))
        XCTAssertFalse(far.sharedQuarters.contains(29))
        // ربع واحد في المسار: لا يتكرّر في الدورة.
        XCTAssertEqual(far.quarters.filter { $0 == 20 }.count, 1)
    }

    /// 5.5: علامة موضع التوقّف تظهر في الموضعين إن كان ربعاً مشتركاً.
    func test_5_5_bookmarkShownInBothPlacesWhenShared() throws {
        XCTAssertEqual(far.bookmarkQuarter, 1)
        XCTAssertTrue(try section(far, "الفاتحة").rows[0].hasBookmark)
        XCTAssertTrue(try section(far, "البقرة").rows[0].hasBookmark)
        XCTAssertFalse(try section(far, "البقرة").rows[1].hasBookmark)
        // وفي الصفّ المطويّ يُعلَّم المشترك بالزاوية المقطوعة.
        XCTAssertEqual(far.foldedRow?.shared, [1])
    }

    /// 7.1.1: الجزء وسم صغير عند أول حزب فيه، مرة واحدة في المسار.
    func test_7_1_1_juzTagOnceAtFirstHizb() {
        let tags = far.sections.flatMap(\.rows).compactMap(\.juzTag)
        XCTAssertEqual(tags, [1, 2, 3, 4, 5])
        XCTAssertEqual(far.sections[0].rows[0].juzTag, 1)
    }

    /// 7.1.1: السور القصيرة المتجاورة في الأرباع نفسها تُجمع في قسم واحد.
    func test_7_1_1_shortAdjacentSurasAreGrouped() {
        let amma = ReviewTrackLayout(track: .farReview, hizbs: [59, 60])
        XCTAssertEqual(amma.sections.first?.suras, [78, 79])
        XCTAssertEqual(amma.sections.first?.title, "\(Quran.suraName(78)) · \(Quran.suraName(79))")
        // كل سورة في قسم واحد لا غير.
        let all = amma.sections.flatMap(\.suras)
        XCTAssertEqual(all, Array(78...114))
        // الربع في القسم المجموع لا يُعدّ مشتركاً (ت8).
        XCTAssertFalse(amma.sharedQuarters.contains(233))
    }

    /// 7.1.1: في المسار يظهر من السور ما فيه وحده؛ وسورة في مسارين لكلٍّ أرباعه.
    func test_7_1_1_suraInTwoTracksShowsOnlyEachTracksQuarters() throws {
        let near = ReviewTrackLayout(track: .nearReview, hizbs: [10, 11])
        let nisaNear = try section(near, "النساء")
        let nisaFar = try section(far, "النساء")
        XCTAssertEqual(nisaNear.rows.map(\.hizb), [10, 11])
        XCTAssertEqual(nisaFar.rows.map(\.hizb), [8, 9])
        XCTAssertTrue(Set(nisaNear.rows.flatMap(\.slots).compactMap { $0 })
            .isDisjoint(with: nisaFar.rows.flatMap(\.slots).compactMap { $0 }))
    }
}
