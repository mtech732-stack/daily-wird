import SwiftUI

/// بطاقة المحفوظ الجديد وفيه حزب أو أكثر (7.1، system.md §15.2):
/// مطويّة على صفّ الأوجه الخمسة الذي فيه موضع التوقّف، أو مفتوحة على أوجه أحزابها كلها (§15.3).
struct NewTrackCard: View {
    let layout: NewTrackLayout
    let isOpen: Bool
    /// الصفّ المطويّ المعروض: صفّ موضع التوقّف، أو صفّه السابق في مهلة 0.8 ث (§15.3، ذ30).
    var displayedRow: FiveRow?
    /// ضغطة على الوجه: أتممته الآن، أو تراجع (§15.3).
    var onPage: (Int) -> Void = { _ in }
    let onToggle: () -> Void
    /// «إضافة» من «⋯» تفتح ورقة «الحزب الذي تحفظه» (§15.6).
    var onAdd: () -> Void = {}
    var onManage: (ManageMode) -> Void = { _ in }
    /// موضع أسفل شريط «طيّ» في الشاشة المرئية، حين تكون البطاقة مفتوحة (م23).
    var onFoldBarMove: (CGFloat) -> Void = { _ in }

    private static let track = Track.newMemorization

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrackHeader(track: Self.track, progress: layout.progressText, showsMenu: true, onAdd: onAdd,
                        onManage: onManage, manageModes: [.remove])
                .padding(.horizontal, isOpen ? 8 : 0)
            if isOpen {
                // لكل حزب قسم بأرضية `paper` وزاوية 18 وحشو 6/10، وأوجهه كلها صفوفاً خمسة خمسة (§15.3).
                // ولا نزول تلقائي: الأوجه 9–14 تُرى كلها.
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(layout.hizbs, id: \.self) { hizb in
                        NewHizbBlock(layout: layout, hizb: hizb, rows: NewTrackLayout.rows(ofHizb: hizb), under: Theme.paper,
                                     onPage: onPage)
                            .padding(.top, 6)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.sura, style: .continuous).fill(Theme.paper))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sura, style: .continuous)
                                .strokeBorder(Theme.line, lineWidth: 1))
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("section.new.\(hizb)")
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 6)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("track.new.archive")
                PullBar(track: Self.track, isOpen: true, action: onToggle)
                    .padding(.top, 4)
                    .padding(.horizontal, -8)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .named(FoldBarPosition.space)).maxY
                    } action: { maxY in
                        onFoldBarMove(maxY)
                    }
            } else {
                // في المهلة يبقى الصفّ بما أُتمّ وعلامة «اليوم» بلا إطار، ثم يتلاشى إلى صفّ الموضع 0.25 ث (ذ30).
                ZStack(alignment: .leading) {
                    if let row = displayedRow ?? layout.foldedRow {
                        NewHizbBlock(layout: layout, hizb: row.hizb, rows: [row.pages], under: Theme.card,
                                     showsBookmark: displayedRow == nil || displayedRow == layout.foldedRow, onPage: onPage)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("track.new.folded")
                            .id(row)
                            .transition(.opacity)
                    }
                }
                PullBar(track: Self.track, isOpen: false, closedTitle: "عرض كل أوجه الحزب", action: onToggle)
                    .padding(.top, 4)
                    .padding(.horizontal, -16)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, isOpen ? 8 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackground())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("track.new.card")
    }
}

/// سطر الحزب ثم أوجهه صفوفاً خمسة خمسة: شبكة أعمدتها 44 بفراغ 8، وبين الصفوف 10 (§15.2).
struct NewHizbBlock: View {
    let layout: NewTrackLayout
    let hizb: Int
    let rows: [[Int]]
    /// لون ما تحت المربّع: `card` في البطاقة المطويّة، و`paper` في قسم الحزب.
    let under: Color
    /// الإطار وعلامة الكتاب، ولا يظهران في الصفّ الباقي في المهلة (ذ30).
    var showsBookmark = true
    var onPage: (Int) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NewHizbLine(hizb: hizb, isBookmark: showsBookmark && layout.bookmarkHizb == hizb)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { page in
                            PageTile(page: page, isDone: layout.completed.contains(page),
                                     isToday: layout.today.contains(page),
                                     isBookmark: showsBookmark && page == layout.bookmarkPage, under: under,
                                     label: layout.pageLabel(page, showsBookmark: showsBookmark)) {
                                onPage(page)
                            }
                        }
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }
}

