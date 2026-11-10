import SwiftData
import Combine
import SwiftUI
import UIKit

/// الشاشة الرئيسية «الورد اليومي» (7.1) كما تُبنى في ش1: المسارات الثلاثة بترتيب المالك،
/// كل بطاقة مطويّة على موضع توقّفها، والأرشيف يُفتح من شريط الإسدال.
/// وفي ش2: الضغطة على الربع تظلّله بتاريخه ووقته وعليه علامة «اليوم» (5.3، §13.1).
/// ولا يظهر بعدُ: سطر «آخر إدخال» ومفاتيح الرموز (مراحلهما في ش2)، والعدّاد (ش5).
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var placements: [HizbPlacement]
    @Query private var readings: [QuarterReading]
    @Environment(\.scenePhase) private var scenePhase

    /// «الآن» الذي تُرسم به الشاشة. يتحدّث عند منتصف الليل والتطبيق مفتوح، ومع العودة من الخلفية،
    /// ومع تغيّر الوقت في الجهاز، فتختفي علامات «اليوم» دون فتح جديد (القرار 2، §13.2).
    @State private var now = WirdClock.now()

    /// المسار الذي فُتحت عليه ورقة الإضافة (7.2).
    @State private var addTrack: Track?
    /// الإشعار العابر (§12.6).
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    /// ورقة الإدارة: نقل أو إزالة من مسار (§12.5).
    @State private var manage: ManageRequest?
    /// تأكيد إزالة حزب من قائمته (5.1: بتأكيد صريح).
    @State private var removal: Removal?
    /// قائمة الحزب المفتوحة بالضغط المطوّل (§12.5).
    @State private var hizbMenu: HizbMenuRequest?

    /// المسار المفتوح أرشيفه. لا يُحفظ، فيفتح التطبيق دائماً مطويّاً (7.1).
    @State private var openTrack: Track?
    /// موضع شريط «طيّ» في أسفل البطاقة المفتوحة، لإلصاقه بأسفل الشاشة إن نزل تحتها (م23).
    @State private var foldBar = FoldBarPosition()

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = geo.size.width < 390 ? 16 : 20
            // عرض الصفّ داخل البطاقة المطويّة: الشاشة ناقص الهامشين وحشو البطاقة وحدّها.
            let narrow = geo.size.width - margin * 2 - 34 < 330
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        HomeHeader(now: now)
                            .padding(.bottom, 6)
                        ForEach(Track.allCases, id: \.self) { track in
                            card(for: track, narrow: narrow, proxy: proxy)
                                .id("card.\(track.rawValue)")
                        }
                    }
                    .padding(.horizontal, margin)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                // لا يمرّ المحتوى تحت شريط الحالة عند التمرير.
                .clipped()
                .coordinateSpace(.named(FoldBarPosition.space))
                .overlay(alignment: .bottom) {
                    // الشريط في أسفل البطاقة، ولا يلتصق بأسفل الشاشة إلا حين يكون تحتها
                    // والبطاقة ظاهرة، كالتصاق CSS sticky في التصميم (7.1، م23).
                    if let open = openTrack, foldBar.isBelow(viewportHeight: geo.size.height) {
                        StickyFoldBar(track: open) { toggle(open, proxy: proxy) }
                            .padding(.horizontal, margin)
                    }
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        // م18: ما جاءت به المزامنة من صفّين مفتوحين للحزب يُسوّى بإغلاق الأقدم، ولا يُحذف شيء.
        .task { try? Library.reconcile(in: context) }
        // منتصف الليل والتطبيق مفتوح: يُعاد الرسم بيوم جديد (§13.2).
        .task(id: Shading.nextMidnight(after: now)) {
            let wait = Shading.nextMidnight(after: now).timeIntervalSince(WirdClock.now())
            try? await Task.sleep(for: .seconds(max(wait, 0) + 0.5))
            guard !Task.isCancelled else { return }
            now = WirdClock.now()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = WirdClock.now() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            now = WirdClock.now()
        }
        .overlay(alignment: .bottom) {
            // اختبار منتصف الليل وحده (`-test-clock`): زرّ لا يُرى يقفز بالساعة بعد منتصف الليل،
            // ثم يُرسل ما يرسله الجهاز عند تغيّر اليوم، فلا ينتظر الاختبار وقتاً حقيقياً.
            if Self.hasTestClock {
                Color.clear
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        WirdClock.jumpPastMidnight()
                        NotificationCenter.default.post(name: UIApplication.significantTimeChangeNotification, object: nil)
                    }
                    .accessibilityElement()
                    .accessibilityLabel(Text(verbatim: "test clock"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("test.midnight")
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                ToastView(text: toast)
                    .padding(.bottom, 42)
                    .transition(.opacity)
            }
        }
        .overlay {
            // قائمة الحزب بالضغط المطوّل (§12.5).
            if let request = hizbMenu {
                HizbMenuOverlay(request: request) { action in
                    hizbMenu = nil
                    switch action {
                    case .move: move([request.hizb], from: request.track)
                    case .remove: removal = Removal(track: request.track, hizbs: [request.hizb])
                    case nil: break
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: hizbMenu)
        .animation(.easeOut(duration: 0.2), value: toast)
        .sheet(item: $addTrack) { track in
            AddSheet(track: track, trackOf: Library.trackOfHizb(from: placements)) { hizbs, target, moving in
                add(hizbs, to: target, moving: moving)
            }
        }
        .sheet(item: $manage) { request in
            ManageSheet(request: request, hizbs: Library.activeHizbs(in: request.track, from: placements)) { hizbs in
                if request.mode == .remove {
                    remove(hizbs, from: request.track)
                } else {
                    move(hizbs, from: request.track)
                }
            }
        }
        .overlay {
            // تأكيد الإزالة من قائمة الحزب (§12.5).
            if let removal {
                ChoiceDialog(
                    title: Phrase.removeQuestion(removal.hizbs, from: removal.track),
                    note: Phrase.removeNote(removal.hizbs.count),
                    primary: Phrase.removeAnswer(removal.hizbs.count), primaryID: "remove.confirm",
                    quiet: "إلغاء", quietID: "remove.cancel",
                    titleID: "remove.question"
                ) { confirmed in
                    self.removal = nil
                    if confirmed { remove(removal.hizbs, from: removal.track) }
                }
            }
        }
    }

    /// ينقل إلى المسار الآخر فوراً بلا سؤال، لأن النقل لا يمحو شيئاً (ذ6)، ثم يؤكّده بإشعار.
    private func move(_ hizbs: [Int], from track: Track) {
        let target = Library.otherReviewTrack(track)
        do {
            let moved = try Library.move(hizbs, from: track, to: target, in: context)
            foldIfEmptied(track, removing: moved)
            if !moved.isEmpty { show(Phrase.movedToast(moved, to: target)) }
        } catch {
            show("تعذّر النقل")
        }
    }

    /// يزيل بعد التأكيد، ويبقى سجلّ التلاوة محفوظاً (5.1)، ثم يؤكّده بإشعار.
    private func remove(_ hizbs: [Int], from track: Track) {
        do {
            let removed = try Library.remove(hizbs, from: track, in: context)
            foldIfEmptied(track, removing: removed)
            if !removed.isEmpty { show(Phrase.removedToast(removed)) }
        } catch {
            show("تعذّرت الإزالة")
        }
    }

    /// إن فرغ المسار عادت بطاقته فارغة، وطُوي أرشيفه إن كان مفتوحاً (§12.5).
    private func foldIfEmptied(_ track: Track, removing list: [Int]) {
        guard openTrack == track else { return }
        let left = Set(Library.activeHizbs(in: track, from: placements)).subtracting(list)
        if left.isEmpty {
            openTrack = nil
            foldBar = FoldBarPosition()
        }
    }

    /// يضيف المختار إلى المسار (وينقل ما في مسار آخر إن أجاب المالك بالنقل)،
    /// ثم يؤكّد ما جرى بإشعار عابر (5.1، ذ8).
    private func add(_ hizbs: [Int], to track: Track, moving: Bool) {
        do {
            let before = Library.trackOfHizb(from: placements)
            let changed = try Library.add(hizbs, to: track, in: context, moving: moving)
            // ما كان في مسار آخر قد نُقل، وما سواه أُضيف جديداً.
            let moved = changed.filter { before[$0] != nil && before[$0] != track }
            let added = changed.filter { !moved.contains($0) }
            show(changed.isEmpty ? "لم يُضف شيء" : Phrase.addedToast(added: added, moved: moved, to: track))
        } catch {
            show("تعذّرت الإضافة")
        }
    }

    /// مدّة الإشعار 2.5 ث (§12.6). وفي اختبارات الواجهة يبقى حتى يُقرأ ويُصوَّر، فالمحاكي البطيء
    /// قد يتجاوز 2.5 ث بين ظهوره وقراءته، فيفشل الاختبار دون خطأ في التطبيق.
    static let hasTestClock = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        && ProcessInfo.processInfo.arguments.contains("-test-clock")

    static let toastSeconds: Double = ProcessInfo.processInfo.arguments.contains("-ui-testing") ? 30 : 2.5

    private func show(_ text: String) {
        toast = text
        AccessibilityNotification.Announcement(text).post()
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.toastSeconds))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }

    @ViewBuilder
    private func card(for track: Track, narrow: Bool, proxy: ScrollViewProxy) -> some View {
        if track.isReview {
            let layout = ReviewTrackLayout(track: track, hizbs: Library.activeHizbs(in: track, from: placements))
            if layout.isEmpty {
                EmptyTrackCard(track: track) { addTrack = track }
            } else {
                let menu = HizbMenu(track: track) { hizb, frame in
                    hizbMenu = HizbMenuRequest(track: track, hizb: hizb, labelFrame: frame)
                }
                ReviewTrackCard(layout: layout, isOpen: openTrack == track, narrow: narrow, hizbMenu: menu,
                                shading: shading) {
                    toggle(track, proxy: proxy)
                } onAdd: {
                    addTrack = track
                } onManage: { mode in
                    manage = ManageRequest(track: track, mode: mode)
                } onFoldBarMove: { maxY in
                    foldBar.barMaxY = maxY
                }
            }
        } else {
            // اختيار الحزب الذي يُحفظ في المحفوظ الجديد في ش4.
            EmptyTrackCard(track: track)
        }
    }

    /// حالة التظليل في الشاشة كلها: الربع واحد في السجلّ، فيظهر مظلّلاً حيث ظهر (7.1.1).
    private var shading: ShadingState {
        ShadingState(today: Shading.readToday(readings, now: now)) { quarter, track in
            shade(quarter, in: track)
        }
    }

    /// ضغطة على الربع = تلوته اليوم، وعلى ربع ظُلّل اليوم = تراجع (5.3، §13.2).
    /// ولا اهتزاز ولا إشعار عابر (ذ11): التغيّر يُرى في المربّع، ويُعلَن لقارئ الشاشة (§13.7).
    private func shade(_ quarter: Int, in track: Track) {
        let at = WirdClock.now()
        now = at
        do {
            let result = try Shading.tap(quarter: quarter, track: track, in: context, now: at)
            AccessibilityNotification.Announcement(result == .shaded ? "تلوته اليوم" : "تراجعت").post()
        } catch {
            show("تعذّر التسجيل")
        }
    }

    /// لا يُفتح إلا مسار واحد في وقت واحد؛ فتح مسار يطوي غيره (7.1).
    private func toggle(_ track: Track, proxy: ScrollViewProxy) {
        foldBar = FoldBarPosition()
        if openTrack == track {
            openTrack = nil
            proxy.scrollTo("card.\(track.rawValue)", anchor: .top)
        } else {
            openTrack = track
            // ينزل إلى موضع التوقّف عند الفتح (7.1). في ش1 هو أول المسار، فيُعرض من أعلى البطاقة.
            proxy.scrollTo("card.\(track.rawValue)", anchor: .top)
        }
    }
}

/// حزب أو أكثر ينتظر تأكيد إزالته من مساره.
struct Removal: Equatable {
    let track: Track
    let hizbs: [Int]
}

/// رأس هادئ (7.1، §6): اسم التطبيق وتاريخ اليوم على سطر واحد، وزرّ الإعدادات.
struct HomeHeader: View {
    /// «الآن» من الشاشة، فيتحدّث التاريخ مع منتصف الليل كما تتحدّث الأرباع.
    var now: Date = WirdClock.now()

    var body: some View {
        HStack(alignment: .center) {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: AppInfo.name)
                        .font(Theme.font(.semiBold, size: 22, relativeTo: .title2))
                        .foregroundStyle(Theme.text)
                        .accessibilityIdentifier("home.title")
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: WirdDate.header(WirdClock.now()))
                        .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
                        .foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("home.date")
                }
            }
            Spacer(minLength: 8)
            // زرّ الإعدادات (§6). شاشة الإعدادات نفسها في ش6 (7.4).
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.iconButton, style: .continuous)
                        .strokeBorder(Theme.line, lineWidth: 1)
                )
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .accessibilityLabel(Text(verbatim: "الإعدادات"))
                .accessibilityIdentifier("home.settings")
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
        .environment(\.layoutDirection, .rightToLeft)
}
