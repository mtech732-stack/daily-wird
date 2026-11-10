import Foundation

/// نصوص تفاصيل الربع (7.3، 5.4، design/system.md §13.5) من جدول الحدود والسجلّ.
enum QuarterDetails {
    /// المدى: «من البقرة 283 إلى آل عمران 14»، وفي سورة واحدة لا يتكرّر اسمها: «من آل عمران 33 إلى 51» (ذ13).
    static func range(_ quarter: Int) -> String {
        let q = Quran.quarter(quarter)
        let (fs, fa, ls, la) = (q.first[0], q.first[1], q.last[0], q.last[1])
        return fs == ls
            ? "من \(Quran.suraName(fs)) \(fa) إلى \(la)"
            : "من \(Quran.suraName(fs)) \(fa) إلى \(Quran.suraName(ls)) \(la)"
    }

    /// السور التي يضمّها: أسماؤها بـ « · ».
    static func suras(_ quarter: Int) -> String {
        Quran.quarter(quarter).suras.map(Quran.suraName).joined(separator: " · ")
    }

    /// الأوجه التي يمسّها: «49 · 50 · 51».
    static func pages(_ quarter: Int) -> String {
        let q = Quran.quarter(quarter)
        return (q.firstPage...q.lastPage).map(String.init).joined(separator: " · ")
    }

    /// تظليلات الربع كلها، الأحدث أولاً.
    static func history(_ quarter: Int, readings: [QuarterReading]) -> [Date] {
        readings.filter { $0.quarter == quarter }.map(\.readAt).sorted(by: >)
    }

    /// كبسولات «آخر التواريخ»: حتى خمسة، الأحدث أولاً، وتظليل اليوم «اليوم».
    static func chips(_ history: [Date], now: Date, calendar: Calendar = WirdDate.calendar()) -> [(text: String, isToday: Bool)] {
        history.prefix(5).map { date in
            calendar.isDate(date, inSameDayAs: now)
                ? ("اليوم", true)
                : (WirdDate.short(date, now: now, timeZone: calendar.timeZone), false)
        }
    }
}
