import Foundation

/// جدول الحدود القرآني (6.1): يُقرأ من `data/quran-boundaries.json` المضمّن في التطبيق،
/// ولا يُحسب ولا يُجلب (4.4). مُعدّ البيانات يملك الملف، والمهندس يقرؤه كما هو.
struct QuranTable: Decodable, Sendable {
    struct Page: Decodable, Sendable {
        let n: Int
        let first: [Int]
    }

    struct Quarter: Decodable, Sendable {
        let n: Int
        let hizb: Int
        let juz: Int
        let first: [Int]
        let last: [Int]
        let firstPage: Int
        let lastPage: Int
        /// السور التي يمسّها الربع، مرتّبة.
        let suras: [Int]
    }

    struct Sura: Decodable, Sendable {
        let n: Int
        let name: String
        let ayas: Int
        let firstQuarter: Int
        let lastQuarter: Int
    }

    let format: Int
    let pages: [Page]
    let quarters: [Quarter]
    let suras: [Sura]
}

/// الوصول إلى الجدول بأرقام الربع (1–240) والحزب (1–60) والجزء (1–30) والسورة (1–114).
enum Quran {
    static let hizbCount = 60
    static let juzCount = 30
    static let quarterCount = 240

    /// الجدول المضمّن. إن تعذّرت قراءته توقّف التطبيق: لا يُبنى شيء على جدول ناقص (6.3).
    static let table: QuranTable = {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "quran-boundaries", withExtension: "json") else {
            fatalError("جدول الحدود غير مضمّن في التطبيق")
        }
        do {
            return try JSONDecoder().decode(QuranTable.self, from: Data(contentsOf: url))
        } catch {
            fatalError("تعذّرت قراءة جدول الحدود: \(error)")
        }
    }()

    static func quarter(_ n: Int) -> QuranTable.Quarter { table.quarters[n - 1] }
    static func sura(_ n: Int) -> QuranTable.Sura { table.suras[n - 1] }
    static func suraName(_ n: Int) -> String { sura(n).name }

    /// أرباع الحزب الأربعة بالترتيب 1، 2، 3، 4 (5.3).
    static func quarters(ofHizb hizb: Int) -> [Int] { Array(((hizb - 1) * 4 + 1)...(hizb * 4)) }

    /// موضع الربع في حزبه: 1–4.
    static func position(ofQuarter quarter: Int) -> Int { (quarter - 1) % 4 + 1 }

    /// الجزء الذي فيه الحزب (كل جزء حزبان).
    static func juz(ofHizb hizb: Int) -> Int { quarter((hizb - 1) * 4 + 1).juz }

    /// حزبا الجزء.
    static func hizbs(ofJuz juz: Int) -> [Int] { [juz * 2 - 1, juz * 2] }

    /// السورة التي يبدأ بها الحزب (من أول ربع فيه)، عوناً على ربط الحزب بسورته (ذ3).
    static func firstSura(ofHizb hizb: Int) -> Int { quarter((hizb - 1) * 4 + 1).suras[0] }
}

private final class BundleToken {}
