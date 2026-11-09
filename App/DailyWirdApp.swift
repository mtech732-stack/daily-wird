import SwiftUI

@main
struct DailyWirdApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
