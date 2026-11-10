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
            if isBookmark {
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
        .accessibilityLabel(Text(verbatim: "الحزب \(Digits.en(hizb))" + (isBookmark ? "، موضع التوقّف" : "")))
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
private struct HizbMenuModifier: ViewModifier {
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

enum HizbMenuAction {
    case move, remove
}

/// قائمة الحزب كما في §12.5: تعتيم `scrim` يبقى الصفّ فوقه مرفوعاً (زاوية 14، يمتدّ 6 جانباً)،
/// وتحته بـ 8 قائمة عرضها 252 (فوقه إن لم تتّسع)، حافّتها اليمنى عند حافّة الصفّ:
/// رأس 12.5 `muted` «ح 10 · النساء · الجزء 5»، ثم «نقل إلى [المسار الآخر]»، ثم فاصل 6 `ghost`،
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
        let other = Library.otherReviewTrack(request.track)
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
            item(Phrase.hizbMenuMove(to: other), icon: "arrow.left.arrow.right", id: "hizbmenu.move") { done(.move) }
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

/// مربّع الربع 44×44 بزاوية 11 (§5). في ش1 لا تظليل، فكل ربع «لم يُتلَ» (الدرجة 5):
/// فارغ بحدّ 1.5 بلون المسار 70%. وموضع التوقّف إطار 3 بلون النصّ يبعد 3 عن المربّع.
struct QuarterTile: View {
    let track: Track
    let quarter: Int
    let isBookmark: Bool
    /// ربع مشترك بين سورتين: الزاوية العليا اليمنى مقطوعة بمثلّث 15 بلون ما تحته (§5، 7.1.1).
    var isShared: Bool = false
    /// لون ما تحت المربّع، للزاوية المقطوعة: `card` في البطاقة المطويّة، و`paper` في قسم السورة.
    var under: Color = Theme.card

    var body: some View {
        let ink = Theme.tileInk(track)
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                .strokeBorder(ink.opacity(0.7), lineWidth: 1.5)
            Text(verbatim: Digits.en(Quran.position(ofQuarter: quarter)))
                .font(Theme.fixedFont(.medium, size: 13))
                .foregroundStyle(ink)
        }
        .frame(width: Theme.Size.tile, height: Theme.Size.tile)
        .overlay {
            if isShared {
                CutCorner().fill(under).accessibilityHidden(true)
            }
        }
        .overlay {
            if isBookmark {
                RoundedRectangle(cornerRadius: Theme.Radius.tile + 4.5, style: .continuous)
                    .stroke(Theme.ink, lineWidth: 3)
                    .padding(-4.5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim:
            "الحزب \(Digits.en(Quran.quarter(quarter).hizb)) الربع \(Digits.en(Quran.position(ofQuarter: quarter)))"
            + (isBookmark ? "، موضع التوقّف" : "")
            + (isShared ? "، بين سورتين" : "")))
        .accessibilityValue(Text(verbatim: "لم يُتلَ"))
        .accessibilityIdentifier("quarter.\(track.rawValue).\(quarter)")
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Rectangle().fill(Theme.line).frame(height: 1)
                HStack(spacing: 6) {
                    Text(verbatim: isOpen ? "طيّ" : "عرض كامل المراجعة")
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
