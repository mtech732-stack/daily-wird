import SwiftUI

/// ش0 · المرحلة 2: شاشة واحدة فارغة عليها اسم التطبيق فقط.
/// الشاشة الرئيسية الحقيقية (7.1) تُبنى في ش1 بعد اعتماد نظام التصميم.
struct HomeView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Text(AppInfo.name)
                .font(Theme.font(.semiBold, size: 28, relativeTo: .title))
                .foregroundStyle(Theme.text)
                .accessibilityIdentifier("home.title")
        }
    }
}

#Preview {
    HomeView().environment(\.layoutDirection, .rightToLeft)
}
