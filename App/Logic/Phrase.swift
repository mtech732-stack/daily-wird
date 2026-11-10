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

    /// «في البعيد» · «في القريب» تحت خانة الحزب الذي في مسار آخر (§12.2).
    static func inTrackShort(_ track: Track) -> String {
        switch track {
        case .farReview: "في البعيد"
        case .nearReview: "في القريب"
        case .newMemorization: "في الجديد"
        }
    }
}
