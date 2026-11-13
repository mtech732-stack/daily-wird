import Foundation

/// المزامنة مع iCloud (5.8، ش7).
///
/// تعمل في بناء «DailyWird iCloud» وحده (إعداد `iCloud` في project.yml)، لأنه وحده يحمل صلاحية iCloud،
/// ولا يوقّعه إلا حساب المطوّر المدفوع. والبناء المعتاد (Debug وRelease) بلا صلاحية، فيبقى يُثبَّت
/// بحساب Apple المجاني كما هو اليوم (القرار 28)، وسجلّه في الجهاز وحده.
///
/// والمخزن هو نفسه في البناءين (`default.store`)، فإذا شُغّل بناء iCloud على مخزن قائم رفع ما فيه
/// إلى iCloud كما هو، ولا يُمحى منه شيء (4.3). والعدّاد خارج المخزن فلا يُزامَن (القرار 10).
enum Cloud {
    /// الحاوية الخاصة بالمالك (5.8). يطابق `Support/DailyWird-iCloud.entitlements`.
    static let containerID = "iCloud.com.mtech732.dailywird"

    #if WIRD_ICLOUD
    static let isBuiltIn = true
    #else
    static let isBuiltIn = false
    #endif
}
