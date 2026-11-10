import Foundation

/// حالة خانة الحزب في ورقة الإضافة (§12.2). تُقرأ بالشكل لا باللون.
enum HizbChipState: Equatable {
    /// متاح: حدّ.
    case available
    /// مختار: ممتلئ بصحّ.
    case selected
    /// في هذا المسار: محايد لا يُضغط.
    case here
    /// في مسار آخر: إطار متقطّع واسم ذلك المسار.
    case other(Track)
}

/// اختيار المالك في ورقة الإضافة (7.2): المسار، ثم الجزء كلّه بدائرته أو حزب منه.
struct AddSelection: Equatable {
    private(set) var track: Track
    private(set) var selected: Set<Int> = []
    /// المسار الذي فيه كل حزب الآن.
    let trackOf: [Int: Track]

    init(track: Track, trackOf: [Int: Track]) {
        self.track = track
        self.trackOf = trackOf
    }

    var sortedSelection: [Int] { selected.sorted() }

    func state(of hizb: Int) -> HizbChipState {
        if trackOf[hizb] == track { return .here }
        if selected.contains(hizb) { return .selected }
        if let at = trackOf[hizb] { return .other(at) }
        return .available
    }

    /// يُختار كل حزب ليس في هذا المسار. والذي في مسار آخر يُسأل عن نقله عند «أضف» (5.1، ذ5).
    func isPickable(_ hizb: Int) -> Bool { trackOf[hizb] != track }

    /// المختار من أحزاب مسار آخر، والمسار الذي هي فيه.
    var conflicts: [Int] { sortedSelection.filter { trackOf[$0] != nil && trackOf[$0] != track } }
    var conflictTrack: Track? { conflicts.first.flatMap { trackOf[$0] } }

    func pickable(inJuz juz: Int) -> [Int] { Quran.hizbs(ofJuz: juz).filter(isPickable) }

    /// دائرة الجزء ممتلئة حين يُختار كل ما يُختار من حزبيه.
    func isJuzSelected(_ juz: Int) -> Bool {
        let can = pickable(inJuz: juz)
        return !can.isEmpty && can.allSatisfy(selected.contains)
    }

    mutating func toggle(_ hizb: Int) {
        guard isPickable(hizb) else { return }
        if selected.contains(hizb) { selected.remove(hizb) } else { selected.insert(hizb) }
    }

    /// الجزء كاملاً: يختار حزبيه أو يلغيهما.
    mutating func toggleJuz(_ juz: Int) {
        let can = pickable(inJuz: juz)
        guard !can.isEmpty else { return }
        if isJuzSelected(juz) { can.forEach { selected.remove($0) } } else { can.forEach { selected.insert($0) } }
    }

    /// تغيير المسار يمحو الاختيار (§12.2).
    mutating func setTrack(_ newTrack: Track) {
        guard newTrack != track else { return }
        track = newTrack
        selected = []
    }
}
