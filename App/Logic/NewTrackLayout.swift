import Foundation

/// ما يُرسم للمحفوظ الجديد في الشاشة الرئيسية (5.6، 7.1، system.md §15.2). منطق خالص بلا واجهة.
///
/// أحزاب الجديد: «الحزب الذي أحفظ فيه الآن» (صفوف `HizbPlacement` المفتوحة بمسار `new`).
/// وأوجهها مربّعات بأرقام المصحف، والوجه المتمّ ما له `PageCompletion` (بالوجه لا بالحزب).
struct NewTrackLayout: Equatable, Sendable {
    /// أحزاب الجديد مرتّبة تصاعدياً بلا تكرار.
    let hizbs: [Int]
    /// الأوجه المتمّة، في أيّ يوم.
    let completed: Set<Int>
    /// الأوجه المتمّة اليوم، لعلامة «اليوم».
    let today: Set<Int>

    init(hizbs: [Int], completed: Set<Int> = [], today: Set<Int> = []) {
        self.hizbs = Array(Set(hizbs)).sorted()
        self.completed = completed
        self.today = today
    }

    var isEmpty: Bool { hizbs.isEmpty }

    /// أوجه أحزاب الجديد بلا تكرار: الوجه المشترك بين حزبين فيه يُعدّ مرة (§15.2، ذ37).
    var pages: [Int] { Array(Set(hizbs.flatMap(Quran.pages(ofHizb:)))).sorted() }

    var doneCount: Int { pages.filter(completed.contains).count }

    /// التقدّم في الرأس: «5 من 10» (§15.2).
    var progressText: String { "\(Digits.en(doneCount)) من \(Digits.en(pages.count))" }

    /// موضع التوقّف (5.6، §15.3): أول وجه لم يتمّ، في أول حزب (بترتيب الأحزاب) بقي فيه وجه.
    /// يُحسب ولا يُخزَّن. و`nil` إن أُتمّت أوجه الأحزاب كلها.
    var bookmark: (hizb: Int, page: Int)? {
        for hizb in hizbs {
            if let page = Quran.pages(ofHizb: hizb).first(where: { !completed.contains($0) }) { return (hizb, page) }
        }
        return nil
    }

    var bookmarkPage: Int? { bookmark?.page }
    var bookmarkHizb: Int? { bookmark?.hizb }

    /// الحزب الذي تُطوى عليه البطاقة: حزب موضع التوقّف، وإلا أول حزب.
    var foldedHizb: Int? { bookmarkHizb ?? hizbs.first }

    /// صفّ الأوجه الخمسة المطويّ (§15.2): الصفوف تُعدّ من أول أوجه الحزب خمسةً خمسة،
    /// وآخرها يُكمل من الذي قبله حتى يكون خمسة. والصفّ الذي فيه موضع التوقّف، وإلا آخر صفّ.
    func foldedRow(hizb: Int?) -> FiveRow? {
        guard let hizb, hizbs.contains(hizb) else { return nil }
        let list = Quran.pages(ofHizb: hizb)
        let index = bookmark.flatMap { $0.hizb == hizb ? list.firstIndex(of: $0.page) : nil } ?? list.count - 1
        let start = Self.rowStart(index: index, count: list.count)
        return FiveRow(hizb: hizb, pages: Array(list[start..<min(start + 5, list.count)]))
    }

    var foldedRow: FiveRow? { foldedRow(hizb: foldedHizb) }

    /// أول الصفّ الذي فيه الوجه رقم `index` من أوجه الحزب: مضاعف الخمسة، وآخر صفّ يُكمل ممّا قبله.
    static func rowStart(index: Int, count: Int) -> Int {
        max(0, min(index / 5 * 5, count - 5))
    }

    /// أوجه الحزب كلها صفوفاً خمسة خمسة، في الأرشيف (§15.3): آخرها يُكمل من الذي قبله.
    static func rows(ofHizb hizb: Int) -> [[Int]] {
        let list = Quran.pages(ofHizb: hizb)
        guard list.count > 5 else { return [list] }
        return stride(from: 0, to: list.count, by: 5).map { i in
            let start = rowStart(index: i, count: list.count)
            return Array(list[start..<(start + 5)])
        }
    }

    /// سطر الحزب بعد «ح 12» (§15.2، ذ28): «· المائدة · الجزء 6». والسورتان بأسمائهما،
    /// وأكثر «أولها ← آخرها»: «· الأعلى ← الناس · الجزء 30».
    static func hizbLine(_ hizb: Int) -> String {
        let suras = Quran.suras(ofHizb: hizb).map(Quran.suraName)
        let text = suras.count > 2 ? "\(suras[0]) ← \(suras[suras.count - 1])" : suras.joined(separator: " · ")
        return "· \(text) · الجزء \(Digits.en(Quran.juz(ofHizb: hizb)))"
    }

    /// تسمية الوجه لقارئ الشاشة (§15.8): «الوجه 117، لم يُحفظ، موضع التوقّف».
    func pageLabel(_ page: Int) -> String {
        "الوجه \(Digits.en(page))، " + (completed.contains(page) ? "محفوظ" : "لم يُحفظ")
            + (today.contains(page) ? "، أتممته اليوم" : "")
            + (page == bookmarkPage && Slice.showsBookmark ? "، موضع التوقّف" : "")
    }
}

/// صفّ أوجه خمسة من حزب، أو أقلّ إن قلّت أوجهه.
struct FiveRow: Equatable, Sendable {
    let hizb: Int
    let pages: [Int]
}
