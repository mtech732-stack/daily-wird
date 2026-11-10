import Foundation

/// صياغة العدد مع المعدود في الإشعارات والأزرار والحوارات (§12.5، م20). الأرقام إنجليزية.
enum Phrase {
    /// منصوب، في الأزرار: «الحزب 9» · «حزبين» · «3 أحزاب» · «11 حزباً».
    static func hizbsAccusative(_ list: [Int]) -> String {
        switch list.count {
        case 1: "الحزب \(Digits.en(list[0]))"
        case 2: "حزبين"
        case 3...10: "\(Digits.en(list.count)) أحزاب"
        default: "\(Digits.en(list.count)) حزباً"
        }
    }

    /// مرفوع، في الإشعار: «ح 9» · «حزبان» · «3 أحزاب» · «11 حزباً».
    static func hizbsNominative(_ list: [Int]) -> String {
        switch list.count {
        case 1: Digits.hizbLabel(list[0])
        case 2: "حزبان"
        case 3...10: "\(Digits.en(list.count)) أحزاب"
        default: "\(Digits.en(list.count)) حزباً"
        }
    }

    /// الضمير العائد: ـه للواحد، وـهما للاثنين، وـها لما فوقهما.
    static func pronoun(_ count: Int) -> String {
        switch count {
        case 1: "ه"
        case 2: "هما"
        default: "ها"
        }
    }

    /// زرّ ورقة الإضافة (§12.2).
    static func addButton(_ list: [Int], to track: Track) -> String {
        list.isEmpty ? "اختر جزءاً أو حزباً" : "أضف \(hizbsAccusative(list)) إلى \(track.title)"
    }

    /// الإشعار بعد الإضافة (§12.2، §12.6).
    static func addedToast(_ list: [Int], to track: Track) -> String {
        "أُضيف \(hizbsNominative(list)) إلى \(track.title)"
    }

    /// الإشعار بعد الإضافة مع النقل (قرار ذوقي): «نُقل ح 10 إلى مراجعة البعيد»،
    /// أو «أُضيف ح 9 ونُقل ح 10 إلى مراجعة البعيد». و«أُضيف» وحدها حين لا نقل.
    static func addedToast(added: [Int], moved: [Int], to track: Track) -> String {
        switch (added.isEmpty, moved.isEmpty) {
        case (_, true): addedToast(added, to: track)
        case (true, false): "نُقل \(hizbsNominative(moved)) إلى \(track.title)"
        case (false, false): "أُضيف \(hizbsNominative(added)) ونُقل \(hizbsNominative(moved)) إلى \(track.title)"
        }
    }

    // MARK: النقل والإزالة (§12.5، م20)

    /// «نُقل ح 10 إلى مراجعة البعيد» · «نُقل 3 أحزاب إلى …»
    static func movedToast(_ list: [Int], to track: Track) -> String {
        "نُقل \(hizbsNominative(list)) إلى \(track.title)"
    }

    /// «أُزيل ح 11 · سجلّه محفوظ» · «أُزيل حزبان · سجلّهما محفوظ»
    static func removedToast(_ list: [Int]) -> String {
        "أُزيل \(hizbsNominative(list)) · سجلّ\(pronoun(list.count)) محفوظ"
    }

    /// عنوان ورقة الإدارة: «نقل من مراجعة القريب» · «إزالة من مراجعة القريب».
    static func manageTitle(removing: Bool, from track: Track) -> String {
        (removing ? "إزالة من " : "نقل من ") + track.title
    }

    /// زرّ ورقة الإدارة: «انقل الحزب 9 إلى مراجعة القريب» · «أزل حزبين»، وبلا اختيار «اختر حزباً».
    static func manageButton(_ list: [Int], removing: Bool, to target: Track) -> String {
        if list.isEmpty { return "اختر جزءاً أو حزباً" }
        return removing ? "أزل \(hizbsAccusative(list))" : "انقل \(hizbsAccusative(list)) إلى \(target.title)"
    }

