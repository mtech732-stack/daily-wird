/// المسارات الثلاثة (3). تُحفظ في البيانات بقيمتها النصّية الثابتة.
/// ترتيبها هنا ترتيب المالك على الشاشة: البعيد ثم القريب ثم الجديد (7.1).
enum Track: String, CaseIterable, Codable, Sendable {
    case farReview = "farReview"   // مراجعة البعيد
    case nearReview = "nearReview" // مراجعة القريب
    case newMemorization = "new"   // المحفوظ الجديد

    /// اسمه على الشاشة، كما سمّاه المالك.
    var title: String {
        switch self {
        case .farReview: "مراجعة البعيد"
        case .nearReview: "مراجعة القريب"
        case .newMemorization: "المحفوظ الجديد"
        }
    }

    /// مسارا المراجعة يُسجَّلان بالأرباع، والجديد بالأوجه (5.3، 5.6).
    var isReview: Bool { self != .newMemorization }
}
