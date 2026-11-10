import SwiftUI

/// عنوان المسار (§6): شريط لونه، والعنوان 19/600، وتقدّم الدورة، و«⋯».
struct TrackHeader: View {
    let track: Track
    var progress: String?
    var showsMenu: Bool
    var onAdd: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            TrackMark(track: track)
            Text(verbatim: track.title)
                .font(Theme.font(.semiBold, size: 19, relativeTo: .headline))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let progress {
                Text(verbatim: progress)
                    .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("track.\(track.rawValue).progress")
            }
            if showsMenu {
                // قائمة المسار (7.1.1، §12.4). في مسار فارغ «إضافة» وحدها (م21).
                Menu {
                    Button(action: onAdd) { Label("إضافة", systemImage: "plus.circle") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                        .contentShape(Rectangle())
                }
                .padding(.vertical, -7)
                .padding(.trailing, -12)
                .accessibilityLabel(Text(verbatim: "قائمة \(track.title)"))
                .accessibilityIdentifier("track.\(track.rawValue).more")
            }
        }
        .frame(minHeight: 30)
    }
}

/// البطاقة الفارغة (§12.1، 5.1): التطبيق يبدأ فارغاً حتى يضيف المالك محفوظه.
struct EmptyTrackCard: View {
    let track: Track
    var onAdd: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrackHeader(track: track, progress: nil, showsMenu: track.isReview, onAdd: onAdd)
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: track.isReview ? "لم تُضف إليه شيئاً بعد." : "لم تحدّد بعدُ الحزب الذي تحفظه.")
                    .font(Theme.font(.regular, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("track.\(track.rawValue).emptyText")
                if track.isReview {
                    // يفتح ورقة الإضافة على هذا المسار. ولا زرّ في الجديد حتى ش4.
                    Button(action: onAdd) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .accessibilityHidden(true)
                            Text(verbatim: "أضف جزءاً أو حزباً")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("track.\(track.rawValue).add")
                }
            }
            .padding(.top, 6)
        }
        .padding(.top, 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackground())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("track.\(track.rawValue).empty")
    }
}

/// خلفية البطاقة: `card`، حدّ `line`، زاوية 22 (§6).
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(Theme.line, lineWidth: 1)
            )
    }
}

/// بطاقة مسار مراجعة فيه محفوظ: مطويّة على موضع التوقّف، أو مفتوحة على أرشيفه (7.1).
struct ReviewTrackCard: View {
    let layout: ReviewTrackLayout
    let isOpen: Bool
    /// ضيق الصفّ المطويّ (أقل من 330): السورة 13 والمسافات 6 (§6).
    let narrow: Bool
    let onToggle: () -> Void
    var onAdd: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrackHeader(track: layout.track, progress: layout.progressText, showsMenu: true, onAdd: onAdd)
                .padding(.horizontal, isOpen ? 8 : 0)
            if isOpen {
                ArchiveView(layout: layout)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            } else {
                if let row = layout.foldedRow {
                    FoldedRowView(track: layout.track, row: row, bookmark: layout.bookmarkQuarter, narrow: narrow)
                }
                // عنوان البطاقة لا يفتح شيئاً؛ الشريط وحده يُسدلها (7.1).
                PullBar(track: layout.track, isOpen: false, action: onToggle)
                    .padding(.top, 4)
                    .padding(.horizontal, -16)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, isOpen ? 8 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackground())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("track.\(layout.track.rawValue).card")
    }
}

/// صفّ الحزب الذي فيه موضع التوقّف بأرباعه الأربعة، وعلى يساره السورة ووسم الجزء (7.1، §6).
struct FoldedRowView: View {
    let track: Track
    let row: FoldedRow
    let bookmark: Int?
    let narrow: Bool

    var body: some View {
        let gap: CGFloat = narrow ? 6 : 8
        HStack(spacing: gap) {
            HizbLabel(hizb: row.hizb, isBookmark: true, width: narrow ? Theme.Size.hizbLabelWidthNarrow : Theme.Size.hizbLabelWidth)
            HStack(spacing: gap) {
                ForEach(row.quarters, id: \.self) { q in
                    QuarterTile(track: track, quarter: q, isBookmark: q == bookmark)
                }
            }
            Spacer(minLength: 0)
            side
        }
        .frame(height: Theme.Size.rowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("track.\(track.rawValue).folded")
    }

    private var side: some View {
        let lines = row.suraLines
        return VStack(alignment: .trailing, spacing: lines.count > 1 ? 0 : 2) {
            if lines.count > 1 {
                ForEach(lines, id: \.self) { line in
                    Text(verbatim: line)
                        .font(Theme.font(.semiBold, size: 13, relativeTo: .subheadline))
                        .lineLimit(1)
                        .frame(height: 16)
                }
            } else {
                Text(verbatim: lines.first ?? "")
                    .font(Theme.font(.semiBold, size: narrow ? 13 : 15, relativeTo: .subheadline))
                    .lineLimit(1)
            }
            Text(verbatim: row.juzText)
                .font(Theme.font(.regular, size: 11.5, relativeTo: .caption2))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .foregroundStyle(Theme.ink)
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("track.\(track.rawValue).folded.suras")
    }
}

/// أرشيف المسار كاملاً داخل البطاقة (7.1): صفّ لكل حزب، ووسم الجزء عند أول حزب فيه.
/// وترتيبه بأقسام السور (7.1.1) في المرحلة التالية.
struct ArchiveView: View {
    let layout: ReviewTrackLayout

    var body: some View {
        let bookmark = layout.bookmarkQuarter
        VStack(alignment: .leading, spacing: 0) {
            ForEach(layout.archiveRows) { row in
                HStack(spacing: 8) {
                    HizbLabel(hizb: row.hizb, isBookmark: row.quarters.contains(bookmark ?? -1))
                    HStack(spacing: 8) {
                        ForEach(row.quarters, id: \.self) { q in
                            QuarterTile(track: layout.track, quarter: q, isBookmark: q == bookmark)
                        }
                    }
                    Spacer(minLength: 0)
                    if let juz = row.juzTag { JuzTag(juz: juz) }
                }
                .frame(height: Theme.Size.rowHeight)
                .padding(.horizontal, 6)
                .id("row.\(layout.track.rawValue).\(row.hizb)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("track.\(layout.track.rawValue).archive")
    }
}

/// شريط «طيّ» ملتصق بأسفل الشاشة أثناء فتح الأرشيف (7.1): خلفية `card` وزاويتا 22 أسفل.
struct StickyFoldBar: View {
    let track: Track
    let action: () -> Void

    var body: some View {
        PullBar(track: track, isOpen: true, action: action)
            .padding(.top, 8) // يعيد ما أخذته مساحة اللمس الممتدّة للأعلى
            .background(
                UnevenRoundedRectangle(bottomLeadingRadius: Theme.Radius.card, bottomTrailingRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.card)
            )
    }
}
