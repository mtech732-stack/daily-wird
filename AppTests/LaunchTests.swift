import UIKit
import XCTest
@testable import DailyWird

/// ش6 · المرحلة 4: الأيقونة وشاشة البداية (8.3 · 8.4، design/system.md §17.2، §17.5، ذ47 · ذ48).
final class LaunchTests: XCTestCase {

    /// 8.4 و§17.5: الأيقونة من `AppIcon` في الحزمة.
    func test_8_4_appIconInBundle() {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        XCTAssertEqual(primary?["CFBundleIconName"] as? String, "AppIcon")
    }

    /// §17.2: الشاشة من `LaunchScreen.storyboard`، والأرضية `paper` نهاراً وليلاً.
    func test_8_3_launchScreenColors() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "UILaunchStoryboardName") as? String, "LaunchScreen")
        let paper = try XCTUnwrap(UIColor(named: "LaunchPaper"))
        XCTAssertEqual(hex(paper.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))), 0xF7F4EC)
        XCTAssertEqual(hex(paper.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))), 0x13283E)
        XCTAssertNotNil(UIImage(named: "LaunchBand"))
        XCTAssertNotNil(UIImage(named: "LaunchRibbon"))
    }

    /// §17.2 على 390×844: الشريط بعرض الشاشة وارتفاعه 85 ومركزه مركزها طولاً، والعلامة من أعلى الشاشة
    /// إلى أسفل الشريط + 37.6، ومركزها على 68% من العرض كما في الأيقونة.
    func test_8_3_launchScreenLayout() throws {
        let controller = try XCTUnwrap(UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController())
        let view = try XCTUnwrap(controller.view)
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.layoutIfNeeded()
        let images = view.subviews.compactMap { $0 as? UIImageView }
        XCTAssertEqual(images.count, 2)
        let band = try XCTUnwrap(images.first { $0.frame.width > 300 })
        let ribbon = try XCTUnwrap(images.first { $0.frame.width < 60 })
        XCTAssertEqual(band.frame.height, 85, accuracy: 0.5)
        XCTAssertEqual(band.frame.midY, 422, accuracy: 0.5)
        XCTAssertEqual(ribbon.frame.minY, 0, accuracy: 0.5, "من أعلى الشاشة لا المنطقة الآمنة")
        XCTAssertEqual(ribbon.frame.maxY, band.frame.maxY + 37.6, accuracy: 0.5)
        XCTAssertEqual(ribbon.frame.midX / 390, 0.68, accuracy: 0.01)
        XCTAssertTrue(band.clipsToBounds && ribbon.clipsToBounds)
    }

    private func hex(_ color: UIColor) -> Int {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Int((r * 255).rounded()) << 16 | Int((g * 255).rounded()) << 8 | Int((b * 255).rounded())
    }
}
