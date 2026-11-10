import Foundation

/// ما يُرسم لمسار مراجعة واحد في الشاشة الرئيسية (7.1). منطق خالص بلا واجهة.
struct ReviewTrackLayout: Equatable, Sendable {
    let track: Track
    /// أحزاب المسار مرتّبة تصاعدياً بلا تكرار.
    let hizbs: [Int]

    init(track: Track, hizbs: [Int]) {
        self.track = track
        self.hizbs = Array(Set(hizbs)).sorted()
    }

    var isEmpty: Bool { hizbs.isEmpty }

    /// أرباع المسار مرتّبة تصاعدياً بأرقامها، من أول المصحف إلى آخره (5.5).
    var quarters: [Int] { hizbs.flatMap(Quran.quarters(ofHizb:)) }

    /// موضع التوقّف (5.5): أول ربع بالترتيب لم يُظلَّل منذ بداية الدورة الحالية.
    /// في ش1 لا تظليل بعدُ (يأتي في ش2)، فهو أول ربع في المسار. وحسابه من الدورة في ش3.
    var bookmarkQuarter: Int? { quarters.first }

    /// الحزب الذي فيه موضع التوقّف: تُطوى عليه البطاقة (7.1).
    var bookmarkHizb: Int? { bookmarkQuarter.map { Quran.quarter($0).hizb } }

    /// تقدّم الدورة «[ما ظُلّل] من [عدد الأرباع]» (7.1). لا تظليل في ش1، فهو «0 من …».
    var progressText: String { "\(Digits.en(0)) من \(Digits.en(quarters.count))" }

    /// الصفّ المطويّ: حزب موضع التوقّف بأرباعه الأربعة، وسورته أو سورتاه، ووسم جزئه (7.1).
    var foldedRow: FoldedRow? {
        guard let hizb = bookmarkHizb else { return nil }
        let qs = Quran.quarters(ofHizb: hizb)
        var suras: [Int] = []
        for q in qs { for s in Quran.quarter(q).suras where !suras.contains(s) { suras.append(s) } }
        // الربع المشترك في الصفّ المطويّ: يظهر في قسمين في الأرشيف، ويمتدّ بين سورتين.
        let shared = sharedQuarters.filter { qs.contains($0) && Quran.quarter($0).suras.count > 1 }
        return FoldedRow(hizb: hizb, quarters: qs, suras: suras, juz: Quran.juz(ofHizb: hizb), shared: shared)
    }

    /// أقسام السور في الأرشيف (7.1.1):
    /// - قسم لكل سورة فيها ربع من المسار، وتحته صفوف أحزابها، ولا يظهر في الصفّ إلا أرباعها.
    /// - السور المتجاورة التي تقع كلها في الأرباع نفسها تُجمع في قسم واحد (جزء عمّ).
    /// - الربع الذي يظهر في أكثر من قسم «مشترك» (ت8).
    /// - وسم الجزء عند أول حزب منه في المسار.
    var sections: [SuraSection] {
        var bySura: [Int: [Int]] = [:]
        for q in quarters { for s in Quran.quarter(q).suras { bySura[s, default: []].append(q) } }
        var groups: [(suras: [Int], quarters: [Int])] = []
        for sura in bySura.keys.sorted() {
            let qs = bySura[sura]!
            if let last = groups.last, last.quarters == qs, last.suras.last == sura - 1 {
                groups[groups.count - 1].suras.append(sura)
            } else {
                groups.append(([sura], qs))
            }
        }
        var seen: [Int: Int] = [:]
        for g in groups { for q in g.quarters { seen[q, default: 0] += 1 } }
        var seenJuz = Set<Int>()
        let bookmark = bookmarkQuarter
        return groups.map { g in
            var hizbOrder: [Int] = []
            for q in g.quarters {
                let h = Quran.quarter(q).hizb
                if !hizbOrder.contains(h) { hizbOrder.append(h) }
            }
            let inSection = Set(g.quarters)
            let rows = hizbOrder.map { hizb -> SectionRow in
                let juz = Quran.juz(ofHizb: hizb)
                let slots = Quran.quarters(ofHizb: hizb).map { q in inSection.contains(q) ? q : nil }
                let isBookmarkRow = bookmark.map { inSection.contains($0) && Quran.quarter($0).hizb == hizb } ?? false
                return SectionRow(hizb: hizb, slots: slots, juzTag: seenJuz.insert(juz).inserted ? juz : nil,
                                  hasBookmark: isBookmarkRow)
            }
            return SuraSection(suras: g.suras, rows: rows,
                               shared: Set(g.quarters.filter { (seen[$0] ?? 0) > 1 }))
        }
    }

    /// الأرباع المشتركة في المسار: تظهر في أكثر من قسم (ت8).
    var sharedQuarters: Set<Int> { sections.reduce(into: Set<Int>()) { $0.formUnion($1.shared) } }
}

/// قسم سورة (أو سور قصيرة مجموعة) في الأرشيف (7.1.1).
struct SuraSection: Equatable, Sendable, Identifiable {
    let suras: [Int]
    let rows: [SectionRow]
    /// أرباع هذا القسم التي تظهر في قسم آخر أيضاً.
    let shared: Set<Int>
    var id: Int { suras[0] }

    /// «البقرة»، أو «النبأ · النازعات» للمجموعة.
    var title: String { suras.map(Quran.suraName).joined(separator: " · ") }

    /// مدى الأحزاب بخطّ صغير: «ح 5 ← ح 8»، أو «ح 5».
    var hizbRange: String {
        guard let first = rows.first?.hizb, let last = rows.last?.hizb else { return "" }
        return first == last ? Digits.hizbLabel(first) : "\(Digits.hizbLabel(first)) ← \(Digits.hizbLabel(last))"
    }
}

/// صفّ حزب في قسم سورة: أربع خانات في أماكنها الثابتة، وما ليس في السورة فراغ (`nil`).
struct SectionRow: Equatable, Sendable, Identifiable {
    let hizb: Int
    let slots: [Int?]
    let juzTag: Int?
    /// فيه موضع التوقّف، فتظهر علامة الكتاب بجانب رقمه.
    let hasBookmark: Bool
    var id: Int { hizb }
}

struct FoldedRow: Equatable, Sendable {
    let hizb: Int
    let quarters: [Int]
    /// السور التي تمسّها أرباع الحزب، بالترتيب.
    let suras: [Int]
    let juz: Int
    /// أرباع الصفّ المشتركة بين سورتين، فتُعلَّم بالزاوية المقطوعة (7.1.1).
    var shared: Set<Int> = []

    /// سطور اسم السورة بجانب الصفّ (م19): سورة واحدة سطر واحد، وسورتان سطران،
    /// وأكثر من اثنتين «أولها ←» ثم «آخرها»، فلا يُقطع الاسم.
    var suraLines: [String] {
        let names = suras.map(Quran.suraName)
        guard names.count > 2, let first = names.first, let last = names.last else { return names }
        return ["\(first) ←", last]
    }

    var juzText: String { "الجزء \(Digits.en(juz))" }
}

}

/// الأرقام إنجليزية في كل الشاشات (القرار 1، م4). كل رقم يُكتب في الواجهة يمرّ من هنا،
/// ولا يُترك لتنسيق اللغة العربية الذي قد يكتبه بالأرقام المشرقية.
enum Digits {
    static func en(_ n: Int) -> String { String(n) }
    /// «ح 12»
    static func hizbLabel(_ hizb: Int) -> String { "ح \(en(hizb))" }
}
