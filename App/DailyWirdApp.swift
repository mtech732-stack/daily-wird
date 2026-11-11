import SwiftData
import SwiftUI

@main
struct DailyWirdApp: App {
    let container: ModelContainer

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
            HomeView()
                .environment(\.layoutDirection, .rightToLeft)
                // اختبارات الواجهة وحدها: `-dark` يفرض الليل، لأن فحص طلب الدمج نهاريّ (القرار 24).
                // وفي التطبيق يتبع الجهاز ولا اختيار له (§1، §17.3).
                .preferredColorScheme(Self.testScheme)
        }
        .modelContainer(container)
    }
}
