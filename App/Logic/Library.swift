import Foundation

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
}
