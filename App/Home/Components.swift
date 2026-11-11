import SwiftUI

// المكوّنات المشتركة في الشاشة الرئيسية، بقياسات design/system.md §5 و§6.

/// شريط لون المسار 5×24 بجانب عنوانه.
struct TrackMark: View {
    let track: Track
    var width: CGFloat = 5
    var height: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Theme.trackColor(track))
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

/// علامة الكتاب 11×14 بجانب رقم الحزب الذي فيه موضع التوقّف، بالشقّ الأعمق (الزخرفة م-ب، §10).
struct BookmarkGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        // المسار في مربّع 11×14: M1 0 h9 v14 l-4.5 -4.6 L1 14 z
        let sx = rect.width / 11, sy = rect.height / 14
        var p = Path()
        p.move(to: CGPoint(x: 1 * sx, y: 0))
        p.addLine(to: CGPoint(x: 10 * sx, y: 0))
        p.addLine(to: CGPoint(x: 10 * sx, y: 14 * sy))
        p.addLine(to: CGPoint(x: 5.5 * sx, y: 9.4 * sy))
        p.addLine(to: CGPoint(x: 1 * sx, y: 14 * sy))
        p.closeSubpath()
        return p
    }
}

/// «ح [رقم]» في عمود عرضه 48، ومعه علامة الكتاب إن كان فيه موضع التوقّف.
/// ارتفاع لمسه 44 صريحاً (م22)، للضغط المطوّل في مرحلة النقل والإزالة.
struct HizbLabel: View {
    let hizb: Int
    let isBookmark: Bool
    var width: CGFloat = Theme.Size.hizbLabelWidth
    /// قائمة الحزب بالضغط المطوّل (§12.5)، حيث يكون الحزب في مسار.
    var menu: HizbMenu?

    var body: some View {
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
        .frame(width: width, height: Theme.Size.touch, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "الحزب \(Digits.en(hizb))" + (isBookmark && Slice.showsBookmark ? "، فيه موضع التوقّف" : "")))
        .modifier(HizbMenuModifier(hizb: hizb, menu: menu))
    }
}

/// قائمة الحزب في مساره (§12.5): الضغط المطوّل على «ح [رقم]» يفتحها، ومعه موضع «ح» على الشاشة
/// لترفع الشاشة الصفّ وتضع القائمة تحته.
struct HizbMenu {
    let track: Track
    let open: (_ hizb: Int, _ labelFrame: CGRect) -> Void
}

/// موضع «ح» على الشاشة، يُحفظ بلا إعادة رسم مع كل تمرير، ويُقرأ عند الضغط المطوّل وحده.
final class FrameBox: @unchecked Sendable {
    var rect: CGRect = .zero
}

/// الضغط المطوّل (0.45 ث) على «ح [رقم]» يفتح قائمة الحزب المخصّصة (§12.5، م22). وليست قائمة
/// النظام `contextMenu`، لأنها تفرض لون رأسها فلا يبلغ تباينه 4.5:1 (م32، القاعدة 8.3)،
/// ولأن §12.5 ترفع الصفّ كلّه لا «ح» وحده.
struct HizbMenuModifier: ViewModifier {
    let hizb: Int
    let menu: HizbMenu?
    @State private var frame = FrameBox()

    func body(content: Content) -> some View {
        if let menu {
            content
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { rect in
                    frame.rect = rect
                }
                .onLongPressGesture(minimumDuration: 0.45) {
                    menu.open(hizb, frame.rect)
                }
                .accessibilityAction(named: Text(verbatim: "خيارات الحزب")) {
                    menu.open(hizb, frame.rect)
                }
                .accessibilityIdentifier("hizb.\(menu.track.rawValue).\(hizb)")
        } else {
            content
        }
    }
}

/// القائمة المفتوحة: أي حزب في أي مسار، وموضع «ح» على الشاشة.
struct HizbMenuRequest: Equatable {
    let track: Track
    let hizb: Int
    let labelFrame: CGRect
}

