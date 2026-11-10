import Foundation
import SwiftData

/// محفوظ مثالي تبدأ به اختبارات الواجهة ولقطاتها، في مخزن في الذاكرة وحده.
/// يُفعَّل بالوسيط `-ui-testing`، ومعه اختيارياً `-seed "farReview:1-9;nearReview:10-11"`.
/// لا شيء من محفوظ المالك في الكود (4.4): المثال في ملف الاختبار.
struct UITestSeed: Equatable {
    var hizbs: [Track: [Int]] = [:]

    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> UITestSeed? {
        guard arguments.contains("-ui-testing") else { return nil }
        guard let i = arguments.firstIndex(of: "-seed"), i + 1 < arguments.count else { return UITestSeed() }
        return parse(arguments[i + 1])
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
        try? context.save()
    }
}
