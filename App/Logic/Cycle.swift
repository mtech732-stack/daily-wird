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

    /// أرباع المسار المظلّلة في الدورة: لها تظليل بعد بدايتها (وإلى نهايتها إن انتهت).
    /// والحدّ صارم: التظليل الذي أتمّ دورة في لحظة بداية التالية، فهو للمنتهية وحدها (§14.4، م40).
    /// والربع المشترك ربع واحد برقمه، فلا يُعدّ مرتين.
    static func done(quarters: [Int], readings: [QuarterReading], since start: Date?, until end: Date? = nil) -> Set<Int> {
        guard let start else { return [] }
        let set = Set(quarters)
        return Set(readings.lazy.filter { reading in
            set.contains(reading.quarter) && reading.readAt > start && (end.map { reading.readAt <= $0 } ?? true)
        }.map(\.quarter))
    }

    /// الدورة التي اكتملت فبدأت الحالية في لحظة اكتمالها، إن كان ذلك اليوم (§14.4).
    static func justCompleted(_ track: Track, in cycles: [ReviewCycle], now: Date,
                              calendar: Calendar = WirdDate.calendar()) -> ReviewCycle? {
        guard let current = current(track, in: cycles) else { return nil }
        return cycles.first {
            $0.track == track && $0.endReasonRaw == CycleEnd.completed.rawValue && $0.endedAt == current.startedAt
                && calendar.isDate(current.startedAt, inSameDayAs: now)
        }
    }

    /// أيام الدورة من يوم بدايتها إلى يوم اكتمالها محسوبين معاً (ذ23).
    static func days(from start: Date, to end: Date, calendar: Calendar = WirdDate.calendar()) -> Int {
        let a = calendar.startOfDay(for: start), b = calendar.startOfDay(for: end)
        return (calendar.dateComponents([.day], from: a, to: b).day ?? 0) + 1
    }

    /// سطر الاكتمال (ذ19): أيام الدورة التي اكتملت اليوم، ما دام لم يُظلَّل في الجديدة شيء.
    /// ويذهب بأول تظليل فيها أو بمنتصف الليل، ويبقى إن أُغلق التطبيق وفُتح في اليوم نفسه.
    static func completedDays(_ track: Track, quarters: [Int], cycles: [ReviewCycle], readings: [QuarterReading],
                              now: Date, calendar: Calendar = WirdDate.calendar()) -> Int? {
        guard let previous = justCompleted(track, in: cycles, now: now, calendar: calendar),
              let end = previous.endedAt,
              done(quarters: quarters, readings: readings, since: end).isEmpty else { return nil }
        return days(from: previous.startedAt, to: end, calendar: calendar)
    }

    /// ما جرى للدورة بعد تغيّر في المسار.
    enum Change: Equatable, Sendable {
        case none
        /// اكتملت الدورة في هذه الأيام، وبدأت غيرها.
        case completed(days: Int)
        /// تراجع المالك في يوم الاكتمال عن تظليل في الدورة المكتملة، فعادت كما كانت.
        case restored
    }

    /// ضغطة على ربع (5.3) ثم ما يتبعها في دورات مسارَي المراجعة: الاكتمال، أو الاستعادة بالتراجع.
    static func tap(quarter: Int, track: Track, in context: ModelContext, now: Date,
                    calendar: Calendar = WirdDate.calendar()) throws -> (Shading.TapResult, [Track: Change]) {
        let q = quarter
        let todays = try context.fetch(FetchDescriptor<QuarterReading>(predicate: #Predicate<QuarterReading> { $0.quarter == q }))
            .filter { calendar.isDate($0.readAt, inSameDayAs: now) }.map(\.readAt)
        let result = try Shading.tap(quarter: quarter, track: track, in: context, now: now, calendar: calendar)
        var changes: [Track: Change] = [:]
        for review in Track.allCases where review.isReview {
            changes[review] = try settle(review, in: context, now: now, undone: result == .undone ? todays : [],
                                         calendar: calendar)
        }
        return (result, changes)
    }

    /// يسوّي دورة المسار بعد تغيّر (§14.4، §14.6):
    /// - إن فرغ المسار انتهت دورته بلا اكتمال، وتبدأ أول إضافة بعده دورة جديدة (م40).
    /// - إن تراجع المالك اليوم عن تظليل كان في الدورة التي اكتملت اليوم عادت تلك الدورة كما كانت،
    ///   وحُذفت التي بدأت باكتمالها.
    /// - إن ظُلّل كل ربع في المسار في الدورة انتهت مكتملةً، وبدأت غيرها من هذه اللحظة.
    @discardableResult
    static func settle(_ track: Track, in context: ModelContext, now: Date, undone: [Date] = [],
                       calendar: Calendar = WirdDate.calendar()) throws -> Change {
        let placements = try context.fetch(FetchDescriptor<HizbPlacement>())
        let cycles = try context.fetch(FetchDescriptor<ReviewCycle>())
        let hizbs = Library.activeHizbs(in: track, from: placements)
        guard let current = current(track, in: cycles) else { return .none }
        if hizbs.isEmpty {
            current.endedAt = now
            current.endReasonRaw = CycleEnd.emptied.rawValue
            try context.save()
            return .none
        }
        let quarters = hizbs.flatMap(Quran.quarters(ofHizb:))
        let readings = try context.fetch(FetchDescriptor<QuarterReading>())
        if !undone.isEmpty, let previous = justCompleted(track, in: cycles, now: now, calendar: calendar),
           let end = previous.endedAt, undone.contains(where: { $0 > previous.startedAt && $0 <= end }),
           done(quarters: quarters, readings: readings, since: previous.startedAt, until: end).count < quarters.count {
            context.delete(current)
            previous.endedAt = nil
            previous.endReasonRaw = nil
            try context.save()
            return .restored
        }
        guard done(quarters: quarters, readings: readings, since: current.startedAt).count == quarters.count else {
            return .none
        }
        current.endedAt = now
        current.endReasonRaw = CycleEnd.completed.rawValue
        context.insert(ReviewCycle(track: track, startedAt: now))
        try context.save()
        return .completed(days: days(from: current.startedAt, to: now, calendar: calendar))
    }

    /// «ابدأ دورة جديدة» (§14.5، ذ21): تنتهي الحالية بيد المالك وتبدأ غيرها من هذه اللحظة، بلا سطر اكتمال.
    static func restart(_ track: Track, in context: ModelContext, now: Date) throws {
        let cycles = try context.fetch(FetchDescriptor<ReviewCycle>())
        if let current = current(track, in: cycles) {
            current.endedAt = now
            current.endReasonRaw = CycleEnd.manual.rawValue
        }
        context.insert(ReviewCycle(track: track, startedAt: now))
        try context.save()
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
