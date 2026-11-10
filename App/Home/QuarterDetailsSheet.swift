import SwiftUI

/// طلب تفاصيل ربع: الضغطة المطوّلة عليه في مسار، ومشتركاً كان أم لا.
struct QuarterDetailsRequest: Identifiable, Equatable {
    let quarter: Int
    let track: Track
    let isShared: Bool
    var id: String { "\(track.rawValue).\(quarter)" }
}

/// ورقة تفاصيل الربع (7.3، 5.4، design/system.md §13.5): ورقة منزلقة بطول محتواها،
/// تُغلق بالسحب للأسفل أو بالضغط خارجها. العرض فقط، إلا زرّ التراجع إن ظُلّل اليوم.
struct QuarterDetailsSheet: View {
    let request: QuarterDetailsRequest
    /// تظليلات الربع كلها، الأحدث أولاً.
    let history: [Date]
    let level: AgeLevel
    let isToday: Bool
    let now: Date
    let onUndo: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 560

    private var info: QuranTable.Quarter { Quran.quarter(request.quarter) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 2)
                .padding(.bottom, 10)
            row("المدى", divider: true) { value(QuarterDetails.range(request.quarter)) }
            row("السور", divider: true) { value(QuarterDetails.suras(request.quarter)) }
            row("الأوجه", divider: true) { value(QuarterDetails.pages(request.quarter)) }
            row("آخر تلاوة", divider: true) { lastReading }
            row("مرات التلاوة", divider: true) { value("\(history.count)") }
            row("آخر التواريخ", divider: false, center: true) { dates }
            if isToday {
                Button {
                    onUndo()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 18))
                            .accessibilityHidden(true)
                        Text(verbatim: "تراجع عن تظليل اليوم")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 10)
                .accessibilityIdentifier("details.undo")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 30)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 + 20 }
        .frame(maxHeight: .infinity, alignment: .top)
        .environment(\.layoutDirection, .rightToLeft)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.Radius.sheet)
        .presentationBackground(Theme.paper)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("details")
    }

    /// الرأس: المربّع نفسه 44 بدرجته وعلاماته، ثم «الحزب 5 · الربع 4» 21/600، وتحته «الجزء 3» 13
    /// ووسم «ربع مشترك» إن كان مشتركاً.
    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            tile
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "الحزب \(info.hizb) · الربع \(Quran.position(ofQuarter: request.quarter))")
                    .font(Theme.font(.semiBold, size: 21, relativeTo: .title2))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("details.title")
                HStack(spacing: 8) {
                    Text(verbatim: "الجزء \(info.juz)")
                        .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.muted)
                    if request.isShared {
                        Text(verbatim: "ربع مشترك")
                            .font(Theme.font(.regular, size: 12, relativeTo: .caption))
                            .foregroundStyle(Theme.muted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                    }
                }
            }
        }
    }

    private var tile: some View {
        let ink = Theme.tileInk(request.track)
        return AgeFace(level: level, color: Theme.trackColor(request.track), ink: ink,
                       on: Theme.onTrack(request.track), under: Theme.paper,
                       number: "\(Quran.position(ofQuarter: request.quarter))")
            .overlay { if request.isShared { CutCorner().fill(Theme.paper) } }
            .overlay { if isToday { TodayBadge(ink: ink) } }
            .frame(width: Theme.Size.tile, height: Theme.Size.tile)
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: isToday ? "تلوته اليوم" : level.meaning))
    }

    /// سطر: العنوان `muted` بعرض 86 على الأقلّ، والقيمة 500 إلى اليسار وتلتفّ (15، حشو 10، فاصل `line`).
    private func row(_ title: String, divider: Bool, center: Bool = false,
                     @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: center ? .center : .top, spacing: 12) {
            Text(verbatim: title)
                .foregroundStyle(Theme.muted)
                .frame(minWidth: 86, alignment: .leading)
            Spacer(minLength: 0)
            content()
        }
        .font(Theme.font(.regular, size: 15, relativeTo: .body))
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if divider { Rectangle().fill(Theme.line).frame(height: 1) }
        }
        .accessibilityElement(children: .combine)
    }

    private func value(_ text: String) -> some View {
        Text(verbatim: text)
            .font(Theme.font(.medium, size: 15, relativeTo: .body))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.trailing)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// آخر تلاوة: المدّة 600، وتحتها اليوم والتاريخ والوقت 13 `muted`؛ وإن لم يُتلَ «لم يُتلَ بعد».
    @ViewBuilder private var lastReading: some View {
        if let last = history.first {
            VStack(alignment: .trailing, spacing: 1) {
                Text(verbatim: LastEntry.relative(days: Age.days(from: last, to: now)))
                    .font(Theme.font(.semiBold, size: 15, relativeTo: .body))
                    .foregroundStyle(Theme.ink)
                Text(verbatim: LastEntry.stamp(last, now: now))
                    .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.muted)
            }
            .multilineTextAlignment(.trailing)
        } else {
            Text(verbatim: "لم يُتلَ بعد").foregroundStyle(Theme.muted)
        }
    }

    /// آخر التواريخ: حتى خمس كبسولات 13 بخلفية `ghost` وحشو 4×10 وفراغ 6، وتلتفّ.
    /// وتظليل اليوم كبسولة بحدّ 1.5 `ink` ونصّ «اليوم» 600. وإن لم يُتلَ «لا تواريخ بعد».
    @ViewBuilder private var dates: some View {
        let chips = QuarterDetails.chips(history, now: now)
        if chips.isEmpty {
            Text(verbatim: "لا تواريخ بعد").foregroundStyle(Theme.muted)
        } else {
            ChipsFlow(spacing: 6) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    Text(verbatim: chip.text)
                        .font(Theme.font(chip.isToday ? .semiBold : .regular, size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background {
                            if chip.isToday {
                                Capsule().strokeBorder(Theme.ink, lineWidth: 1.5)
                            } else {
                                Capsule().fill(Theme.ghost)
                            }
                        }
                        .fixedSize()
                }
            }
        }
    }
}

/// صفّ يلتفّ من البداية، ويُحاذى إلى نهاية السطر (إلى اليسار في العربية) كالقيم الأخرى.
private struct ChipsFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            // السطر يبدأ من الحافة الأمامية ويُدفع إلى نهايتها.
            var x = bounds.minX + (bounds.width - row.width)
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        var current: (indices: [Int], width: CGFloat, height: CGFloat) = ([], 0, 0)
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = ([index], size.width, size.height)
            } else {
                current = (current.indices + [index], needed, max(current.height, size.height))
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
