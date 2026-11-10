import SwiftUI

/// عنوان المسار (§6): شريط لونه، والعنوان 19/600، وتقدّم الدورة، و«⋯».
struct TrackHeader: View {
    let track: Track
    var progress: String?
    var showsMenu: Bool
    var onAdd: () -> Void = {}
    /// «نقل» و«إزالة» تفتحان ورقة الإدارة (§12.4). ولا تظهران في مسار فارغ (م21).
    var onManage: ((ManageMode) -> Void)?
    /// عدد أرباع المسار، لاختبارات الواجهة وحدها ما دام تقدّم الدورة مخفيّاً (ذ10).
    var quarterCount: Int?

    private static let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")

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
            if Self.isUITesting, let quarterCount {
                // لا يُرى ولا يُلمس: تقرؤه اختبارات الواجهة لتتحقّق من الإضافة والنقل والإزالة.
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel(Text(verbatim: Digits.en(quarterCount)))
                    .accessibilityIdentifier("track.\(track.rawValue).quarterCount")
                    .allowsHitTesting(false)
            }
            if showsMenu {
                // قائمة المسار (7.1.1، §12.4). في مسار فارغ «إضافة» وحدها (م21).
                Menu {
                    Button(action: onAdd) { Label("إضافة", systemImage: "plus.circle") }
                    if let onManage {
                        Button { onManage(.move) } label: { Label("نقل", systemImage: "arrow.left.arrow.right") }
                        Button { onManage(.remove) } label: { Label("إزالة", systemImage: "trash") }
                    }
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
    /// قائمة الحزب بالضغط المطوّل (§12.5).
    var hizbMenu: HizbMenu?
    /// التظليل: حالة الأرباع وضغطتها (5.3).
    var shading: ShadingState?
    let onToggle: () -> Void
    var onAdd: () -> Void = {}
    /// «نقل» و«إزالة» من «⋯» (§12.4).
    var onManage: (ManageMode) -> Void = { _ in }
    /// موضع أسفل شريط «طيّ» في الشاشة المرئية، حين يكون الأرشيف مفتوحاً (م23).
    var onFoldBarMove: (CGFloat) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrackHeader(track: layout.track, progress: Slice.showsCycleProgress ? layout.progressText : nil,
                        showsMenu: true, onAdd: onAdd, onManage: onManage, quarterCount: layout.quarters.count)
                .padding(.horizontal, isOpen ? 8 : 0)
            if isOpen {
                ArchiveView(layout: layout, menu: hizbMenu, shading: shading)
                    .padding(.top, 4)
                // «طيّ» في أسفل البطاقة؛ ويلتصق بأسفل الشاشة عند التمرير (م23).
                PullBar(track: layout.track, isOpen: true, action: onToggle)
                    .padding(.top, 4)
                    .padding(.horizontal, -8)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .named(FoldBarPosition.space)).maxY
                    } action: { maxY in
                        onFoldBarMove(maxY)
                    }
            } else {
                if let row = layout.foldedRow {
                    FoldedRowView(track: layout.track, row: row, bookmark: layout.bookmarkQuarter, narrow: narrow,
                                  menu: hizbMenu, shading: shading)
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
    var menu: HizbMenu?
    var shading: ShadingState?

    var body: some View {
        let gap: CGFloat = narrow ? 6 : 8
        HStack(spacing: gap) {
            HizbLabel(hizb: row.hizb, isBookmark: true, width: narrow ? Theme.Size.hizbLabelWidthNarrow : Theme.Size.hizbLabelWidth, menu: menu)
            HStack(spacing: gap) {
                ForEach(row.quarters, id: \.self) { q in
                    QuarterTile(track: track, quarter: q, isBookmark: q == bookmark, isShared: row.shared.contains(q),
                                shading: shading)
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

/// أرشيف المسار كاملاً داخل البطاقة، مرتّباً بالسور (7.1، 7.1.1): قسم لكل سورة،
/// وتحته صفوف أحزابها بخاناتها الأربع في أماكنها الثابتة، وما ليس في السورة فراغ في مكانه.
struct ArchiveView: View {
    let layout: ReviewTrackLayout
    var menu: HizbMenu?
    var shading: ShadingState?

    var body: some View {
        let bookmark = layout.bookmarkQuarter
        VStack(alignment: .leading, spacing: 12) {
            ForEach(layout.sections) { section in
                SuraSectionView(track: layout.track, section: section, bookmark: bookmark, menu: menu, shading: shading)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("track.\(layout.track.rawValue).archive")
    }
}

/// قسم السورة (§6): العنوان 17/600 وتحته مسطرتان ذهبيتان (م-أ)، ومدى الأحزاب على يساره،
/// ثم صفوف الأحزاب. وفي الأرشيف المفتوح على أرضية `paper` بزاوية 18.
struct SuraSectionView: View {
    let track: Track
    let section: SuraSection
    let bookmark: Int?
    var menu: HizbMenu?
    var shading: ShadingState?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: section.title)
                    .font(Theme.font(.semiBold, size: 17, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: section.hizbRange)
                    .font(Theme.font(.regular, size: 12.5, relativeTo: .caption))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.bottom, 7)
            .overlay(alignment: .bottom) { GiltRules() }
            .padding(.top, 2)
            .padding(.bottom, 6)

            ForEach(section.rows) { row in
                rowView(row)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 6)
        .padding(.bottom, 10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sura, style: .continuous).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sura, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("section.\(track.rawValue).\(section.suras[0])")
    }

    @ViewBuilder
    private func rowView(_ row: SectionRow) -> some View {
        if let juz = row.juzTag {
            // إن لم يتّسع الصفّ لوسم الجزء نزل الوسم إلى سطر رفيع فوقه، ولا تتحرّك الخانات (ت7).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    tiles(row)
                    Spacer(minLength: 8)
                    JuzTag(juz: juz)
                }
                .frame(height: Theme.Size.rowHeight)
                VStack(alignment: .trailing, spacing: 0) {
                    JuzTag(juz: juz).padding(.top, 4)
                    HStack(spacing: 8) {
                        tiles(row)
                        Spacer(minLength: 0)
                    }
                    .frame(height: Theme.Size.rowHeight)
                }
            }
            .id("row.\(track.rawValue).\(section.suras[0]).\(row.hizb)")
        } else {
            HStack(spacing: 8) {
                tiles(row)
                Spacer(minLength: 0)
            }
            .frame(height: Theme.Size.rowHeight)
            .id("row.\(track.rawValue).\(section.suras[0]).\(row.hizb)")
        }
    }

    @ViewBuilder
    private func tiles(_ row: SectionRow) -> some View {
        HizbLabel(hizb: row.hizb, isBookmark: row.hasBookmark, menu: menu)
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                if let q = row.slots[i] {
                    QuarterTile(track: track, quarter: q, isBookmark: q == bookmark,
                                isShared: section.shared.contains(q), under: Theme.paper, shading: shading)
                } else {
                    QuarterGap()
                }
            }
        }
    }
}

/// مسطرتان ذهبيتان تحت اسم السورة: 2 ثم 1 بينهما 2، بشفافية 75% (الزخرفة م-أ، §10). زينة بلا معنى.
struct GiltRules: View {
    var body: some View {
        VStack(spacing: 2) {
            Rectangle().frame(height: 2)
            Rectangle().frame(height: 1)
        }
        .foregroundStyle(Theme.gilt)
        .opacity(0.75)
        .frame(height: 5, alignment: .top)
        .accessibilityHidden(true)
    }
}

/// موضع شريط «طيّ» الذي في أسفل البطاقة المفتوحة، في إحداثيات الشاشة المرئية.
struct FoldBarPosition: Equatable, Sendable {
    static let space = "home.scroll"
    var barMaxY: CGFloat?

    /// الشريط تحت أسفل الشاشة، والبطاقة بادئة فيها: فيُلصق بالأسفل.
    func isBelow(viewportHeight: CGFloat) -> Bool {
        guard let barMaxY else { return false }
        return barMaxY > viewportHeight + 1
    }
}

/// شريط «طيّ» ملتصق بأسفل الشاشة حين يكون شريط البطاقة تحتها (7.1، م23): خلفية `card` وزاويتا 22 أسفل.
struct StickyFoldBar: View {
    let track: Track
    let action: () -> Void

    var body: some View {
        PullBar(track: track, isOpen: true, identifier: "track.\(track.rawValue).pull.sticky", action: action)
            .background(
                UnevenRoundedRectangle(bottomLeadingRadius: Theme.Radius.card, bottomTrailingRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.card)
            )
    }
}

/// سطر «آخر إدخال» فوق بطاقة المسار، خارجها (7.1، §13.4): ساعة 13، ثم المدّة 12.5/600 `ink`،
/// ثم «·» واليوم والتاريخ والوقت 12.5 `muted`. والمدّة لا تُختصر، والتاريخ وحده يُختصر بنقاط إن ضاق،
/// ومع خطّ كبير يلتفّ التاريخ إلى سطر ثانٍ تحت المدّة.
/// وقبل أول إدخال لا يُكتب (ذ12)، ومكانه محجوز بارتفاعه فلا تنزل البطاقة تحت الإصبع (ذ17).
struct LastEntryLine: View {
    let track: Track
    /// أحدث تظليل في المسار، أو `nil` قبل أول إدخال.
    let date: Date?
    let now: Date

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let title = date.map { LastEntry.title($0, now: now) } ?? "آخر إدخال"
        let stamp = date.map { LastEntry.stamp($0, now: now) } ?? " "
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    heading(title)
                    Text(verbatim: stamp)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                HStack(spacing: 5) {
                    heading(title)
                    Text(verbatim: "· \(stamp)")
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .font(Theme.font(.regular, size: 12.5, relativeTo: .caption))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        // ذ17: السطر نفسه مخفيّ بارتفاعه، لا محذوف.
        .hiddenIf(date == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: date == nil ? "" : "\(title)، \(stamp)"))
        .accessibilityHidden(date == nil)
        .accessibilityIdentifier("track.\(track.rawValue).lastEntry")
    }

    private func heading(_ title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
            Text(verbatim: title)
                .font(Theme.font(.semiBold, size: 12.5, relativeTo: .caption))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

private extension View {
    /// `.hidden()` بشرط: يبقى مكان العنصر محجوزاً ولا يُرى.
    @ViewBuilder func hiddenIf(_ hidden: Bool) -> some View {
        if hidden { self.hidden() } else { self }
    }
}
