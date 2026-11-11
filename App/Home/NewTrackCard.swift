import SwiftUI

/// بطاقة المحفوظ الجديد وفيه حزب أو أكثر (7.1، system.md §15.2):
/// مطويّة على صفّ الأوجه الخمسة الذي فيه موضع التوقّف، أو مفتوحة على أوجه أحزابها كلها (§15.3).
struct NewTrackCard: View {
    let layout: NewTrackLayout
    let isOpen: Bool
    /// الصفّ المطويّ المعروض: صفّ موضع التوقّف، أو صفّه السابق في مهلة 0.8 ث (§15.3، ذ30).
    var displayedRow: FiveRow?
    /// قائمة الحزب بالضغط المطوّل على «ح» (§15.6).
    var hizbMenu: HizbMenu?
    /// ضغطة على الوجه: أتممته الآن، أو تراجع (§15.3).
    var onPage: (Int) -> Void = { _ in }
    /// «ارفع ح 12 إلى مراجعة القريب» (§15.5، ذ33).
    var onRaise: (Int) -> Void = { _ in }
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
                        onManage: onManage)
                .padding(.horizontal, isOpen ? 8 : 0)
            if isOpen {
                // لكل حزب قسم بأرضية `paper` وزاوية 18 وحشو 6/10، وأوجهه كلها صفوفاً خمسة خمسة (§15.3).
                // ولا نزول تلقائي: الأوجه 9–14 تُرى كلها.
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(layout.hizbs, id: \.self) { hizb in
                        NewHizbBlock(layout: layout, hizb: hizb, rows: NewTrackLayout.rows(ofHizb: hizb), under: Theme.paper,
                                     menu: hizbMenu, onPage: onPage, onRaise: onRaise)
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
                                     showsBookmark: displayedRow == nil || displayedRow == layout.foldedRow,
                                     menu: hizbMenu, onPage: onPage, onRaise: onRaise)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("track.new.folded")
                            .id(row)
                            .transition(.opacity)
                    }
                }
                // حزب آخر اكتمل ولم يُرفع (حزبان في الجديد) يبقى زرّه ظاهراً (§15.5).
                let shown = (displayedRow ?? layout.foldedRow)?.hizb
                ForEach(layout.completeHizbs.filter { $0 != shown }, id: \.self) { hizb in
                    RaiseButton(hizb: hizb) { onRaise(hizb) }
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
    var menu: HizbMenu?
    var onPage: (Int) -> Void = { _ in }
    var onRaise: (Int) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NewHizbLine(hizb: hizb, isBookmark: showsBookmark && layout.bookmarkHizb == hizb, menu: menu)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { page in
                            PageTile(page: page, isDone: layout.completed.contains(page),
                                     isToday: layout.today.contains(page),
                                     isBookmark: showsBookmark && page == layout.bookmarkPage, under: under,
                                     isShared: Quran.sharingHizb(page: page, inHizb: hizb) != nil,
                                     label: layout.pageLabel(page, inHizb: hizb, showsBookmark: showsBookmark)) {
                                onPage(page)
                            }
                        }
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
            // بعد «لاحقاً» يبقى زرّ الرفع تحت أوجه الحزب ما دام مكتملاً (ذ33).
            if layout.isComplete(hizb) {
                RaiseButton(hizb: hizb) { onRaise(hizb) }
            }
        }
    }
}

/// زرّ ثانوي «↑ ارفع ح 12 إلى مراجعة القريب» (§15.5، ذ33): ارتفاعه 44، ونصّه 15/500، وسهمه 18، وتحته 12.
struct RaiseButton: View {
    let hizb: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                Text(verbatim: Phrase.raiseButton(hizb))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .buttonStyle(RaiseButtonStyle())
        .padding(.top, 2)
        .padding(.bottom, 12)
        .accessibilityIdentifier("raise.\(hizb)")
    }
}

/// حوار اكتمال الحزب (§15.5، النموذج المعتمد 6): فوق تعتيم `scrim`، دائرة 58 بلون الجديد فيها صحّ 28
/// بخطّ 2.6 بلون `onNew`، ثم «اكتمل الحزب 12» 21/600، ثم سطرا الشرح 14.5 `muted`، ثم زرّ الرفع و«لاحقاً».
struct HizbCompleteDialog: View {
    let hizb: Int
    let answer: (_ raise: Bool) -> Void

    var body: some View {
        ZStack {
            Theme.scrim.ignoresSafeArea()
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Theme.trackColor(.newMemorization))
                    CheckGlyph()
                        .stroke(Theme.onTrack(.newMemorization),
                                style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                        .frame(width: 28, height: 28)
                        // علامة الصحّ لا تنعكس في العربية (م51).
                        .environment(\.layoutDirection, .leftToRight)
                }
                .frame(width: 58, height: 58)
                .padding(.bottom, 2)
                .accessibilityHidden(true)
                Text(verbatim: Phrase.hizbCompleteTitle(hizb))
                    .font(Theme.font(.semiBold, size: 21, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("complete.title")
                Text(verbatim: Phrase.hizbCompleteNote(hizb) + "\n" + Phrase.raiseQuestion)
                    .font(Theme.font(.regular, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("complete.note")
                VStack(spacing: 8) {
                    Button { answer(true) } label: { Text(verbatim: Phrase.raiseAnswer) }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("complete.raise")
                    Button { answer(false) } label: { Text(verbatim: "لاحقاً") }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityIdentifier("complete.later")
                }
                .padding(.top, 8)
            }
            .padding(.top, 26)
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.dialog, style: .continuous).fill(Theme.paper))
            .padding(.horizontal, 28)
            // لقارئ الشاشة حوار تنبيه (§15.8): يُحصر فيه، ويُغلق بإيماءة الخروج على «لاحقاً».
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape) { answer(false) }
            .accessibilityIdentifier("complete.dialog")
        }
    }
}

/// صحّ الحوار في مربّع 24 كما في التصميم: M5 12.5 l4.5 4.5 L19 7.5.
struct CheckGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        var p = Path()
        p.move(to: CGPoint(x: 5 * s, y: 12.5 * s))
        p.addLine(to: CGPoint(x: 9.5 * s, y: 17 * s))
        p.addLine(to: CGPoint(x: 19 * s, y: 7.5 * s))
        return p
    }
}

/// سطر الحزب بارتفاع 30 (§15.2، ذ28): علامة الكتاب إن كان فيه موضع التوقّف، ثم «ح 12» 14/500 `ink`،
/// ثم «· المائدة · الجزء 6» 13 `muted` يُختصر بنقاط إن ضاق. ومساحة لمس «ح» 44 صريحة.
struct NewHizbLine: View {
    let hizb: Int
    let isBookmark: Bool
    /// قائمة الحزب بالضغط المطوّل على «ح» (§15.6).
    var menu: HizbMenu?

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
            .modifier(HizbMenuModifier(hizb: hizb, menu: menu))
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
    /// الوجه المشترك بين حزبين: الزاوية العليا اليمنى مقطوعة كالربع المشترك (§15.4).
    var isShared = false
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
                if isShared {
                    CutCorner().fill(under).accessibilityHidden(true)
                }
            }
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

/// زرّ ثانوي بارتفاع 44 ونصّ 15/500، بحدّ 1.5 `ink` وزاوية 14 (§6، §15.5).
private struct RaiseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.medium, size: 15, relativeTo: .subheadline))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
