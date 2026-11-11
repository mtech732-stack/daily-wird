import Foundation
import SwiftData

/// المحفوظ: أي حزب في أي مسار، مقروءاً من صفوف `HizbPlacement` (5.1، 5.2).
/// منطق خالص بلا واجهة، تختبره اختبارات الوحدة.
///
/// الحزب لا يكون في مسارين معاً (5.1). والقاعدة تُفرض هنا في المنطق لا في البنية،
/// لأن CloudKit لا يقبل قيود التفرّد (4.4). وقد تأتي المزامنة بصفّين مفتوحين للحزب نفسه
/// من جهازين (م18): فيُؤخذ الأحدث إضافةً، ولا يُحذف شيء.
enum Library {
    /// المسار الذي فيه كل حزب الآن: صفّه المفتوح الأحدث إضافةً (م18).
    static func trackOfHizb(from placements: [HizbPlacement]) -> [Int: Track] {
        var map: [Int: (track: Track, at: Date)] = [:]
        for p in placements where p.removedAt == nil {
            guard let track = p.track, (1...Quran.hizbCount).contains(p.hizb) else { continue }
            if let current = map[p.hizb], current.at >= p.addedAt { continue }
            map[p.hizb] = (track, p.addedAt)
        }
        return map.mapValues(\.track)
    }

    /// أحزاب المسار الآن، مرتّبة تصاعدياً بلا تكرار. فلا يظهر حزب في مسارين ولو تكرّر صفّه.
    static func activeHizbs(in track: Track, from placements: [HizbPlacement]) -> [Int] {
        trackOfHizb(from: placements).filter { $0.value == track }.map(\.key).sorted()
    }

    /// ما في الاختيار من أحزاب موجودة في مسار آخر، فيُسأل عنها: «الحزب موجود في [المسار]. أتنقله؟» (5.1).
    static func conflicts(_ selection: [Int], with track: Track, placements: [HizbPlacement]) -> [Int] {
        let current = trackOfHizb(from: placements)
        return Array(Set(selection)).sorted().filter { current[$0] != nil && current[$0] != track }
    }

    /// ما يُضاف فعلاً من اختيار المالك إلى مسار (5.1): يُترك ما هو فيه أصلاً،
    /// ولا يُنقل ما في مسار آخر إلا إن أجاب المالك بالنقل.
    static func hizbsToAdd(_ selection: [Int], to track: Track, placements: [HizbPlacement], moving: Bool = false) -> [Int] {
        let current = trackOfHizb(from: placements)
        return Array(Set(selection)).sorted().filter { hizb in
            guard (1...Quran.hizbCount).contains(hizb) else { return false }
            guard let at = current[hizb] else { return true }
            return moving && at != track
        }
    }

    /// يضيف إلى مسار الأحزاب المختارة (جزء كامل = حزباه، أو حزب واحد) (5.1)،
    /// أو إلى المحفوظ الجديد الحزب الذي يُحفظ الآن (5.6، §15.1).
    /// كل حزب صفّ مفتوح بتاريخ الإضافة ووقتها. وما كان في مسار آخر لا يُنقل إلا إن كان `moving`:
    /// فيُغلق صفّه هناك (لا يُحذف) ويُفتح صفّ هنا، وسجلّ تظليلاته باقٍ لأنه بالربع لا بالمسار (5.2).
    /// ويعيد ما أُضيف أو نُقل.
    @discardableResult
    static func add(_ selection: [Int], to track: Track, in context: ModelContext,
                    moving: Bool = false, now: Date = .now) throws -> [Int] {
        let placements = try context.fetch(FetchDescriptor<HizbPlacement>())
        let list = hizbsToAdd(selection, to: track, placements: placements, moving: moving)
        let set = Set(list)
        for p in placements where p.removedAt == nil && set.contains(p.hizb) {
            p.removedAt = now
        }
        for hizb in list { context.insert(HizbPlacement(hizb: hizb, track: track, addedAt: now)) }
        // الدورة لمسارَي المراجعة وحدهما (5.5).
        if !list.isEmpty && track.isReview { try Cycles.startIfNeeded(track, in: context, now: now) }
        try context.save()
        // ما نُقل من مسار آخر قد يفرغه أو يتمّ دورته (§14.4، §14.6).
        if !list.isEmpty { try settleReviews(in: context, now: now) }
        return list
    }

