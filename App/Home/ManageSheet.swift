import SwiftUI

/// ما تفعله ورقة الإدارة: نقل من المسار إلى الآخر، أو إزالة منه (§12.5).
enum ManageMode: String, Identifiable {
    case move, remove
    var id: String { rawValue }
}

/// ما تُفتح عليه ورقة الإدارة: مسار ومعه النقل أو الإزالة.
struct ManageRequest: Identifiable, Equatable {
    let track: Track
    let mode: ManageMode
    var id: String { "\(track.rawValue).\(mode.rawValue)" }
}

/// ورقة الإدارة من «⋯» (§12.5): ورقة الإضافة نفسها بلا اختيار مسار. لا تظهر فيها إلا أجزاء
/// هذا المسار، وفيها أحزابه وحدها في أماكنها الثابتة، وما ليس فيه فراغ في مكانه.
/// النقل ينفذ فوراً (النقل لا يمحو شيئاً، ذ6)، والإزالة بتأكيد صريح (5.1).
struct ManageSheet: View {
    @Environment(\.dismiss) private var dismiss
    let request: ManageRequest
    /// أحزاب هذا المسار الآن.
    let hizbs: [Int]
    let onDone: (_ hizbs: [Int]) -> Void

    @State private var selected: Set<Int> = []
    @State private var confirming = false

    private var removing: Bool { request.mode == .remove }
    private var target: Track { Library.otherReviewTrack(request.track) }
    private var list: [Int] { selected.sorted() }
    private var juzs: [Int] { Array(Set(hizbs.map(Quran.juz(ofHizb:)))).sorted() }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(juzs, id: \.self) { juz in
                        ManageJuzRow(juz: juz, inTrack: Set(hizbs), selected: $selected)
                        Rectangle().fill(Theme.line).frame(height: 1)
                    }
                }
                .padding(.horizontal, 22)
            }
            .scrollIndicators(.hidden)
            bottomBar
        }
        .background(Theme.paper)
        .overlay {
            if confirming {
                ChoiceDialog(
                    title: Phrase.removeQuestion(list, from: request.track),
                    note: Phrase.removeNote(list.count, from: request.track),
                    primary: Phrase.removeAnswer(list.count), primaryID: "remove.confirm",
                    quiet: "إلغاء", quietID: "remove.cancel",
                    titleID: "remove.question"
                ) { confirmed in
                    confirming = false
                    if confirmed {
                        onDone(list)
                        dismiss()
                    }
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
                Text(verbatim: Phrase.manageTitle(removing: removing, from: request.track))
                    .font(Theme.font(.semiBold, size: 21, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("manage.title")
                Spacer()
                Button { dismiss() } label: {
                    Text(verbatim: "إلغاء")
                        .font(Theme.font(.regular, size: 16, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                        .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("manage.cancel")
            }
            if removing {
                Text(verbatim: Phrase.removeSheetNote(request.track))
                    .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.muted)
            } else {
                // سطر الوجهة: «إلى» ثم شريط لونها واسمها.
                HStack(spacing: 8) {
                    Text(verbatim: "إلى")
                        .font(Theme.font(.regular, size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.muted)
                    TrackMark(track: target, width: 4, height: 18)
                    Text(verbatim: target.title)
                        .font(Theme.font(.semiBold, size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.ink)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("manage.target")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.line).frame(height: 1)
            Button {
                if removing {
                    confirming = true
                } else {
                    onDone(list)
                    dismiss()
                }
            } label: {
                Text(verbatim: Phrase.manageButton(list, removing: removing, to: target))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(list.isEmpty)
            .opacity(list.isEmpty ? 0.38 : 1)
            .padding(.top, 10)
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
            .accessibilityIdentifier("manage.go")
        }
        .background(Theme.paper)
    }
}

/// صفّ جزء في ورقة الإدارة: دائرته تختار ما فيه من أحزاب هذا المسار، ثم خانتا الحزبين
/// في مكانيهما، وما ليس في المسار فراغ في مكانه (§12.5).
private struct ManageJuzRow: View {
    let juz: Int
    let inTrack: Set<Int>
    @Binding var selected: Set<Int>

    var body: some View {
        let hizbs = Quran.hizbs(ofJuz: juz)
        let mine = hizbs.filter(inTrack.contains)
        let full = !mine.isEmpty && mine.allSatisfy(selected.contains)
        HStack(spacing: 8) {
            Button {
                if full { mine.forEach { selected.remove($0) } } else { mine.forEach { selected.insert($0) } }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(full ? Theme.ink : Color.clear)
                        Circle().strokeBorder(full ? Theme.ink : Theme.ink.opacity(0.6), lineWidth: 1.5)
                        if full {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.paper)
                        }
                    }
                    .frame(width: 22, height: 22)
                    Text(verbatim: "الجزء \(Digits.en(juz))")
                        .font(Theme.font(.semiBold, size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(width: 92, height: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: "الجزء \(Digits.en(juz)) كاملاً"))
            .accessibilityAddTraits(full ? .isSelected : [])
            .accessibilityIdentifier("manage.juz.\(juz)")

            ForEach(hizbs, id: \.self) { hizb in
                if inTrack.contains(hizb) {
                    HizbChip(hizb: hizb, state: selected.contains(hizb) ? .selected : .available,
                             pickable: true, idPrefix: "manage") {
                        if selected.contains(hizb) { selected.remove(hizb) } else { selected.insert(hizb) }
                    }
                } else {
                    // فراغ في مكانه، فلا تتحرّك الخانات.
                    Color.clear.frame(maxWidth: .infinity, minHeight: 52).accessibilityHidden(true)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

/// حوار بسؤال وسطر هادئ وزرّين: أساسي وهادئ (§6). يُستعمل لتأكيد الإزالة (5.1).
struct ChoiceDialog: View {
    let title: String
    let note: String
    let primary: String
    let primaryID: String
    let quiet: String
    let quietID: String
    var titleID = "dialog.title"
    let answer: (_ primary: Bool) -> Void

    var body: some View {
        ZStack {
            Theme.scrim.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: title)
                    .font(Theme.font(.semiBold, size: 19, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(titleID)
                Text(verbatim: note)
                    .font(Theme.font(.regular, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    Button { answer(true) } label: { Text(verbatim: primary) }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier(primaryID)
                    Button { answer(false) } label: { Text(verbatim: quiet) }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityIdentifier(quietID)
                }
                .padding(.top, 8)
            }
            .padding(.top, 26)
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.dialog, style: .continuous).fill(Theme.paper))
            .padding(.horizontal, 28)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }
}
