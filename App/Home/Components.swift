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

/// ما تفعله قائمة الحزب في مساره (§12.5): نقل إلى المسار الآخر، أو إزالة منه.
struct HizbMenu {
    let track: Track
    let onMove: (Int) -> Void
    let onRemove: (Int) -> Void
}

/// قائمة الحزب بالضغط المطوّل على «ح [رقم]» (§12.5، م22): رأسها «ح 10 · النساء · الجزء 5»،
/// ثم «نقل إلى [المسار الآخر]»، ثم بعد فاصل «إزالة من المسار». الإزالة مفصولة بالفراغ وبرمزها
/// لا باللون (ذ7)، فلا تُعلَّم `destructive` كي لا يجعلها النظام حمراء.
private struct HizbMenuModifier: ViewModifier {
    let hizb: Int
    let menu: HizbMenu?

    func body(content: Content) -> some View {
        if let menu {
            content
                .contextMenu {
                    Section(Phrase.hizbMenuHeader(hizb)) {
                        Button { menu.onMove(hizb) } label: {
                            Label("نقل إلى \(Library.otherReviewTrack(menu.track).title)", systemImage: "arrow.left.arrow.right")
                        }
                    }
                    Section {
                        Button { menu.onRemove(hizb) } label: {
                            Label("إزالة من المسار", systemImage: "trash")
                        }
                    }
                }
                .accessibilityIdentifier("hizb.\(menu.track.rawValue).\(hizb)")
        } else {
            content
        }
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