/// سطر الحزب بارتفاع 30 (§15.2، ذ28): علامة الكتاب إن كان فيه موضع التوقّف، ثم «ح 12» 14/500 `ink`،
/// ثم «· المائدة · الجزء 6» 13 `muted` يُختصر بنقاط إن ضاق. ومساحة لمس «ح» 44 صريحة.
struct NewHizbLine: View {
    let hizb: Int
    let isBookmark: Bool

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                if isBookmark && Slice.showsBookmark {
                    BookmarkGlyph()
                        .fill(Theme.ink)
                        .frame(width: 11, height: 14)
                        .accessibilityHidden(true)
                }
                Text(verbatim: Digits.hizbLabel(hizb))
                    .font(Theme.font(.medium, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .fixedSize()
            }
            // مساحة اللمس 44 تمتدّ 7 فوق السطر وتحته، و8 جانباً، ولا تزيد ارتفاعه.
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .padding(.vertical, -7)
            .padding(.horizontal, -8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: "الحزب \(Digits.en(hizb))" + (isBookmark && Slice.showsBookmark ? "، فيه موضع التوقّف" : "")))
            .accessibilityIdentifier("hizb.new.\(hizb)")
            Text(verbatim: NewTrackLayout.hizbLine(hizb))
                .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("hizb.new.\(hizb).line")
        }
        .frame(minHeight: 30, alignment: .leading)
    }
}

/// مربّع الوجه 44×44 بزاوية 11 (§5، §15): محفوظ = ممتلئ بلون الجديد ورقمه `onNew`، ولم يُحفظ = فارغ
/// بحدّ `newInk` 70%. ورقمه رقم الوجه في المصحف. وموضع التوقّف إطار 3 يبعد 3، وعلامة «اليوم» كما في الربع.
struct PageTile: View {
    let page: Int
    let isDone: Bool
    let isToday: Bool
    let isBookmark: Bool
    var under: Color = Theme.card
    let label: String
    var onTap: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// المربّع تحت الإصبع: يصغر إلى 0.94 (§13.1).
    @State private var pressed = false

    var body: some View {
        let track = Track.newMemorization
        AgeFace(level: isDone ? .full : .empty, color: Theme.trackColor(track), ink: Theme.tileInk(track),
                on: Theme.onTrack(track), under: under, number: Digits.en(page))
            // التعبئة تتغيّر بتلاشٍ 0.15 ث، وفوراً مع «تقليل الحركة» (§13.1).
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isDone)
            .frame(width: Theme.Size.tile, height: Theme.Size.tile)
            .overlay {
                if isBookmark && Slice.showsBookmark {
                    RoundedRectangle(cornerRadius: Theme.Radius.tile + 4.5, style: .continuous)
                        .stroke(Theme.ink, lineWidth: 3)
                        .padding(-4.5)
                }
            }
            .overlay {
                // علامة «اليوم» تظهر من 0.6 إلى حجمها في 0.18 ث (§13.1).
                ZStack {
                    if isToday {
                        TodayBadge(ink: Theme.tileInk(track))
                            .transition(.scale(scale: 0.6, anchor: UnitPoint(x: 2.5 / 44, y: 2.5 / 44)).combined(with: .opacity))
                    }
                }
                .frame(width: Theme.Size.tile, height: Theme.Size.tile)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isToday)
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .scaleEffect(pressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
            .onTapGesture(perform: onTap)
            .onLongPressGesture(minimumDuration: 10) {} onPressingChanged: { pressed = $0 }
            .zIndex(isToday ? 1 : 0)
            // علامة «اليوم» في الزاوية العليا اليسرى بالإحداثيات الفعلية، كما في مربّع الربع.
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: label))
            .accessibilityHint(Text(verbatim: "ضغطة: أتممته أو تراجع"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onTap() }
            .accessibilityIdentifier("page.\(page)")
    }
}
