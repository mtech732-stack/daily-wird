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

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.layoutDirection, .rightToLeft)
        }
        .modelContainer(container)
    }
}
