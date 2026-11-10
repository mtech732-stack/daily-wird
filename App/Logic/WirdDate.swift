import Foundation

/// التاريخ في الواجهة (م4، القرار 1، القرار 2): التقويم الميلادي والأرقام الإنجليزية صراحةً،
/// مهما كانت منطقة الجهاز ولغته. واليوم يوم عادي يبدأ عند منتصف الليل بتوقيت الجهاز.
enum WirdDate {
    /// العربية بأرقام لاتينية وتقويم ميلادي.
    static let locale = Locale(identifier: "ar@calendar=gregorian;numbers=latn")

    static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = timeZone
        return calendar
    }

    /// تاريخ رأس الشاشة (7.1): «الاثنين 9 نوفمبر».
    static func header(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timeZone: timeZone)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }

    /// تاريخ «آخر إدخال» و«آخر تلاوة» (§13.4): «الجمعة 6 نوفمبر»، و«الخميس 6 أغسطس 2025» إن خالفت سنته سنة اليوم.
    static func long(_ date: Date, now: Date, timeZone: TimeZone = .current) -> String {
        let cal = calendar(timeZone: timeZone)
        let formatter = formatter(timeZone: timeZone)
        formatter.dateFormat = cal.component(.year, from: date) == cal.component(.year, from: now)
            ? "EEEE d MMMM" : "EEEE d MMMM y"
        return formatter.string(from: date)
    }

    /// الوقت بنظام 12 ساعة: «5:34 ص» و«9:40 م».
    static func time(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = formatter(timeZone: timeZone)
        formatter.amSymbol = "ص"
        formatter.pmSymbol = "م"
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private static func formatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timeZone: timeZone)
        formatter.locale = locale
        formatter.timeZone = timeZone
        return formatter
    }
}
