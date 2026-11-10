import Foundation
import SwiftData

/// التظليل (3، 5.3): ضغطة على الربع = تلوته اليوم. منطق خالص بلا واجهة، تختبره اختبارات الوحدة.
///
/// - كل تظليل صفّ `QuarterReading` بتاريخه ووقته كاملين، مرتبط برقم الربع لا بموضعه في الشاشة،
///   فالربع المشترك يُظلَّل مرة واحدة ويظهر مظلّلاً في الموضعين (7.1.1)، ويبقى بعد النقل والإزالة (5.2).
/// - لا يُظلَّل الربع مرتين في اليوم الواحد، واليوم يوم عادي يبدأ عند منتصف الليل بتوقيت الجهاز (القرار 2).
/// - لا يختار المالك درجة أبداً: الضغطة تسجّل التلاوة وحدها.
enum Shading {
    /// ما جرى بالضغطة.
    enum TapResult: Equatable, Sendable {
        /// سُجّل تظليل جديد بتاريخه ووقته.
        case shaded
        /// الربع مظلّل اليوم أصلاً، فلم يُسجَّل شيء. (والتراجع في المرحلة التالية.)
        case alreadyReadToday
    }

    /// هل التاريخان في اليوم نفسه بتوقيت الجهاز (من منتصف الليل إلى منتصف الليل).
    static func sameDay(_ a: Date, _ b: Date, calendar: Calendar = WirdDate.calendar()) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// الأرباع التي ظُلّلت اليوم: عليها علامة «اليوم» (5.3).
    static func readToday(_ readings: [QuarterReading], now: Date, calendar: Calendar = WirdDate.calendar()) -> Set<Int> {
        Set(readings.filter { sameDay($0.readAt, now, calendar: calendar) }.map(\.quarter))
    }

    /// ضغطة على ربع (5.3): إن لم يُظلَّل اليوم سُجّل تظليله بتاريخه ووقته، وإلا فلا تظليل ثانٍ.
    @discardableResult
    static func tap(quarter: Int, track: Track?, in context: ModelContext,
                    now: Date, calendar: Calendar = WirdDate.calendar()) throws -> TapResult {
        precondition((1...Quran.quarterCount).contains(quarter), "رقم الربع 1–240")
        let q = quarter
        let readings = try context.fetch(FetchDescriptor<QuarterReading>(predicate: #Predicate<QuarterReading> { $0.quarter == q }))
        if readings.contains(where: { sameDay($0.readAt, now, calendar: calendar) }) {
            return .alreadyReadToday
        }
        context.insert(QuarterReading(quarter: quarter, readAt: now, track: track))
        try context.save()
        return .shaded
    }

    /// أول لحظة في اليوم التالي، لتتحدّث الشاشة عندها والتطبيق مفتوح (§13.2).
    static func nextMidnight(after now: Date, calendar: Calendar = WirdDate.calendar()) -> Date {
        calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
                          matchingPolicy: .nextTime) ?? now.addingTimeInterval(86_400)
    }
}

/// ما تحتاجه مربّعات الأرباع من حالة التظليل، وما تفعله الضغطة.
struct ShadingState {
    /// الأرباع المظلّلة اليوم.
    var today: Set<Int> = []
    /// ضغطة على ربع في مسار.
    var tap: (_ quarter: Int, _ track: Track) -> Void = { _, _ in }

    func isToday(_ quarter: Int) -> Bool { today.contains(quarter) }
}
