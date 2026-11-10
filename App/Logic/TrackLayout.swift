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
        return FoldedRow(hizb: hizb, quarters: qs, suras: suras, juz: Quran.juz(ofHizb: hizb))
    }

    /// صفوف الأرشيف (7.1). في هذه المرحلة صفّ لكل حزب بأرباعه الأربعة، ووسم الجزء عند أول حزب فيه.
    /// وتقسيمها إلى أقسام السور (7.1.1) في المرحلة التالية.
    var archiveRows: [ArchiveRow] {
        var seenJuz = Set<Int>()
        return hizbs.map { hizb in
            let juz = Quran.juz(ofHizb: hizb)
            let firstInJuz = seenJuz.insert(juz).inserted
            return ArchiveRow(hizb: hizb, quarters: Quran.quarters(ofHizb: hizb), juzTag: firstInJuz ? juz : nil)
        }
    }
}

struct FoldedRow: Equatable, Sendable {
    let hizb: Int
    let quarters: [Int]
    /// السور التي تمسّها أرباع الحزب، بالترتيب.
    let suras: [Int]
    let juz: Int

    /// سطور اسم السورة بجانب الصفّ (م19): سورة واحدة سطر واحد، وسورتان سطران،
    /// وأكثر من اثنتين «أولها ←» ثم «آخرها»، فلا يُقطع الاسم.
    var suraLines: [String] {
        let names = suras.map(Quran.suraName)
        guard names.count > 2, let first = names.first, let last = names.last else { return names }
        return ["\(first) ←", last]
    }

    var juzText: String { "الجزء \(Digits.en(juz))" }
}

struct ArchiveRow: Equatable, Sendable, Identifiable {
    let hizb: Int
    let quarters: [Int]
    /// رقم الجزء إن كان هذا أول حزب منه في المسار، فيظهر وسماً صغيراً (7.1.1).
    let juzTag: Int?
    var id: Int { hizb }
}

/// الأرقام إنجليزية في كل الشاشات (القرار 1، م4). كل رقم يُكتب في الواجهة يمرّ من هنا،
/// ولا يُترك لتنسيق اللغة العربية الذي قد يكتبه بالأرقام المشرقية.
enum Digits {
    static func en(_ n: Int) -> String { String(n) }
    /// «ح 12»
    static func hizbLabel(_ hizb: Int) -> String { "ح \(en(hizb))" }
}
