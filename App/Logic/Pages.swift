import Foundation
import SwiftData

/// إتمام الوجه في المحفوظ الجديد (5.6، design/system.md §15.3). منطق خالص بلا واجهة.
///
/// - كل إتمام صفّ `PageCompletion` بتاريخه ووقته، مرتبط برقم الوجه، فالوجه المشترك بين حزبين يُتمّ مرة.
/// - ضغطة ثانية في يوم الإتمام = تراجع: يُحذف إتمام اليوم وحده.
/// - ضغطة على وجه أُتمّ قبل اليوم لا تغيّر شيئاً (ذ29)، والتراجع في يومه وحده.
enum Pages {
    enum TapResult: Equatable, Sendable {
        /// سُجّل إتمام الوجه الآن.
        case completed
        /// أُتمّ اليوم، فحُذف إتمام اليوم وحده.
        case undone
        /// أُتمّ قبل اليوم في هذا التاريخ (آخر إتمام له)، فلم يتغيّر شيء.
        case completedBefore(Date)
    }

    @discardableResult
    static func tap(page: Int, in context: ModelContext, now: Date,
                    calendar: Calendar = WirdDate.calendar()) throws -> TapResult {
        precondition((1...604).contains(page), "رقم الوجه 1–604")
        let p = page
        let rows = try context.fetch(FetchDescriptor<PageCompletion>(predicate: #Predicate<PageCompletion> { $0.page == p }))
        let today = rows.filter { calendar.isDate($0.completedAt, inSameDayAs: now) }
        if !today.isEmpty {
            // كل إتمام اليوم (وقد تأتي المزامنة بصفّين من جهازين)، ولا شيء قبله.
            for row in today { context.delete(row) }
            try context.save()
            return .undone
        }
        if let last = rows.map(\.completedAt).max() { return .completedBefore(last) }
        context.insert(PageCompletion(page: page, completedAt: now))
        try context.save()
        return .completed
    }
}
