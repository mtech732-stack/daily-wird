import SwiftData
import SwiftUI

extension Track: Identifiable {
    var id: String { rawValue }
}

/// ورقة الإضافة (7.2، §12.2): المسار، ثم صفّ لكل جزء من 30 بدائرته وخانتي حزبيه.
/// وعلى المحفوظ الجديد هي ورقة «الحزب الذي تحفظه» (§15.1، ذ27): بلا اختيار مسار، والجزء نصّ بلا دائرة.
struct AddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: AddSelection
    /// عدد الضغطات التي وصلت إلى دوائر الأجزاء وخانات الأحزاب. لا يُعرض إلا في اختبارات الواجهة،
    /// ومعه الأحزاب المختارة («2|1,2»)، ليفرّق الاختبار بين ضغطة لم تصل إلى التطبيق،
    /// وضغطة وصلت ولم يتغيّر بها الاختيار، واختيار تغيّر ولم تظهر سمته بعد.
    @State private var receivedTaps = 0
    /// ضغطات «أضف» التي وصلت، لاختبارات الواجهة: تفرّق بين ضغطة لم تصل وسؤال لم يظهر.
    @State private var goTaps = 0
    private static let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
    /// سؤال النقل ظاهر فوق الورقة (§12.3).
    @State private var asking = false
    let onAdd: (_ hizbs: [Int], _ track: Track, _ moving: Bool) -> Void

    init(track: Track, trackOf: [Int: Track], onAdd: @escaping (_ hizbs: [Int], _ track: Track, _ moving: Bool) -> Void) {
        _selection = State(initialValue: AddSelection(track: track, trackOf: trackOf))
        self.onAdd = onAdd
    }

    /// ورقة اختيار الحزب الذي يُحفظ في المحفوظ الجديد (5.6).
    private var picking: Bool { !selection.track.isReview }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(1...Quran.juzCount, id: \.self) { juz in
                        JuzRow(juz: juz, selection: $selection) { receivedTaps += 1 }
                        Rectangle().fill(Theme.line).frame(height: 1)
                    }
                }
                .padding(.horizontal, 22)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("add.list")
            bottomBar
        }
        .overlay(alignment: .topLeading) {
            if Self.isUITesting {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("add.taps")
                    .accessibilityValue(Text(verbatim: "\(receivedTaps)|\(selection.sortedSelection.map(String.init).joined(separator: ","))|\(goTaps)"))
                    .allowsHitTesting(false)
            }
        }
        .background(Theme.paper)
        .overlay {
            if asking, let from = selection.conflictTrack {
                ConflictDialog(conflicts: selection.conflicts, from: from, to: selection.track,
                               hasOthers: selection.sortedSelection.count > selection.conflicts.count) { moving in
                    onAdd(selection.sortedSelection, selection.track, moving)
                    asking = false
                    dismiss()
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.Radius.sheet)
        .presentationBackground(Theme.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verbatim: picking ? "الحزب الذي تحفظه" : "إضافة محفوظ")
                    .font(Theme.font(.semiBold, size: 21, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { dismiss() } label: {
                    Text(verbatim: "إلغاء")
                        .font(Theme.font(.regular, size: 16, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                        .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("add.cancel")
            }
            if picking {
                // سطر الوجهة: شريط الجديد 4×18 واسمه 15/600 (§15.1).
                HStack(spacing: 8) {
                    TrackMark(track: selection.track, width: 4, height: 18)
                    Text(verbatim: selection.track.title)
                        .font(Theme.font(.semiBold, size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("add.target")
            } else {
                TrackSegments(selection: $selection)
            }
            Text(verbatim: picking ? "اختر الحزب الذي تحفظ فيه الآن، فتظهر أوجهه في البطاقة." : "اختر الجزء كلّه بدائرته، أو حزباً منه.")
                .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }

    private var bottomBar: some View {
        let list = selection.sortedSelection
        return VStack(spacing: 0) {
            Rectangle().fill(Theme.line).frame(height: 1)
            Button {
                goTaps += 1
                // الحزب الذي في مسار آخر يُسأل عنه عند «أضف» لا عند اختياره (ذ5).
                if selection.conflicts.isEmpty {
                    onAdd(list, selection.track, false)
                    dismiss()
                } else {
                    asking = true
                }
            } label: {
                Text(verbatim: Phrase.addButton(list, to: selection.track))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(list.isEmpty)
            .opacity(list.isEmpty ? 0.38 : 1)
            .padding(.top, 10)
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
            .accessibilityIdentifier("add.go")
        }
        .background(Theme.paper)
    }
}

/// اختيار المسار: مقطعان، والمختار مرفوع بخلفية البطاقة وإطار (§12.2).
private struct TrackSegments: View {
    @Binding var selection: AddSelection

    var body: some View {
        HStack(spacing: 4) {
            ForEach([Track.farReview, .nearReview]) { track in
                let on = selection.track == track
                Button { selection.setTrack(track) } label: {
                    HStack(spacing: 8) {
                        TrackMark(track: track, width: 4, height: 18)
                        Text(verbatim: track.title)
                            .font(Theme.font(on ? .semiBold : .regular, size: 15, relativeTo: .subheadline))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                            .fill(on ? Theme.card : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                            .strokeBorder(on ? Theme.ink : Color.clear, lineWidth: 1.5)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("add.track.\(track.rawValue)")
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous).fill(Theme.ghost))
    }
}

/// صفّ الجزء: دائرته (تختار حزبيه)، ثم خانتا الحزبين في مكانيهما الثابتين (ذ2).
private struct JuzRow: View {
    let juz: Int
    @Binding var selection: AddSelection
    var noteTap: () -> Void = {}

    var body: some View {
        let hizbs = Quran.hizbs(ofJuz: juz)
        let can = !selection.pickable(inJuz: juz).isEmpty
        let full = selection.isJuzSelected(juz)
        HStack(spacing: 8) {
            if !selection.track.isReview {
                // في اختيار الحزب الذي يُحفظ لا دائرة للجزء: حزب واحد في وقت واحد (القرار 5، ذ27).
                Text(verbatim: "الجزء \(Digits.en(juz))")
                    .font(Theme.font(.medium, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: 72, height: 52, alignment: .leading)
                    .accessibilityIdentifier("add.juz.\(juz)")
            } else {
                Button { noteTap(); selection.toggleJuz(juz) } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(full ? Theme.ink : Color.clear)
                            Circle()
                                .strokeBorder(full ? Theme.ink : Theme.ink.opacity(0.6), lineWidth: 1.5)
                            if full {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.paper)
                            }
                        }
                        .frame(width: 22, height: 22)
                        // م27: في الجزء الذي لم يبقَ فيه ما يُختار تختفي الدائرة وحدها، ويبقى اسمه هادئاً.
                        .opacity(can ? 1 : 0)
                        Text(verbatim: "الجزء \(Digits.en(juz))")
                            .font(Theme.font(.semiBold, size: 14, relativeTo: .subheadline))
                            .foregroundStyle(can ? Theme.ink : Theme.muted)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .frame(width: 92, height: 52, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // لا `.disabled`: يخفّت النصّ دون التباين المطلوب (م25). والضغط لا يفعل شيئاً حين لا يُختار.
                .allowsHitTesting(can)
                .accessibilityRemoveTraits(can ? [] : .isButton)
                .accessibilityLabel(Text(verbatim: can ? "الجزء \(Digits.en(juz)) كاملاً" : "الجزء \(Digits.en(juz))"))
                .accessibilityAddTraits(full ? .isSelected : [])
                .accessibilityIdentifier("add.juz.\(juz)")
            }

            ForEach(hizbs, id: \.self) { hizb in
                HizbChip(hizb: hizb, state: selection.state(of: hizb), pickable: selection.isPickable(hizb),
                         hereText: Phrase.inThisTrack(selection.track)) {
                    noteTap()
                    selection.toggle(hizb)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

/// خانة الحزب: «ح [رقم]» وتحته السورة التي يبدأ بها (ذ3)، وحالاتها الأربع بالشكل (ذ4).
/// تُستعمل في ورقة الإضافة وورقة الإدارة (§12.5)، وتختلف بادئة معرّفها.
struct HizbChip: View {
    let hizb: Int
    let state: HizbChipState
    let pickable: Bool
    var idPrefix = "add"
    /// «في هذا المسار»، وفي المحفوظ الجديد «تحفظه الآن» (§15.1).
    var hereText = "في هذا المسار"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(verbatim: Digits.hizbLabel(hizb))
                        .font(Theme.font(.semiBold, size: 15, relativeTo: .subheadline))
                    Spacer(minLength: 0)
                    if state == .selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                subtitle
                    .font(Theme.font(.regular, size: 11.5, relativeTo: .caption2))
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(background)
            .overlay(border)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        // م25: لا `.disabled`، فهو يخفّت النصّ إلى 2.7:1. ما لا يُختار لا يستجيب للمس، ويبقى نصّه بألوان التصميم.
        .allowsHitTesting(pickable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(state == .selected ? .isSelected : [])
        .accessibilityIdentifier("\(idPrefix).hizb.\(hizb)")
    }

    @ViewBuilder private var subtitle: some View {
        switch state {
        case .here:
            Text(verbatim: hereText)
        case .other(let track):
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Theme.trackColor(track))
                    .frame(width: 3, height: 11)
                Text(verbatim: Phrase.inTrackShort(track))
            }
        default:
            Text(verbatim: Quran.suraName(Quran.firstSura(ofHizb: hizb)))
                .foregroundStyle(state == .selected ? Theme.paper.opacity(0.85) : Theme.muted)
        }
    }

    private var foreground: Color {
        switch state {
        case .selected: Theme.paper
        case .here: Theme.muted
        default: Theme.ink
        }
    }

    @ViewBuilder private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        switch state {
        case .selected: shape.fill(Theme.ink)
        case .here: shape.fill(Theme.ghost)
        default: shape.fill(Color.clear)
        }
    }

    @ViewBuilder private var border: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        switch state {
        case .available: shape.strokeBorder(Theme.ink.opacity(0.55), lineWidth: 1.5)
        case .other: shape.strokeBorder(Theme.ink.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        default: EmptyView()
        }
    }
}

/// سؤال النقل (5.1، §12.3): حوار فوق الورقة بتعتيم ثانٍ، بنصّ الوثيقة، وخياران بالحجم نفسه (ذ5).
/// فلا يصل التطبيق أبداً إلى حزب في مسارين، ولا ينقل شيئاً دون سؤال.
private struct ConflictDialog: View {
    let conflicts: [Int]
    let from: Track
    let to: Track
    let hasOthers: Bool
    let answer: (_ moving: Bool) -> Void

    var body: some View {
        ZStack {
            Theme.scrim.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: Phrase.conflictQuestion(conflicts, in: from))
                    .font(Theme.font(.semiBold, size: 19, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("conflict.question")
                Text(verbatim: Phrase.conflictNote(conflicts.count, hasOthers: hasOthers, from: from))
                    .font(Theme.font(.regular, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    Button { answer(true) } label: { Text(verbatim: Phrase.moveAnswer(conflicts.count, to: to)) }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("conflict.move")
                    Button { answer(false) } label: { Text(verbatim: Phrase.keepAnswer(conflicts.count, in: from)) }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityIdentifier("conflict.keep")
                }
                .padding(.top, 8)
            }
            .padding(.top, 26)
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.dialog, style: .continuous).fill(Theme.dialog))
            .padding(.horizontal, 28)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }
}

/// زرّ أساسي (§6): ارتفاع 50، زاوية 14، ممتلئ بلون النصّ، ونصّه بلون الأرضية.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.medium, size: 16, relativeTo: .body))
            .foregroundStyle(Theme.paper)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous).fill(Theme.ink))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// زرّ هادئ (§6): بلا حدّ.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.medium, size: 16, relativeTo: .body))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// الإشعار العابر (§12.6): كبسولة بلون النصّ، يبقى 2.5 ث ثم يتلاشى، ويُعلَن لـ VoiceOver.
struct ToastView: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(Theme.font(.regular, size: 14, relativeTo: .subheadline))
            .foregroundStyle(Theme.paper)
            .multilineTextAlignment(.center)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(Capsule().fill(Theme.ink))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .padding(.horizontal, 24)
            .allowsHitTesting(false)
            .accessibilityIdentifier("toast")
    }
}