    /// سؤال تأكيد الإزالة: «أتزيل الحزب 11 من مراجعة القريب؟» · «أتزيل الحزبين 10 و11 من …؟» · «أتزيل 3 أحزاب من …؟»
    static func removeQuestion(_ list: [Int], from track: Track) -> String {
        let what: String
        switch list.count {
        case 1: what = "الحزب \(Digits.en(list[0]))"
        case 2: what = "الحزبين \(Digits.en(list[0])) و\(Digits.en(list[1]))"
        default: what = hizbsAccusative(list)
        }
        return "أتزيل \(what) من \(track.title)؟"
    }

    /// «يبقى سجلّ تلاوته محفوظاً، فإن أعدته ظهر عمره كما كان.»
    static func removeNote(_ count: Int) -> String {
        let p = pronoun(count)
        return "يبقى سجلّ تلاوت\(p) محفوظاً، فإن أعدت\(p) ظهر عمر\(p) كما كان."
    }

    /// «أزله» · «أزلهما» · «أزلها»
    static func removeAnswer(_ count: Int) -> String { "أزل\(pronoun(count))" }

    /// بند النقل في قائمة الحزب: «نقل إلى مراجعة البعيد». نصّ جاهز لا مفتاح ترجمة،
    /// لأن الإقحام في مفتاح الترجمة يحيط الاسم بعلامتي عزل خفيّتين (⁨…⁩) يقرؤهما قارئ الشاشة والاختبار.
    static func hizbMenuMove(to track: Track) -> String {
        "نقل إلى " + track.title
    }

    /// رأس قائمة الحزب: «ح 10 · النساء · الجزء 5».
    static func hizbMenuHeader(_ hizb: Int) -> String {
        "\(Digits.hizbLabel(hizb)) · \(Quran.suraName(Quran.firstSura(ofHizb: hizb))) · الجزء \(Digits.en(Quran.juz(ofHizb: hizb)))"
    }

    /// «في البعيد» · «في القريب» تحت خانة الحزب الذي في مسار آخر (§12.2).
    static func inTrackShort(_ track: Track) -> String {
        switch track {
        case .farReview: "في البعيد"
        case .nearReview: "في القريب"
        case .newMemorization: "في الجديد"
        }
    }

    // MARK: سؤال النقل (5.1، §12.3)

    /// «الحزب 10 موجود في مراجعة القريب. أتنقله؟» · «الحزبان 10 و11 موجودان في …. أتنقلهما؟»
    /// · «3 أحزاب موجودة في …. أتنقلها؟»
    static func conflictQuestion(_ list: [Int], in track: Track) -> String {
        switch list.count {
        case 1: "الحزب \(Digits.en(list[0])) موجود في \(track.title). أتنقله؟"
        case 2: "الحزبان \(Digits.en(list[0])) و\(Digits.en(list[1])) موجودان في \(track.title). أتنقلهما؟"
        case 3...10: "\(Digits.en(list.count)) أحزاب موجودة في \(track.title). أتنقلها؟"
        default: "\(Digits.en(list.count)) حزباً موجودة في \(track.title). أتنقلها؟"
        }
    }

    /// «سجلّ تلاوته ينتقل معه كما هو.» ويُضاف إن كان في الاختيار غيره: «ويُضاف ما سواه في الحالين.»
    static func conflictNote(_ count: Int, hasOthers: Bool) -> String {
        let p = pronoun(count)
        return "سجلّ تلاوت\(p) ينتقل مع\(p) كما هو." + (hasOthers ? " ويُضاف ما سوا\(p) في الحالين." : "")
    }

    /// «انقله إلى مراجعة البعيد»
    static func moveAnswer(_ count: Int, to track: Track) -> String { "انقل\(pronoun(count)) إلى \(track.title)" }

    /// «اتركه في مراجعة القريب»
    static func keepAnswer(_ count: Int, in track: Track) -> String { "اترك\(pronoun(count)) في \(track.title)" }
}
