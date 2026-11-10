import Foundation

/// ساعة التطبيق: الوقت الحقيقي للمالك دائماً. وفي اختبارات الواجهة وحدها (`-ui-testing`)
/// يجوز أن تبدأ من وقت مثبّت بالوسيط `-now "2026-11-06T23:59:50"` (بتوقيت الجهاز)، ثم تمضي
/// مع الوقت الحقيقي، فيُختبر منتصف الليل والتطبيق مفتوح (5.3، القرار 2) دون انتظار يوم.
enum WirdClock {
    /// الفرق بين ساعة الاختبار والوقت الحقيقي. صفر خارج الاختبارات، ولا يغيّره إلا `jumpPastMidnight` فيها.
    nonisolated(unsafe) static var offset: TimeInterval = offset(from: ProcessInfo.processInfo.arguments)

    /// اختبارات الواجهة وحدها: تقفز الساعة إلى ما بعد منتصف الليل التالي بثانيتين، فيُختبر
    /// تحديث الشاشة والتطبيق مفتوح دون انتظار وقت حقيقي.
    static func jumpPastMidnight() {
        let target = Shading.nextMidnight(after: now()).addingTimeInterval(2)
        offset += target.timeIntervalSince(now())
    }

    static func now() -> Date { Date().addingTimeInterval(offset) }

    static func offset(from arguments: [String], realNow: Date = Date(), timeZone: TimeZone = .current) -> TimeInterval {
        guard arguments.contains("-ui-testing"),
              let i = arguments.firstIndex(of: "-now"), i + 1 < arguments.count,
              let start = parse(arguments[i + 1], timeZone: timeZone) else { return 0 }
        return start.timeIntervalSince(realNow)
    }

    /// «2026-11-06T23:59:50» بتوقيت الجهاز.
    static func parse(_ text: String, timeZone: TimeZone = .current) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.date(from: text)
    }
}