enum HizbMenuAction: Equatable {
    case move(Track), remove
}

/// قائمة الحزب كما في §12.5: تعتيم `scrim` يبقى الصفّ فوقه مرفوعاً (زاوية 14، يمتدّ 6 جانباً)،
/// وتحته بـ 8 قائمة عرضها 252 (فوقه إن لم تتّسع)، حافّتها اليمنى عند حافّة الصفّ:
/// رأس 12.5 `muted` «ح 10 · النساء · الجزء 5»، ثم «نقل إلى [مسار]» لكل مسار آخر (§15.6)، ثم فاصل 6 `ghost`،
/// ثم «إزالة من المسار». الإزالة مفصولة بالفراغ وبرمزها لا باللون (ذ7).
/// الضغط خارج القائمة يغلقها بلا فعل.
struct HizbMenuOverlay: View {
    let request: HizbMenuRequest
    let done: (HizbMenuAction?) -> Void

    @State private var menuHeight: CGFloat = 150

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let size = geo.size
            let label = request.labelFrame.offsetBy(dx: -origin.x, dy: -origin.y)
            // «ح» أول الصفّ من اليمين، والبطاقة في وسط الشاشة، فيسار الصفّ مقابل يمينه.
            let right = label.maxX + 6
            let left = size.width - label.maxX - 6
            let lift = CGRect(x: left, y: label.midY - Theme.Size.rowHeight / 2,
                              width: max(right - left, 0), height: Theme.Size.rowHeight)
            let below = lift.maxY + 8 + menuHeight <= size.height - geo.safeAreaInsets.bottom - 8
            let menuX = min(max(right - 252, 8), size.width - 252 - 8)
            let menuY = below ? lift.maxY + 8 : lift.minY - 8 - menuHeight

            ZStack(alignment: .topLeading) {
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: size))
                    p.addRoundedRect(in: lift, cornerSize: CGSize(width: 14, height: 14), style: .continuous)
                }
                .fill(Theme.scrim, style: FillStyle(eoFill: true))

                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
                    .frame(width: lift.width, height: lift.height)
                    .offset(x: lift.minX, y: lift.minY)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { done(nil) }
                    .accessibilityHidden(true)

                card
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { menuHeight = $0 }
                    .offset(x: menuX, y: menuY)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .ignoresSafeArea()
        // المواضع محسوبة من اليسار، فتُرسم الطبقة باتّجاه ثابت، والقائمة نفسها من اليمين.
        .environment(\.layoutDirection, .leftToRight)
    }

    private var card: some View {
        return VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: Phrase.hizbMenuHeader(request.hizb))
                .font(Theme.font(.regular, size: 12.5, relativeTo: .caption))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("hizbmenu.header")
                .accessibilityAddTraits(.isHeader)
            Rectangle().fill(Theme.line).frame(height: 1)
            // «نقل إلى …» لكل مسار آخر، بترتيب §15.6 (ذ32).
            ForEach(Library.destinations(from: request.track), id: \.self) { target in
                item(Phrase.hizbMenuMove(to: target), icon: "arrow.left.arrow.right",
                     id: "hizbmenu.move.\(target.rawValue)") { done(.move(target)) }
            }
            Rectangle().fill(Theme.ghost).frame(height: 6)
                .accessibilityHidden(true)
            item("إزالة من المسار", icon: "trash", id: "hizbmenu.remove") { done(.remove) }
        }
        .frame(width: 252)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
        .shadow(color: Color(red: 0x0A / 255, green: 0x16 / 255, blue: 0x24 / 255).opacity(0.22), radius: 16, y: 12)
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { done(nil) }
        .accessibilityIdentifier("hizbmenu")
    }

    private func item(_ text: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(verbatim: text)
                    .font(Theme.font(.regular, size: 16, relativeTo: .body))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .regular))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Theme.ink)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowStyle())
        .accessibilityLabel(Text(verbatim: text))
        .accessibilityIdentifier(id)
    }
}

