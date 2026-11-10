import Foundation

/// سطر «آخر إدخال» فوق بطاقة كل مسار مراجعة (7.1، 7.1.2، system.md §13.4).
/// هو أحدث تظليل لأيّ ربع في أحزاب المسار الآن: فإن نُقل حزب انتقل سجلّه معه، وتغيّر السطر في المسارين.
enum LastEntry {
    /// أحدث تظليل بين أرباع المسار، أو `nil` قبل أول إدخال (ذ12).
    static func latest(in quarters: [Int], readings: [QuarterReading]) -> Date? {
        let set = Set(quarters)
        return readings.lazy.filter { set.contains($0.quarter) }.map(\.readAt).max()
    }

    /// صيغة المدّة بالأيام التقويمية (7.1.2): اليوم · أمس · قبل يومين · قبل 3–6 أيام · قبل أسبوع (7–13)
    /// · قبل أسبوعين (14–20) · قبل 3 أسابيع (21–29) · قبل شهر (30–59) · قبل شهرين (60–89)
    /// · ثم «قبل [ش] أشهر» حيث ش = الأيام ÷ 30 بلا كسر، و«شهراً» من 11 فما فوق.
    static func relative(days: Int) -> String {
        switch max(days, 0) {
        case 0: "اليوم"
        case 1: "أمس"
        case 2: "قبل يومين"
        case ...6: "قبل \(days) أيام"
        case ...13: "قبل أسبوع"
        case ...20: "قبل أسبوعين"
        case ...29: "قبل 3 أسابيع"
        case ...59: "قبل شهر"
        case ...89: "قبل شهرين"
        default:
            days / 30 <= 10 ? "قبل \(days / 30) أشهر" : "قبل \(days / 30) شهراً"
        }
    }

    /// «آخر إدخال قبل 3 أيام».
    static func title(_ date: Date, now: Date, calendar: Calendar = WirdDate.calendar()) -> String {
        "آخر إدخال \(relative(days: Age.days(from: date, to: now, calendar: calendar)))"
    }

    /// «الجمعة 6 نوفمبر · 5:34 ص»، والسنة لا تُكتب إلا إن خالفت سنة اليوم (§13.4).
    static func stamp(_ date: Date, now: Date, timeZone: TimeZone = .current) -> String {
        "\(WirdDate.long(date, now: now, timeZone: timeZone)) · \(WirdDate.time(date, timeZone: timeZone))"
    }
}
