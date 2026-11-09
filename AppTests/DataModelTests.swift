import Foundation
import SwiftData
import XCTest
@testable import DailyWird

/// ش0 · المرحلة 7: بنية البيانات الصالحة لـ CloudKit (4.4) ولا يضيع فيها السجلّ (4.3).
@MainActor
final class DataModelTests: XCTestCase {

    private func memoryContext() throws -> ModelContext {
        ModelContext(try Persistence.makeContainer(inMemory: true))
    }

    // MARK: 4.4 · قيود CloudKit

    /// 4.4: لا قيود تفرّد في أي كيان.
    func test_4_4_noUniqueConstraints() {
        for entity in Persistence.schema.entities {
            XCTAssertTrue(entity.uniquenessConstraints.isEmpty, "قيد تفرّد في \(entity.name)")
            for attribute in entity.attributes {
                XCTAssertFalse(attribute.isUnique, "خاصية فريدة: \(entity.name).\(attribute.name)")
            }
        }
    }

    /// 4.4: كل علاقة اختيارية (ولا علاقات الآن أصلاً).
    func test_4_4_relationshipsAreOptional() {
        for entity in Persistence.schema.entities {
            for relationship in entity.relationships {
                XCTAssertTrue(relationship.isOptional, "علاقة إلزامية: \(entity.name).\(relationship.name)")
            }
        }
    }

    /// 4.4: قائمة الخصائص كما راجعناها. كل خاصية فيها اختيارية أو لها قيمة افتراضية،
    /// ويتحقّق من ذلك في الكود نفسه `scripts/check-cloudkit-model.py` في سير العمل.
    /// فأي خاصية تُضاف لاحقاً تُفشل هذا الاختبار حتى تُراجَع هنا وفي الترحيل.
    func test_4_4_attributeInventoryIsReviewed() throws {
        let expected: [String: Set<String>] = [
            "HizbPlacement": ["hizb", "trackRaw", "addedAt", "removedAt"],
            "QuarterReading": ["quarter", "readAt", "trackRaw"],
            "PageCompletion": ["page", "completedAt"],
            "ReviewCycle": ["trackRaw", "startedAt", "endedAt", "endReasonRaw"],
        ]
        var seen: [String: Set<String>] = [:]
        for entity in Persistence.schema.entities {
            seen[entity.name] = Set(entity.attributes.map(\.name))
        }
        XCTAssertEqual(seen, expected)
    }

    /// 4.4: المزامنة غير مفعّلة قبل ش7.
    func test_4_4_cloudKitIsOffUntilSlice7() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        for configuration in container.configurations {
            XCTAssertEqual(configuration.cloudKitContainerIdentifier, nil)
        }
    }

    // MARK: 4.3 · لا يضيع السجلّ

    /// 4.3: ما حُفظ يبقى بعد إغلاق المخزن وفتحه من جديد.
    func test_4_3_recordsSurviveReopeningTheStore() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")
        let when = Date(timeIntervalSince1970: 1_762_675_200) // 9 نوفمبر 2025 · 08:00 UTC
        do {
            let context = ModelContext(try Persistence.makeContainer(url: url))
            context.insert(HizbPlacement(hizb: 9, track: .farReview, addedAt: when))
            context.insert(QuarterReading(quarter: 33, readAt: when, track: .farReview))
            context.insert(PageCompletion(page: 22, completedAt: when))
            context.insert(ReviewCycle(track: .farReview, startedAt: when))
            try context.save()
        }
        let context = ModelContext(try Persistence.makeContainer(url: url))
        let readings = try context.fetch(FetchDescriptor<QuarterReading>())
        XCTAssertEqual(readings.map(\.quarter), [33])
        XCTAssertEqual(readings.first?.readAt, when)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HizbPlacement>()).first?.hizb, 9)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PageCompletion>()).first?.page, 22)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewCycle>()).first?.track, .farReview)
    }

    /// 5.3: التظليل يُحفظ بتاريخه ووقته كاملين، والتظليلات المتعدّدة للربع كلها محفوظة.
    func test_5_3_readingKeepsFullDateAndTime() throws {
        let context = try memoryContext()
        let first = Date(timeIntervalSince1970: 1_762_675_200.5)
        let second = first.addingTimeInterval(86_400 * 3 + 125)
        context.insert(QuarterReading(quarter: 5, readAt: first))
        context.insert(QuarterReading(quarter: 5, readAt: second))
        try context.save()
        let dates = try context.fetch(FetchDescriptor<QuarterReading>(sortBy: [SortDescriptor(\.readAt)])).map(\.readAt)
        XCTAssertEqual(dates, [first, second])
    }

    /// 5.1 · 5.2: إزالة الحزب أو نقله يُغلق صفّه ولا يمسّ تظليلاته، فيعود عمره كما كان.
    func test_5_1_removingOrMovingHizbKeepsItsReadings() throws {
        let context = try memoryContext()
        let placement = HizbPlacement(hizb: 9, track: .nearReview)
        context.insert(placement)
        context.insert(QuarterReading(quarter: 33, track: .nearReview))
        try context.save()

        // نقل إلى البعيد: يُغلق القديم ويُفتح جديد.
        placement.removedAt = .now
        context.insert(HizbPlacement(hizb: 9, track: .farReview))
        try context.save()

        let placements = try context.fetch(FetchDescriptor<HizbPlacement>())
        XCTAssertEqual(placements.count, 2, "النقل يحفظ الصفّ القديم تاريخاً")
        XCTAssertEqual(placements.filter(\.isActive).map(\.track), [.farReview])
        XCTAssertEqual(try context.fetch(FetchDescriptor<QuarterReading>()).map(\.quarter), [33])
    }

    /// 5.6: إتمام الوجه بتاريخه، ويبقى بعد رفع الحزب إلى القريب.
    func test_5_6_pageCompletionSurvivesPromotion() throws {
        let context = try memoryContext()
        let current = HizbPlacement(hizb: 10, track: .newMemorization)
        context.insert(current)
        context.insert(PageCompletion(page: 92))
        try context.save()

        current.removedAt = .now
        context.insert(HizbPlacement(hizb: 10, track: .nearReview))
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<PageCompletion>()).map(\.page), [92])
    }

    /// 3: المسارات بأسمائها الملزمة، ولا «القديم».
    func test_3_trackTitles() {
        XCTAssertEqual(Track.allCases.map(\.title), ["مراجعة البعيد", "مراجعة القريب", "المحفوظ الجديد"])
        XCTAssertFalse(Track.allCases.contains { $0.title.contains("القديم") })
    }
}