/// بند القائمة: يُظلَّل بـ `ghost` أثناء الضغط.
private struct MenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.ghost : Color.clear)
    }
}

/// مربّع الربع 44×44 بزاوية 11 (§5)، يُضغط فيُظلَّل (5.3، §13.1).
/// - لم يُتلَ (الدرجة 5): فارغ بحدّ 1.5 بلون المسار 70%، ورقمه بلون المسار.
/// - تُلي اليوم: ممتلئ بلون المسار ورقمه `on…` (الدرجة 1)، وعليه علامة «اليوم».
///   (ودرجات العمر الأخرى في مرحلتها من ش2.)
/// - موضع التوقّف إطار 3 بلون النصّ يبعد 3 عن المربّع، ولا يظهر في ش2 (ذ16).
/// - الربع المشترك: الزاوية العليا اليمنى مقطوعة بمثلّث 15 بلون ما تحته (§5، 7.1.1).
struct QuarterTile: View {
    let track: Track
    let quarter: Int
    let isBookmark: Bool
    var isShared: Bool = false
    /// لون ما تحت المربّع، للزاوية المقطوعة: `card` في البطاقة المطويّة، و`paper` في قسم السورة.
    var under: Color = Theme.card
    /// حالة التظليل والضغطة. بلا حالة (معاينات ش1) يُرسم المربّع «لم يُتلَ» ولا يُضغط.
    var shading: ShadingState?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// المربّع تحت الإصبع: يصغر إلى 0.94 (§13.1).
    @State private var pressed = false

    private var isToday: Bool { shading?.isToday(quarter) ?? false }
    /// درجة العمر (5.4، القرار 14).
    private var level: AgeLevel { shading?.level(quarter) ?? .empty }

    var body: some View {
        // الضغطة تظلّل أو تتراجع، والضغطة المطوّلة 0.45 ث تفتح التفاصيل ولا تظلّل شيئاً (7.3، §13.5).
        // لا `Button` هنا: الضغطة المطوّلة المضافة إلى زرّ لم تفتح التفاصيل في اختبار الواجهة (#69)،
        // والزرّ يُطلق فعله عند الرفع فيظلّل. فإيماءتان على المربّع: تفوز المطوّلة إن طال الضغط، وإلا فالضغطة.
        face
            .scaleEffect(pressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
            .onTapGesture {
                shading?.tap(quarter, track)
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                shading?.details(quarter, track, isShared)
            } onPressingChanged: { pressing in
                pressed = pressing
            }
            .allowsHitTesting(shading != nil)
            .zIndex(isToday ? 1 : 0)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim:
            "الحزب \(Digits.en(Quran.quarter(quarter).hizb))، الربع \(Digits.en(Quran.position(ofQuarter: quarter)))"
            + (isShared ? "، ربع مشترك" : "")
            + (isBookmark && Slice.showsBookmark ? "، موضع التوقّف" : "")))
        .accessibilityValue(Text(verbatim: isToday ? "تلوته اليوم" : level.meaning))
        .accessibilityHint(Text(verbatim: "ضغطة: تلوته أو تراجع"))
        .accessibilityAction {
            shading?.tap(quarter, track)
        }
        // التفاصيل إجراء مخصّص، لأن الضغط المطوّل لا يصل إليه كل أحد (§13.7).
        .accessibilityAction(named: Text(verbatim: "التفاصيل")) {
            shading?.details(quarter, track, isShared)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("quarter.\(track.rawValue).\(quarter)")
    }

