import Foundation
import SwiftData

/// الدورة وموضع التوقّف في مسارَي المراجعة (5.5، design/system.md §14.1–14.2).
/// لكل مسار دورة حالية (`endedAt == nil`) تبدأ حين يُضاف إليه أول حزب. والتظليل في الدورة
/// إن كان بعد بدايتها بالتاريخ والوقت. وموضع التوقّف لا يُخزَّن، بل يُحسب.
enum Cycles {
    /// الدورة الحالية للمسار: الأحدث بدايةً من غير المنتهية.
    static func current(_ track: Track, in cycles: [ReviewCycle]) -> ReviewCycle? {
        cycles.filter { $0.track == track && $0.isCurrent }.max { $0.startedAt < $1.startedAt }
    }

    /// أرباع المسار المظلّلة في الدورة: لها تظليل في بدايتها أو بعدها.
    /// والربع المشترك ربع واحد برقمه، فلا يُعدّ مرتين.
    static func done(quarters: [Int], readings: [QuarterReading], since start: Date?) -> Set<Int> {
        guard let start else { return [] }
        let set = Set(quarters)
        return Set(readings.lazy.filter { set.contains($0.quarter) && $0.readAt >= start }.map(\.quarter))
    }

    /// تبدأ دورة لكل مسار مراجعة فيه أحزاب ولا دورة حالية له، من أقدم إضافة لأحزابه الحالية.
    /// للبيانات التي سبقت ش3، ولما جاءت به المزامنة. ويعيد ما بدأ.
    @discardableResult
    static func ensure(in context: ModelContext) throws -> [Track] {
        let placements = try context.fetch(FetchDescriptor<HizbPlacement>()).filter { $0.removedAt == nil }
        let cycles = try context.fetch(FetchDescriptor<ReviewCycle>())
        var started: [Track] = []
        for track in Track.allCases where track.isReview && current(track, in: cycles) == nil {
            let rows = placements.filter { $0.track == track }
            guard let first = rows.map(\.addedAt).min() else { continue }
            context.insert(ReviewCycle(track: track, startedAt: first))
            started.append(track)
        }
        if !started.isEmpty { try context.save() }
        return started
    }

    /// يبدأ دورة المسار عند إضافة أول حزب إليه، إن لم تكن له دورة حالية (5.5).
    static func startIfNeeded(_ track: Track, in context: ModelContext, now: Date) throws {
        let cycles = try context.fetch(FetchDescriptor<ReviewCycle>())
        guard current(track, in: cycles) == nil else { return }
        context.insert(ReviewCycle(track: track, startedAt: now))
    }
}