    /// تسوية ما جاءت به المزامنة (م18): إن بقي للحزب أكثر من صفّ مفتوح، أُغلق ما سوى الأحدث
    /// بتاريخ الأحدث. لا يُحذف صفّ، فيبقى تاريخ المسارات كاملاً. ويعيد عدد ما أُغلق.
    @discardableResult
    static func reconcile(in context: ModelContext) throws -> Int {
        let open = try context.fetch(FetchDescriptor<HizbPlacement>()).filter { $0.removedAt == nil }
        var closed = 0
        for (_, rows) in Dictionary(grouping: open, by: \.hizb) where rows.count > 1 {
            let sorted = rows.sorted { $0.addedAt > $1.addedAt }
            for stale in sorted.dropFirst() {
                stale.removedAt = sorted[0].addedAt
                closed += 1
            }
        }
        if closed > 0 { try context.save() }
        return closed
    }

    // MARK: النقل والإزالة (5.1، 5.2، §12.5)

    /// وجهتا النقل من كل مسار بترتيبهما في القائمة والورقة (§15.6، ذ32): الأقرب في طريق المالك أولاً،
    /// الجديد ← القريب ← البعيد.
    static func destinations(from track: Track) -> [Track] {
        switch track {
        case .farReview: [.nearReview, .newMemorization]
        case .nearReview: [.farReview, .newMemorization]
        case .newMemorization: [.nearReview, .farReview]
        }
    }

    /// متى خرج كل ربع من المحفوظ الجديد آخر مرة، لأحزابه التي كانت فيه (م49): الحزب المرفوع يدخل دورة
    /// المراجعة بأرباعه غير مظلّلة (5.6)، فلا يُعدّ في الدورة ما تُلي منه قبل خروجه من الجديد.
    static func leftNew(from placements: [HizbPlacement]) -> [Int: Date] {
        var hizbs: [Int: Date] = [:]
        for p in placements where p.track == .newMemorization {
            guard let end = p.removedAt else { continue }
            if let at = hizbs[p.hizb], at >= end { continue }
            hizbs[p.hizb] = end
        }
        var quarters: [Int: Date] = [:]
        for (hizb, at) in hizbs { for q in Quran.quarters(ofHizb: hizb) { quarters[q] = at } }
        return quarters
    }

    /// المسار الآخر من مسارَي المراجعة. وفي ش1 «المسار الآخر» واحد؛ والجديد في ش4.
    static func otherReviewTrack(_ track: Track) -> Track {
        track == .farReview ? .nearReview : .farReview
    }

    /// ينقل من مسار إلى آخر ما هو فيه الآن من الأحزاب المختارة، يدوياً بيد المالك (5.2):
    /// يُغلق صفّه المفتوح (لا يُحذف) ويُفتح صفّ في الوجهة. وسجلّ تظليلاته باقٍ لأنه بالربع.
    /// ويعيد ما نُقل.
    @discardableResult
    static func move(_ selection: [Int], from source: Track, to target: Track, in context: ModelContext,
                     now: Date = .now) throws -> [Int] {
        precondition(source != target, "النقل إلى مسار آخر")
        let placements = try context.fetch(FetchDescriptor<HizbPlacement>())
        let current = trackOfHizb(from: placements)
        let list = Array(Set(selection)).sorted().filter { current[$0] == source }
        let set = Set(list)
        for p in placements where p.removedAt == nil && set.contains(p.hizb) { p.removedAt = now }
        for hizb in list { context.insert(HizbPlacement(hizb: hizb, track: target, addedAt: now)) }
        // الدورة لمسارَي المراجعة وحدهما، والقريب الفارغ تبدأ دورته الأولى بالرفع (5.5، §15.5).
        if !list.isEmpty && target.isReview { try Cycles.startIfNeeded(target, in: context, now: now) }
        try context.save()
        if !list.isEmpty { try settleReviews(in: context, now: now) }
        return list
    }

    /// يزيل من مسار ما هو فيه الآن من الأحزاب المختارة، بعد تأكيد المالك (5.1):
    /// يُغلق صفّه ولا يُحذف، ولا يُمسّ سجلّ تظليلاته، فإن أُعيد ظهر عمره كما كان.
    /// ويعيد ما أُزيل.
    @discardableResult
    static func remove(_ selection: [Int], from track: Track, in context: ModelContext,
                       now: Date = .now) throws -> [Int] {
        let placements = try context.fetch(FetchDescriptor<HizbPlacement>())
        let current = trackOfHizb(from: placements)
        let list = Array(Set(selection)).sorted().filter { current[$0] == track }
        let set = Set(list)
        for p in placements where p.removedAt == nil && set.contains(p.hizb) { p.removedAt = now }
        try context.save()
        if !list.isEmpty { try settleReviews(in: context, now: now) }
        return list
    }

    /// بعد الإضافة والنقل والإزالة: إن فرغ المسار انتهت دورته، وإن خرج منه آخر ما لم يُظلَّل اكتملت (§14.4).
    private static func settleReviews(in context: ModelContext, now: Date) throws {
        for track in Track.allCases where track.isReview {
            try Cycles.settle(track, in: context, now: now)
        }
    }
}
