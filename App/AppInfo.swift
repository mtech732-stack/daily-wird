import Foundation

enum AppInfo {
    /// اسم عمل حتى يقرّر المالك قبل ش7 (القرار 9).
    static let name = "الورد اليومي"

    /// الإصدار من `CFBundleShortVersionString` (§17.3).
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// شعار المالك واسمه لـ«عن التطبيق» (8.4، §17.3). ينتظران جواب س8، ولا يُكتبان ولا يُرسمان قبله.
    /// والشعار اسم أصل صورة في `Assets.xcassets`.
    static let ownerLogo: String? = nil
    static let ownerName: String? = nil
}
