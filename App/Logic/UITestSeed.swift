import Foundation
import SwiftData

/// محفوظ مثالي تبدأ به اختبارات الواجهة ولقطاتها، في مخزن في الذاكرة وحده.
/// يُفعَّل بالوسيط `-ui-testing`، ومعه اختيارياً `-seed "farReview:1-9;nearReview:10-11"`،
/// وتظليلات سابقة `-readings "1:0,5:3@23:30"`: الربع ثم كم يوماً مضى، واختيارياً الساعة،
/// وبداية الدورة `-cycle "farReview:20"`: كم يوماً مضى على بدايتها (أول ذلك اليوم). وإن لم تُذكر
/// بدأت دورة كل مسار عند فتح التطبيق، فلا يُعدّ فيها ما ظُلّل قبله.
/// لا شيء من محفوظ المالك في الكود (4.4): المثال في ملف الاختبار.
struct UITestSeed: Equatable {
    var hizbs: [Track: [Int]] = [:]
    var readings: [Reading] = []
    /// كم يوماً مضى على بداية دورة كل مسار (§14.1).
    var cycles: [Track: Int] = [:]

    /// تظليل سابق: الربع، وكم يوماً مضى عليه، والساعة والدقيقة (إن لم تُذكر: قبل دقيقة إن كان اليوم،
    /// وإلا 9:00 ص).
    struct Reading: Equatable {
        var quarter: Int
        var daysAgo: Int
        var hour: Int?
        var minute: Int = 0
    }

    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> UITestSeed? {
        guard arguments.contains("-ui-testing") else { return nil }
        var seed = UITestSeed()
        if let i = arguments.firstIndex(of: "-seed"), i + 1 < arguments.count { seed = parse(arguments[i + 1]) }
        if let i = arguments.firstIndex(of: "-readings"), i + 1 < arguments.count {
            seed.readings = parseReadings(arguments[i + 1])
        }
        if let i = arguments.firstIndex(of: "-cycle"), i + 1 < arguments.count {
            for part in arguments[i + 1].split(separator: ",") {
                let kv = part.split(separator: ":")
                if kv.count == 2, let track = Track(rawValue: String(kv[0])), let days = Int(kv[1]), days >= 0 {
                    seed.cycles[track] = days
                }
            }
        }
        return seed
    }

    /// «1:0,5:3@23:30» → الربع 1 اليوم، والربع 5 قبل ثلاثة أيام في 11:30 م.
    static func parseReadings(_ text: String) -> [Reading] {
        text.split(separator: ",").compactMap { item -> Reading? in
            let parts = item.split(separator: "@", maxSplits: 1)
            let qd = parts[0].split(separator: ":").compactMap { Int($0) }
            guard qd.count == 2, (1...Quran.quarterCount).contains(qd[0]), qd[1] >= 0 else { return nil }
            var reading = Reading(quarter: qd[0], daysAgo: qd[1])
            if parts.count == 2 {
                let hm = parts[1].split(separator: ":").compactMap { Int($0) }
                guard hm.count == 2 else { return nil }
                reading.hour = hm[0]
                reading.minute = hm[1]
            }
            return reading
        }
    }

    /// وقت التظليل المثالي بالنسبة إلى «الآن».
    static func date(of reading: Reading, now: Date, calendar: Calendar = WirdDate.calendar()) -> Date {
        let today = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: -reading.daysAgo, to: today) ?? today
        guard let hour = reading.hour else {
            return reading.daysAgo == 0 ? now.addingTimeInterval(-60) : day.addingTimeInterval(9 * 3600)
        }
        return calendar.date(bySettingHour: hour, minute: reading.minute, second: 0, of: day) ?? day
    }

    /// «farReview:1-9;nearReview:10-11» → البعيد ح 1–9، والقريب ح 10–11.
    static func parse(_ text: String) -> UITestSeed {
        var seed = UITestSeed()
        for part in text.split(separator: ";") {
            let kv = part.split(separator: ":", maxSplits: 1)
            guard kv.count == 2, let track = Track(rawValue: String(kv[0])) else { continue }
            var list: [Int] = []
            for item in kv[1].split(separator: ",") {
                let ends = item.split(separator: "-").compactMap { Int($0) }
                if ends.count == 2, ends[0] <= ends[1] { list += Array(ends[0]...ends[1]) }
                else if ends.count == 1 { list.append(ends[0]) }
            }
            seed.hizbs[track, default: []] += list
        }
        return seed
    }

    func apply(to context: ModelContext) {
        for (track, list) in hizbs {
            for hizb in list { context.insert(HizbPlacement(hizb: hizb, track: track)) }
        }
        let now = WirdClock.now()
        for reading in readings {
            context.insert(QuarterReading(quarter: reading.quarter, readAt: Self.date(of: reading, now: now)))
        }
        let calendar = WirdDate.calendar()
        for track in hizbs.keys where track.isReview {
            let start = cycles[track].flatMap {
                calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: now))
            } ?? now
            context.insert(ReviewCycle(track: track, startedAt: start))
        }
        try? context.save()
    }
}
