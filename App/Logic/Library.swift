import Foundation
import SwiftData

/// المحفوظ: أي حزب في أي مسار، مقروءاً من صفوف `HizbPlacement` (5.1، 5.2).
/// منطق خالص بلا واجهة، تختبره اختبارات الوحدة.
enum Library {
    /// أحزاب المسار الآن، مرتّبة تصاعدياً بلا تكرار.
    /// الصفّ المفتوح (`removedAt == nil`) يعني أن الحزب في المسار.
    static func activeHizbs(in track: Track, from placements: [HizbPlacement]) -> [Int] {
        let hizbs = placements
            .filter { $0.trackRaw == track.rawValue && $0.removedAt == nil && (1...Quran.hizbCount).contains($0.hizb) }
            .map(\.hizb)
        return Array(Set(hizbs)).sorted()
    }

    /// المسار الذي فيه كل حزب الآن.
    static func trackOfHizb(from placements: [HizbPlacement]) -> [Int: Track] {
        var map: [Int: (Track, Date)] = [:]
        for p in placements where p.removedAt == nil {
            guard let track = p.track, (1...Quran.hizbCount).contains(p.hizb) else { continue }
            if let current = map[p.hizb], current.1 >= p.addedAt { continue }
            map[p.hizb] = (track, p.addedAt)
        }
        return map.mapValues(\.0)
    }

    /// ما يُضاف فعلاً من اختيار المالك إلى مسار (5.1): يُترك ما هو فيه أصلاً،
    /// ولا يُضاف حزب في مسار آخر، فالحزب لا يكون في مسارين معاً.
    static func hizbsToAdd(_ selection: [Int], to track: Track, placements: [HizbPlacement]) -> [Int] {
        let current = trackOfHizb(from: placements)
        return Array(Set(selection)).sorted().filter { (1...Quran.hizbCount).contains($0) && current[$0] == nil }
    }

    /// يضيف إلى مسار مراجعة الأحزاب المختارة (جزء كامل = حزباه، أو حزب واحد) (5.1)،
    /// بصفّ مفتوح لكل حزب بتاريخ الإضافة ووقتها. ويعيد ما أُضيف.
    @discardableResult
    static func add(_ selection: [Int], to track: Track, in context: ModelContext, now: Date = .now) throws -> [Int] {
        precondition(track.isReview, "الإضافة بالجزء أو الحزب لمسارَي المراجعة (5.1)")
        let placements = try context.fetch(FetchDescriptor<HizbPlacement>())
        let list = hizbsToAdd(selection, to: track, placements: placements)
        for hizb in list { context.insert(HizbPlacement(hizb: hizb, track: track, addedAt: now)) }
        try context.save()
        return list
    }
}
