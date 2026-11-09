import XCTest
import UIKit
@testable import DailyWird

/// ش0 · المرحلة 2: أساسات المشروع.
final class FoundationTests: XCTestCase {

    /// 8.3: الخط IBM Plex Sans Arabic مضمّن بأوزانه الأربعة.
    func test_8_3_embeddedFontWeightsAreAvailable() {
        for weight in Theme.Weight.allCases {
            XCTAssertNotNil(UIFont(name: weight.rawValue, size: 17), "الخط غير مضمّن: \(weight.rawValue)")
        }
    }

    /// 9 (القرار 9): اسم العمل «الورد اليومي».
    func test_9_appNameIsDailyWird() {
        XCTAssertEqual(AppInfo.name, "الورد اليومي")
    }

    /// 4.2 · أدنى نظام iOS 17.
    func test_4_2_minimumOSIs17() {
        let min = Bundle.main.infoDictionary?["MinimumOSVersion"] as? String
        XCTAssertEqual(min, "17.0")
    }

    /// 4.2: الاتجاه من اليمين إلى اليسار؛ لغة التطبيق العربية.
    func test_4_2_appLanguageIsArabic() {
        XCTAssertEqual(Bundle.main.preferredLocalizations.first, "ar")
    }
}
