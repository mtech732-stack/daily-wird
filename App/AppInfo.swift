import Foundation

enum AppInfo {
    /// اسم عمل حتى يقرّر المالك قبل ش7 (القرار 9).
    static let name = "الورد اليومي"

    /// الإصدار من `CFBundleShortVersionString` (§17.3).
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
