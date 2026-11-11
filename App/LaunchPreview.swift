import SwiftUI
import UIKit

/// شاشة البداية كما يعرضها النظام، من `LaunchScreen.storyboard` نفسه (§17.2). لاختبارات الواجهة وحدها
/// (`-launch-preview`)، لأن النظام يعرضها لحظة قبل التطبيق فلا تُلتقط في اختبار.
struct LaunchPreview: UIViewControllerRepresentable {
    static var isRequested: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-ui-testing") && args.contains("-launch-preview")
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController() ?? UIViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