    private var face: some View {
        let color = Theme.trackColor(track)
        let ink = Theme.tileInk(track)
        return AgeFace(level: level, color: color, ink: ink, on: Theme.onTrack(track), under: under,
                       number: Digits.en(Quran.position(ofQuarter: quarter)))
        // التعبئة تتغيّر بتلاشٍ 0.15 ث، وفوراً مع «تقليل الحركة» (§13.1).
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: level)
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
                    TodayBadge(ink: ink)
                        .transition(.scale(scale: 0.6, anchor: UnitPoint(x: 2.5 / 44, y: 2.5 / 44)).combined(with: .opacity))
                }
            }
            .frame(width: Theme.Size.tile, height: Theme.Size.tile)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isToday)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        // الزاوية المقطوعة (العليا اليمنى) وعلامة «اليوم» (العليا اليسرى) بالإحداثيات الفعلية كما في §5.
        // واتجاه الشاشة من اليمين يعكس رسم الأشكال، فكانت الزاوية تُقطع من اليسار، والعلامة تقع
        // عليها وصحّها مقلوب. فيُرسم وجه المربّع باتّجاه ثابت؛ ولا نصّ فيه إلا رقم الربع.
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// وجه المربّع بدرجة عمره (§5، القرار 14). الفروق بالامتلاء والشكل لا باللون وحده (8.3):
/// 1 ممتلئ · 2 نصفه الأسفل وحدّ 2 · 3 ربعه الأسفل (11) وحدّ 2 · 4 تخطيط مائل 135° وحدّ 1.5 70%،
/// ورقمه على رقعة بلون ما تحته · 5 فارغ بحدّ 1.5 70%.
struct AgeFace: View {
    let level: AgeLevel
    /// لون المسار `c`.
    let color: Color
    /// لون رقمه وحدّه `ci`.
    let ink: Color
    /// لون الرقم على الممتلئ `on…`.
    let on: Color
    /// لون ما تحت المربّع، لرقعة الرقم في المخطّط.
    let under: Color
    let number: String

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous) }

    var body: some View {
        ZStack {
            switch level {
            case .full:
                shape.fill(color)
            case .half, .quarter:
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle().fill(color).frame(height: level == .half ? 22 : 11)
                }
                .clipShape(shape)
                shape.strokeBorder(color, lineWidth: 2)
            case .faded:
                Stripes().stroke(color.opacity(0.7), lineWidth: 2.5)
                    .clipShape(shape)
                shape.strokeBorder(ink.opacity(0.7), lineWidth: 1.5)
            case .empty:
                shape.strokeBorder(ink.opacity(0.7), lineWidth: 1.5)
            }
            numberView
        }
        .frame(width: Theme.Size.tile, height: Theme.Size.tile)
    }

    @ViewBuilder
    private var numberView: some View {
        switch level {
        case .full:
            Text(verbatim: number).font(Theme.fixedFont(.medium, size: 13)).foregroundStyle(on)
        case .half:
            Text(verbatim: number).font(Theme.fixedFont(.medium, size: 11)).foregroundStyle(ink).offset(y: -9)
        case .quarter:
            Text(verbatim: number).font(Theme.fixedFont(.medium, size: 13)).foregroundStyle(ink).offset(y: -5)
        case .faded:
            Text(verbatim: number).font(Theme.fixedFont(.medium, size: 13)).foregroundStyle(ink)
                .padding(.horizontal, 4)
                .frame(height: 18)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(under))
        case .empty:
            Text(verbatim: number).font(Theme.fixedFont(.medium, size: 13)).foregroundStyle(ink)
        }
    }
}

/// تخطيط مائل كما في التصميم (`repeating-linear-gradient(135deg, c 0 2.5px, transparent 2.5px 7px)`):
/// خطوط عرضها 2.5 كل 7 على امتداد القطر من الأعلى يساراً، فتجري من أسفل اليسار إلى أعلى اليمين.
struct Stripes: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r2 = 2.0.squareRoot()
        let span = rect.width + rect.height
        var k = 0.0
        while (7 * k + 1.25) * r2 <= span + 7 {
            // الخطّ x + y = c، ومركز الشريط عند 1.25 من بدايته على امتداد القطر.
            let c = (7 * k + 1.25) * r2
            p.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
            k += 1
        }
        return p
    }
}

