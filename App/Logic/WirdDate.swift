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
}
