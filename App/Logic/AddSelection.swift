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
        if let at = trackOf[hizb] { return at == track ? .here : .other(at) }
        return selected.contains(hizb) ? .selected : .available
    }

    /// يُختار الحزب الذي ليس في أي مسار. والحزب الذي في مسار آخر لا يُضاف حتى يُسأل عن نقله (5.1).
    func isPickable(_ hizb: Int) -> Bool { trackOf[hizb] == nil }

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
