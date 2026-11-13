import SwiftData
import SwiftUI

@main
struct DailyWirdApp: App {
    let container: ModelContainer
    /// حركة البداية مرة واحدة في كل تشغيل بعد إغلاق كلي (`LaunchSplash`).
    @State private var showsSplash = LaunchSplash.isEnabled

    init() {
        // العدّاد في UserDefaults: يبدأ في اختبارات الواجهة صفراً أو بعدد معلوم (§16.8).
        CounterStore.prepareForUITesting()
        do {
            if let seed = UITestSeed.fromLaunchArguments() {
                // اختبارات الواجهة وحدها: مخزن في الذاكرة بمحفوظ مثالي، فلا يُمسّ مخزن حقيقي.
                container = try Persistence.makeContainer(inMemory: true)
                seed.apply(to: container.mainContext)
            } else {
                container = try Persistence.makeContainer()
            }
        } catch {
            // لا نمحو المخزن ولا نبدأ فارغاً بصمت: سجلّ المالك لا يضيع (4.3).
            fatalError("تعذّر فتح مخزن البيانات: \(error)")
        }
    }

    private static var testScheme: ColorScheme? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ui-testing") else { return nil }
        // `-light` لما يُقرأ لونه نهاراً، فلا يتبع مظهر المحاكي في أوضاع الفحص الليلية.
        return args.contains("-dark") ? .dark : args.contains("-light") ? .light : nil
    }

    var body: some Scene {
        WindowGroup {
            if LaunchPreview.isRequested {
                LaunchPreview()
                    .ignoresSafeArea()
                    .accessibilityIdentifier("launch.preview")
                    .preferredColorScheme(Self.testScheme)
            } else {
                ZStack {
                    HomeView()
                        .environment(\.layoutDirection, .rightToLeft)
                    if showsSplash {
                        // التلاشي داخل الحركة نفسها؛ وبعده تُزال بلا انتقال. واللمسة تُزيلها بتلاشٍ قصير.
                        LaunchSplash(done: { showsSplash = false })
                            .transition(.opacity.animation(.easeOut(duration: 0.2)))
                            .zIndex(1)
                    }
                }
                // اختبارات الواجهة وحدها: `-dark` يفرض الليل، لأن فحص طلب الدمج نهاريّ (القرار 24).
                // وفي التطبيق يتبع الجهاز ولا اختيار له (§1، §17.3).
                .preferredColorScheme(Self.testScheme)
            }
        }
        .modelContainer(container)
    }
}
