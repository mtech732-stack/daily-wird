import Foundation

/// العمر (3، 5.4، القرار 14): المدة منذ آخر تظليل للربع، في خمس درجات منفصلة بالأيام التقويمية
/// بين يوم آخر تظليل واليوم، لا بالساعات (system.md §13.3). والحدود شاملة.
/// لا يُدخلها المالك، بل تتغيّر وحدها مع الأيام، وتعود ممتلئة إذا ظُلّل الربع من جديد.
/// ولا ترتيب ولا ترشيح بحسبها: العرض فقط.
enum AgeLevel: Int, CaseIterable, Sendable {
    /// 1 · خلال 7 أيام (0–7): ممتلئ.
    case full = 1
    /// 2 · خلال 15 يوماً (8–15): نصفه الأسفل ممتلئ.
    case half
    /// 3 · خلال 22 يوماً (16–22): ربعه الأسفل ممتلئ.
    case quarter
    /// 4 · أكثر من 22 يوماً (23 فأكثر): باهت مخطّط.
    case faded
    /// 5 · لم يُتلَ: فارغ.
    case empty

    /// الأيام الحدّية كما اعتمدها المالك (القرار 14)، مبدئية حتى ش7.
    static let fullDays = 7
    static let halfDays = 15
    static let quarterDays = 22

    /// الدرجة من عدد الأيام التقويمية منذ آخر تظليل، أو `nil` إن لم يُتلَ.
    static func from(days: Int?) -> AgeLevel {
        guard let days else { return .empty }
        switch max(days, 0) {
        case ...fullDays: return .full
        case ...halfDays: return .half
        case ...quarterDays: return .quarter
        default: return .faded
        }
    }

    /// معنى الدرجة لقارئ الشاشة وللمفاتيح (7.1.3، ذ15).
    var meaning: String {
        switch self {
        case .full: "خلال 7 أيام"
        case .half: "خلال 15 يوماً"
        case .quarter: "خلال 22 يوماً"
        case .faded: "أكثر من 22 يوماً"
        case .empty: "لم يُتلَ"
        }
    }
}

enum Age {
    /// الأيام التقويمية بين يومين بتوقيت الجهاز: ما ظُلّل أمس في 11 ليلاً عمره يوم واحد صباح اليوم.
    static func days(from: Date, to: Date, calendar: Calendar = WirdDate.calendar()) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    /// آخر تظليل لكل ربع.
    static func lastRead(_ readings: [QuarterReading]) -> [Int: Date] {
        var map: [Int: Date] = [:]
        for r in readings where map[r.quarter].map({ r.readAt > $0 }) ?? true {
            map[r.quarter] = r.readAt
        }
        return map
    }

    /// درجة كل ربع له تظليل؛ وما لا تظليل له «لم يُتلَ».
    static func levels(_ readings: [QuarterReading], now: Date, calendar: Calendar = WirdDate.calendar()) -> [Int: AgeLevel] {
        lastRead(readings).mapValues { AgeLevel.from(days: days(from: $0, to: now, calendar: calendar)) }
    }
}
