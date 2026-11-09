import SwiftData
import SwiftUI

@main
struct DailyWirdApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try Persistence.makeContainer()
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
