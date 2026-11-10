import SwiftData
import SwiftUI

/// الشاشة الرئيسية «الورد اليومي» (7.1) كما تُبنى في ش1: المسارات الثلاثة بترتيب المالك،
/// كل بطاقة مطويّة على موضع توقّفها، والأرشيف يُفتح من شريط الإسدال.
/// لا يظهر في ش1: سطر «آخر إدخال» ومفاتيح الرموز (ش2)، والعدّاد (ش5) (design/system.md §12).
struct HomeView: View {
    @Query private var placements: [HizbPlacement]

    /// المسار المفتوح أرشيفه. لا يُحفظ، فيفتح التطبيق دائماً مطويّاً (7.1).
    @State private var openTrack: Track?

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = geo.size.width < 390 ? 16 : 20
            // عرض الصفّ داخل البطاقة المطويّة: الشاشة ناقص الهامشين وحشو البطاقة وحدّها.
            let narrow = geo.size.width - margin * 2 - 34 < 330
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        HomeHeader()
                            .padding(.bottom, 6)
                        ForEach(Track.allCases, id: \.self) { track in
                            card(for: track, narrow: narrow, proxy: proxy)
                                .id("card.\(track.rawValue)")
                        }
                    }
                    .padding(.horizontal, margin)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let open = openTrack {
                        StickyFoldBar(track: open) { toggle(open, proxy: proxy) }
                            .padding(.horizontal, margin)
                    }
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func card(for track: Track, narrow: Bool, proxy: ScrollViewProxy) -> some View {
        if track.isReview {
            let layout = ReviewTrackLayout(track: track, hizbs: Library.activeHizbs(in: track, from: placements))
            if layout.isEmpty {
                EmptyTrackCard(track: track)
            } else {
                ReviewTrackCard(layout: layout, isOpen: openTrack == track, narrow: narrow) {
                    toggle(track, proxy: proxy)
                }
            }
        } else {
            // اختيار الحزب الذي يُحفظ في المحفوظ الجديد في ش4.
            EmptyTrackCard(track: track)
        }
    }

    /// لا يُفتح إلا مسار واحد في وقت واحد؛ فتح مسار يطوي غيره (7.1).
    private func toggle(_ track: Track, proxy: ScrollViewProxy) {
        if openTrack == track {
            openTrack = nil
            proxy.scrollTo("card.\(track.rawValue)", anchor: .top)
        } else {
            openTrack = track
            // ينزل إلى موضع التوقّف عند الفتح (7.1). في ش1 هو أول المسار، فيُعرض من أعلى البطاقة.
            proxy.scrollTo("card.\(track.rawValue)", anchor: .top)
        }
    }
}

/// رأس هادئ (7.1، §6): اسم التطبيق وتاريخ اليوم على سطر واحد، وزرّ الإعدادات.
struct HomeHeader: View {
    var body: some View {
        HStack(alignment: .center) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: AppInfo.name)
                        .font(Theme.font(.semiBold, size: 22, relativeTo: .title2))
                        .foregroundStyle(Theme.text)
                        .accessibilityIdentifier("home.title")
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: WirdDate.header(context.date))
                        .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("home.date")
                }
            }
            Spacer(minLength: 8)
            // زرّ الإعدادات (§6). شاشة الإعدادات نفسها في ش6 (7.4).
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.iconButton, style: .continuous)
                        .strokeBorder(Theme.line, lineWidth: 1)
                )
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .accessibilityLabel(Text(verbatim: "الإعدادات"))
                .accessibilityIdentifier("home.settings")
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
        .environment(\.layoutDirection, .rightToLeft)
}
