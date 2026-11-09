import Foundation
import SwiftData

/// بنية البيانات · الإصدار 1 (ش0 · المرحلة 7).
///
/// قواعد ملزمة (4.4، 4.3):
/// - صالحة لـ CloudKit من أول يوم: لا `@Attribute(.unique)`، وكل خاصية اختيارية
///   أو لها قيمة افتراضية، ولا علاقات (فلا حاجة إلى علاقات اختيارية ولا عكسية).
/// - لا يُمحى شيء من سجلّ المالك إلا التراجع في اليوم نفسه (5.3، 5.6).
///   والنقل والإزالة يُسجَّلان بإغلاق صفّ وفتح آخر، لا بالحذف.
/// - كل تسجيل بتاريخه ووقته كاملين، لتقوم عليه أي ميزة لاحقة دون إعادة بناء.
/// - أي تغيير بعد الإطلاق يكون إصداراً جديداً (SchemaV2) بخطّة ترحيل تحفظ القديم.
///
/// المراجع إلى القرآن أرقام فقط (الحزب 1–60، الربع 1–240، الوجه 1–604)،
/// وحدودها في جدول data/ المضمّن، لا هنا.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [HizbPlacement.self, QuarterReading.self, PageCompletion.self, ReviewCycle.self]
    }

    /// حزب في مسار (5.1، 5.2). الحزب في مسار واحد في وقت واحد: صفّه المفتوح `removedAt == nil`.
    /// النقل = إغلاق الصفّ القديم وفتح صفّ في المسار الجديد. الإزالة = إغلاقه.
    /// وفي المحفوظ الجديد يعني الصفّ المفتوح: «الحزب الذي أحفظ فيه الآن» (5.6).
    @Model
    final class HizbPlacement {
        /// رقم الحزب 1–60.
        var hizb: Int = 0
        /// `Track.rawValue`.
        var trackRaw: String = Track.farReview.rawValue
        var addedAt: Date = Date.distantPast
        /// متى أُزيل أو نُقل منه. `nil` = ما زال فيه.
        var removedAt: Date?

        init(hizb: Int, track: Track, addedAt: Date = .now) {
            self.hizb = hizb
            self.trackRaw = track.rawValue
            self.addedAt = addedAt
        }

        var track: Track? { Track(rawValue: trackRaw) }
        var isActive: Bool { removedAt == nil }
    }

    /// التظليل (3، 5.3): المالك تلا ربعاً في وقت بعينه.
    /// مرتبط برقم الربع لا بالمسار، فيبقى عمره كما هو بعد النقل والإزالة (5.1، 5.2).
    /// ويُحذف بالتراجع في يومه وحده.
    @Model
    final class QuarterReading {
        /// رقم الربع 1–240.
        var quarter: Int = 0
        var readAt: Date = Date.distantPast
        /// المسار الذي كان فيه حين التظليل، للتاريخ وحده (لا يُبنى عليه العمر).
        var trackRaw: String?

        init(quarter: Int, readAt: Date = .now, track: Track? = nil) {
            self.quarter = quarter
            self.readAt = readAt
            self.trackRaw = track?.rawValue
        }
    }

    /// إتمام الوجه في المحفوظ الجديد (3، 5.6). مرتبط برقم الوجه، فالوجه المشترك
    /// بين حزبين يُتمّ مرة واحدة ويُحسب لهما. ويبقى بعد رفع الحزب، تاريخاً لحفظه.
    @Model
    final class PageCompletion {
        /// رقم الوجه 1–604.
        var page: Int = 0
        var completedAt: Date = Date.distantPast

        init(page: Int, completedAt: Date = .now) {
            self.page = page
            self.completedAt = completedAt
        }
    }

    /// الدورة في مسار مراجعة (5.5). الدورة الحالية: `endedAt == nil`.
    /// موضع التوقّف لا يُخزَّن، بل يُحسب من التظليلات منذ `startedAt`.
    @Model
    final class ReviewCycle {
        var trackRaw: String = Track.farReview.rawValue
        var startedAt: Date = Date.distantPast
        var endedAt: Date?
        /// `CycleEnd.rawValue`: اكتملت، أو بدأ المالك دورة جديدة بنفسه.
        var endReasonRaw: String?

        init(track: Track, startedAt: Date = .now) {
            self.trackRaw = track.rawValue
            self.startedAt = startedAt
        }

        var track: Track? { Track(rawValue: trackRaw) }
        var isCurrent: Bool { endedAt == nil }
    }

    enum CycleEnd: String, Sendable {
        case completed   // ظُلّل كل ربع في المسار
        case manual      // «ابدأ دورة جديدة»
    }
}

// الأسماء المستعملة في التطبيق تشير دائماً إلى آخر إصدار.
typealias HizbPlacement = SchemaV1.HizbPlacement
typealias QuarterReading = SchemaV1.QuarterReading
typealias PageCompletion = SchemaV1.PageCompletion
typealias ReviewCycle = SchemaV1.ReviewCycle
typealias CycleEnd = SchemaV1.CycleEnd
