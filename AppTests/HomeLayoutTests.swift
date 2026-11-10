import Foundation
import SwiftData
import XCTest
@testable import DailyWird

/// ش1 · المرحلة 1: الشاشة الرئيسية بمساراتها الثلاثة، والطيّ على موضع التوقّف، والأرشيف (7.1).
@MainActor
final class HomeLayoutTests: XCTestCase {

    // MARK: 6.1 · الجدول المضمّن

    /// 6.1، 4.4: جدول الحدود مضمّن في التطبيق ويُقرأ كاملاً.
    func test_6_1_embeddedBoundaryTableLoads() {
        XCTAssertEqual(Quran.table.quarters.count, 240)
        XCTAssertEqual(Quran.table.pages.count, 604)
        XCTAssertEqual(Quran.table.suras.count, 114)
        XCTAssertEqual(Set(Quran.table.quarters.map(\.hizb)), Set(1...60))
        XCTAssertEqual(Quran.suraName(1), "الفاتحة")
        XCTAssertEqual(Quran.suraName(84), "الانشقاق")
    }

    /// 3: الحزب أربعة أرباع متتالية، وكل جزء حزبان.
    func test_3_hizbQuartersAndJuz() {
        XCTAssertEqual(Quran.quarters(ofHizb: 1), [1, 2, 3, 4])
        XCTAssertEqual(Quran.quarters(ofHizb: 60), [237, 238, 239, 240])
        for hizb in 1...60 {
            XCTAssertEqual(Quran.juz(ofHizb: hizb), (hizb + 1) / 2, "الحزب \(hizb)")
            for q in Quran.quarters(ofHizb: hizb) { XCTAssertEqual(Quran.quarter(q).hizb, hizb) }
        }
        XCTAssertEqual(Quran.hizbs(ofJuz: 5), [9, 10])
    }

    // MARK: 5.1 · يبدأ فارغاً

    /// 5.1: لا شيء مضاف مسبقاً؛ التطبيق يبدأ بمسارات فارغة.
    func test_5_1_appStartsEmpty() throws {
        let context = ModelContext(try Persistence.makeContainer(inMemory: true))
        let placements = try context.fetch(FetchDescriptor<HizbPlacement>())
        XCTAssertTrue(placements.isEmpty)
        for track in Track.allCases where track.isReview {
            XCTAssertTrue(ReviewTrackLayout(track: track, hizbs: Library.activeHizbs(in: track, from: placements)).isEmpty)
        }
    }

    /// 5.1، 5.2: أحزاب المسار من الصفوف المفتوحة وحدها، مرتّبة بلا تكرار.
    func test_5_1_activeHizbsReadOpenPlacementsOnly() {
        let removed = HizbPlacement(hizb: 3, track: .farReview)
        removed.removedAt = .now
        let placements = [
            HizbPlacement(hizb: 9, track: .farReview),
            HizbPlacement(hizb: 1, track: .farReview),
            HizbPlacement(hizb: 1, track: .farReview),
            removed,
            HizbPlacement(hizb: 10, track: .nearReview),
        ]
        XCTAssertEqual(Library.activeHizbs(in: .farReview, from: placements), [1, 9])
        XCTAssertEqual(Library.activeHizbs(in: .nearReview, from: placements), [10])
    }

    // MARK: 7.1 · الطيّ على موضع التوقّف

    /// 5.5، 7.1: أرباع المسار مرتّبة تصاعدياً، وموضع التوقّف قبل أي تظليل أول ربع فيه.
    func test_7_1_bookmarkBeforeAnyReadingIsFirstQuarter() {
        let layout = ReviewTrackLayout(track: .nearReview, hizbs: [11, 10])
        XCTAssertEqual(layout.hizbs, [10, 11])
        XCTAssertEqual(layout.quarters, Array(37...44))
        XCTAssertEqual(layout.bookmarkQuarter, 37)
        XCTAssertEqual(layout.bookmarkHizb, 10)
    }

    /// 7.1: البطاقة مطويّة على صفّ الحزب الذي فيه موضع التوقّف، بأرباعه الأربعة وسورته وجزئه.
    func test_7_1_foldedRowIsBookmarkHizb() throws {
        let layout = ReviewTrackLayout(track: .farReview, hizbs: Array(1...9))
        let row = try XCTUnwrap(layout.foldedRow)
        XCTAssertEqual(row.hizb, 1)
        XCTAssertEqual(row.quarters, [1, 2, 3, 4])
        XCTAssertEqual(row.juz, 1)
        XCTAssertEqual(row.juzText, "الجزء 1")
        // الربع 1 يبدأ بالفاتحة وينتهي في البقرة: سورتان على سطرين (م19).
        XCTAssertEqual(row.suraLines, ["الفاتحة", "البقرة"])
    }

