import SwiftUI

/// مفاتيح الرموز (7.1.3، design/system.md §6 و§13.6): بطاقة زاوية 22 وحشو 16، فيها ثلاث مجموعات،
/// تحت كل مربّع معناه 12. لا تظهر إلا بسحب الشاشة للأعلى: تأتي بعد الحالة المطويّة التي تملأ الشاشة،
/// أو بعد البطاقات في الأرشيف المفتوح. ولا شيء غير التمرير العادي.
struct SymbolKeys: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "مفاتيح الرموز")
                .font(Theme.font(.semiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 6)
                .accessibilityAddTraits(.isHeader)

            group("عمر الربع منذ آخر تلاوة · يتغيّر وحده مع الأيام")
            // معاني الدرجات الخمس بالأيام على سطرين (القرار 14، ذ15).
            row(columns: 5, [
                Key(kind: .age(.full, .farReview), text: "خلال\n7 أيام"),
                Key(kind: .age(.half, .farReview), text: "خلال\n15 يوماً"),
                Key(kind: .age(.quarter, .farReview), text: "خلال\n22 يوماً"),
                Key(kind: .age(.faded, .farReview), text: "أكثر\nمن 22"),
                Key(kind: .age(.empty, .farReview), text: "لم يُتلَ"),
            ])

            // العلامات على مربّع محايد لا يشبه أي درجة، حتى لا تلتبس بها (7.1.3).
            group("علامات تُضاف فوق أي ربع، أياً كان عمره")
            row(columns: 4, [
                Key(kind: .today, text: "تلوته اليوم"),
                Key(kind: .bookmark, text: "موضع التوقّف"),
                Key(kind: .shared, text: "بين سورتين"),
            ])

            group("المحفوظ الجديد")
            row(columns: 4, [
                Key(kind: .age(.full, .newMemorization), text: "وجه محفوظ"),
                Key(kind: .age(.empty, .newMemorization), text: "لم يُحفظ"),
            ])

            Text(verbatim: "ضغطة: تلوته أو تراجع · ضغطة مطوّلة: التفاصيل")
                .font(Theme.font(.regular, size: 12.5, relativeTo: .caption))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("keys")
    }

    private func group(_ title: String) -> some View {
        Text(verbatim: title)
            .font(Theme.font(.regular, size: 12.5, relativeTo: .caption))
            .foregroundStyle(Theme.muted)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }

    /// صفّ بأعمدة متساوية، وما نقص منها فراغ في مكانه.
    private func row(columns: Int, _ keys: [Key]) -> some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(0..<columns, id: \.self) { i in
                Group {
                    if i < keys.count { keys[i] } else { Color.clear.frame(height: 1) }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 4)
    }
}

/// رمز واحد في المفاتيح: المربّع 44 ومعناه تحته 12.
private struct Key: View {
    enum Kind {
        case age(AgeLevel, Track)
        case today, bookmark, shared
    }

    let kind: Kind
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            tile
                .frame(width: Theme.Size.tile, height: Theme.Size.tile)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityHidden(true)
            Text(verbatim: text)
                .font(Theme.font(.regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text.replacingOccurrences(of: "\n", with: " ")))
    }

    @ViewBuilder private var tile: some View {
        switch kind {
        case let .age(level, track):
            AgeFace(level: level, color: Theme.trackColor(track), ink: Theme.tileInk(track),
                    on: Theme.onTrack(track), under: Theme.card, number: "3")
        case .today:
            ghost.overlay { TodayBadge(ink: Theme.ink) }
        case .bookmark:
            ghost.overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.tile + 4.5, style: .continuous)
                    .stroke(Theme.ink, lineWidth: 3)
                    .padding(-4.5)
            }
        case .shared:
            ghost.overlay { CutCorner().fill(Theme.card) }
        }
    }

    /// المربّع المحايد `ghost` (§1)، ورقمه `muted`.
    private var ghost: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
            .fill(Theme.ghost)
            .overlay {
                Text(verbatim: "3")
                    .font(Theme.fixedFont(.medium, size: 13))
                    .foregroundStyle(Theme.muted)
            }
    }
}

/// إشارة «اسحب للأعلى لمفاتيح الرموز» بمقبضها (§6): مقبض 36×4 بلون `line`، ثم النصّ 12 `muted`.
struct KeysHint: View {
    var body: some View {
        VStack(spacing: 4) {
            Capsule().fill(Theme.line).frame(width: 36, height: 4)
            Text(verbatim: "اسحب للأعلى لمفاتيح الرموز")
                .font(Theme.font(.regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "اسحب للأعلى لمفاتيح الرموز"))
        .accessibilityIdentifier("keys.hint")
    }
}