/// علامة «اليوم» (§5، 8.3): دائرة 17 بلون الأرضية حدّها 2 بلون رقم المسار، فيها صحّ (7×4، خطّ 2)،
/// مركزها قرب الزاوية العليا اليسرى وتبرز 6 خارج المربّع. بالإحداثيات الفعلية كما في التصميم،
/// لا تتبع اتجاه الكتابة. تُميَّز بشكلها لا بلونها، فتُقرأ بالرمادي.
struct TodayBadge: View {
    let ink: Color

    var body: some View {
        ZStack {
            BadgeDisc(radius: 8.5).fill(Theme.paper)
            BadgeDisc(radius: 9.5).stroke(ink, lineWidth: 2)
            BadgeCheck().stroke(ink, style: StrokeStyle(lineWidth: 2, lineCap: .butt, lineJoin: .miter))
        }
    }
}

/// دائرة مركزها (2.5، 2.5) من الزاوية العليا اليسرى للمربّع: أعلى 6- ويسار 6- ونصف قطر 8.5.
struct BadgeDisc: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.minX + 2.5, y: rect.minY + 2.5)
        return Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// الصحّ: ضلعا زاوية 7×4 مدوّرة 45° كما في التصميم (ds.css `.today:before`).
struct BadgeCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX - 1.1, y: rect.minY + 1.85))
        p.addLine(to: CGPoint(x: rect.minX + 2.44, y: rect.minY + 5.39))
        p.addLine(to: CGPoint(x: rect.minX + 8.1, y: rect.minY - 0.27))
        return p
    }
}

/// مثلّث الزاوية العليا اليمنى (بالإحداثيات الفعلية، لا يتبع اتجاه الكتابة): ضلعاه 15،
/// ويمتدّ نقطة خارج المربّع ليغطّي حدّه.
struct CutCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX - 15, y: rect.minY - 1))
        p.addLine(to: CGPoint(x: rect.maxX + 1, y: rect.minY - 1))
        p.addLine(to: CGPoint(x: rect.maxX + 1, y: rect.minY + 15))
        p.closeSubpath()
        return p
    }
}

/// خانة فارغة في مكان ربع ليس في هذا الصفّ، فلا تتحرّك الخانات (7.1.1).
struct QuarterGap: View {
    var body: some View {
        Color.clear.frame(width: Theme.Size.tile, height: Theme.Size.tile).accessibilityHidden(true)
    }
}

/// وسم الجزء: كبسولة 11.5 بحدّ `line` وحشو 2×7 (§6).
struct JuzTag: View {
    let juz: Int

    var body: some View {
        Text(verbatim: "الجزء \(Digits.en(juz))")
            .font(Theme.font(.regular, size: 11.5, relativeTo: .caption2))
            .foregroundStyle(Theme.muted)
            .lineLimit(1)
            .fixedSize()
            .padding(.vertical, 2)
            .padding(.horizontal, 7)
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
    }
}

/// زرّ ثانوي (§6): ارتفاع 50، زاوية 14، حدّ 1.5 بلون النصّ، 16/500.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.medium, size: 16, relativeTo: .body))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// شريط الإسدال أسفل البطاقة (7.1، §6): فاصل أعلاه، ارتفاعه 36، ومساحة لمسه 44
/// تمتدّ 8 للأعلى داخل البطاقة لا للأسفل حيث يغطّيها ما بعدها (م14).
struct PullBar: View {
    let track: Track
    let isOpen: Bool
    var identifier: String?
    /// نصّ الشريط مطويّاً: «عرض كامل المراجعة»، وفي المحفوظ الجديد «عرض كل أوجه الحزب» (§15.2).
    var closedTitle = "عرض كامل المراجعة"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Rectangle().fill(Theme.line).frame(height: 1)
                HStack(spacing: 6) {
                    Text(verbatim: isOpen ? "طيّ" : closedTitle)
                        .font(Theme.font(.medium, size: 13.5, relativeTo: .footnote))
                        .foregroundStyle(Theme.ink)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 35)
            }
            .padding(.top, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, -8)
        .accessibilityIdentifier(identifier ?? "track.\(track.rawValue).pull")
    }
}