    /// 7.1، م19: أكثر من سورتين في الصفّ المطويّ «أولها ←» ثم «آخرها».
    func test_7_1_foldedRowWithManySurasShowsFirstAndLast() throws {
        let row = try XCTUnwrap(ReviewTrackLayout(track: .farReview, hizbs: [60]).foldedRow)
        XCTAssertGreaterThan(row.suras.count, 2)
        XCTAssertEqual(row.suraLines.count, 2)
        XCTAssertEqual(row.suraLines[0], "\(Quran.suraName(row.suras.first!)) ←")
        XCTAssertEqual(row.suraLines[1], Quran.suraName(row.suras.last!))
    }

    /// 7.1: تقدّم الدورة «0 من [عدد الأرباع]» قبل أي تظليل (ش1).
    func test_7_1_progressBeforeAnyReading() {
        XCTAssertEqual(ReviewTrackLayout(track: .farReview, hizbs: Array(1...9)).progressText, "0 من 36")
        XCTAssertEqual(ReviewTrackLayout(track: .nearReview, hizbs: [10, 11]).progressText, "0 من 8")
    }

    // MARK: 7.1 · الأرشيف

    /// 7.1: الأرشيف كل أحزاب المسار بالترتيب، ووسم الجزء عند أول حزب فيه وحده.
    func test_7_1_archiveRowsWithJuzTagAtFirstHizbOfJuz() {
        let rows = ReviewTrackLayout(track: .farReview, hizbs: [1, 2, 3, 9]).archiveRows
        XCTAssertEqual(rows.map(\.hizb), [1, 2, 3, 9])
        XCTAssertEqual(rows.map(\.juzTag), [1, nil, 2, 5])
    }

    // MARK: م4 · التقويم الميلادي والأرقام الإنجليزية

    /// القرار 1، م4: تاريخ الرأس ميلادي بأرقام إنجليزية، مهما كانت منطقة الجهاز.
    func test_9_headerDateIsGregorianWithEnglishDigits() throws {
        let tz = try XCTUnwrap(TimeZone(identifier: "Asia/Riyadh"))
        var parts = DateComponents()
        parts.year = 2026; parts.month = 11; parts.day = 9; parts.hour = 5
        let date = try XCTUnwrap(WirdDate.calendar(timeZone: tz).date(from: parts))
        let text = WirdDate.header(date, timeZone: tz)
        XCTAssertTrue(text.contains("الاثنين"), text)
        XCTAssertTrue(text.contains("نوفمبر"), text)
        XCTAssertTrue(text.contains("9"), text)
        XCTAssertFalse(text.unicodeScalars.contains { (0x0660...0x0669).contains($0.value) || (0x06F0...0x06F9).contains($0.value) },
                       "أرقام مشرقية: \(text)")
    }

    /// القرار 2: اليوم يبدأ عند منتصف الليل بتوقيت الجهاز.
    func test_5_3_dayStartsAtMidnight() throws {
        let tz = try XCTUnwrap(TimeZone(identifier: "Asia/Riyadh"))
        let cal = WirdDate.calendar(timeZone: tz)
        var parts = DateComponents()
        parts.year = 2026; parts.month = 11; parts.day = 9; parts.hour = 0; parts.minute = 0
        let midnight = try XCTUnwrap(cal.date(from: parts))
        XCTAssertEqual(cal.startOfDay(for: midnight.addingTimeInterval(60)), midnight)
        XCTAssertNotEqual(cal.startOfDay(for: midnight.addingTimeInterval(-60)), midnight)
        XCTAssertEqual(cal.identifier, .gregorian)
    }

    /// القرار 1: كل رقم يُكتب في الواجهة بالأرقام الإنجليزية.
    func test_9_labelsUseEnglishDigits() {
        XCTAssertEqual(Digits.hizbLabel(12), "ح 12")
        XCTAssertEqual(Digits.en(240), "240")
    }

    // MARK: اختبارات الواجهة

    /// وسيط اختبارات الواجهة يُقرأ كما كُتب، ولا يعمل دون `-ui-testing`.
    func test_uiTestSeedParsing() {
        XCTAssertNil(UITestSeed.fromLaunchArguments(["app"]))
        XCTAssertEqual(UITestSeed.fromLaunchArguments(["app", "-ui-testing"]), UITestSeed())
        let seed = UITestSeed.parse("farReview:1-3,9;nearReview:10-11")
        XCTAssertEqual(seed.hizbs[.farReview], [1, 2, 3, 9])
        XCTAssertEqual(seed.hizbs[.nearReview], [10, 11])
    }
}
