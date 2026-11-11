import SwiftData
import Combine
import SwiftUI
import UIKit

/// الشاشة الرئيسية «الورد اليومي» (7.1) كما تُبنى في ش1: المسارات الثلاثة بترتيب المالك،
/// كل بطاقة مطويّة على موضع توقّفها، والأرشيف يُفتح من شريط الإسدال.
/// وفي ش2: الضغطة على الربع تظلّله بتاريخه ووقته وعليه علامة «اليوم» (5.3، §13.1).
/// ولا يظهر بعدُ: العدّاد (ش5).
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var placements: [HizbPlacement]
    @Query private var readings: [QuarterReading]
    /// دورات مسارَي المراجعة (5.5، §14.1).
    @Query private var cycles: [ReviewCycle]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    /// تفاصيل الربع المفتوحة بالضغط المطوّل (7.3).
    @State private var details: QuarterDetailsRequest?

    /// ارتفاع الرأس والبطاقات، لإظهار إشارة المفاتيح إن بقي لها مكان (§13.6).
    @State private var cardsHeight: CGFloat = 0
    private static let topPadding: CGFloat = 4
    /// المقبض 4 وفراغ 4 والنصّ نحو 18 وحشو 12 فوقه و12 تحته.
    private static let hintHeight: CGFloat = 50

    /// الصفّ المطويّ الباقي على حزبه بعد انتقال موضع التوقّف عنه، مدّة المهلة (§14.3، ذ20).
    @State private var pinned: [Track: Int] = [:]
    @State private var pinTasks: [Track: Task<Void, Never>] = [:]
    /// مهلة بقاء الصفّ 0.8 ث. وفي اختبارات الواجهة تطول بـ`-pin-seconds` ليُقرأ الصفّ فيها على محاكٍ بطيء.
    static let pinSeconds: Double = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-ui-testing"), let i = args.firstIndex(of: "-pin-seconds"), i + 1 < args.count,
           let value = Double(args[i + 1]) { return value }
        return 0.8
    }()

    /// المسار الذي فُتح أرشيفه للتوّ، وينتظر قياس صفّ موضع التوقّف لينزل إليه (ذ18).
    @State private var pendingBookmark: Track?

    /// موضع شريط «طيّ» في أسفل البطاقة المفتوحة، لإلصاقه بأسفل الشاشة إن نزل تحتها (م23).
    @State private var foldBar = FoldBarPosition()

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = geo.size.width < 390 ? 16 : 20
            // عرض الصفّ داخل البطاقة المطويّة: الشاشة ناقص الهامشين وحشو البطاقة وحدّها.
            let narrow = geo.size.width - margin * 2 - 34 < 330
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // الحالة المطويّة تملأ الشاشة، وفي أسفلها إشارة «اسحب للأعلى»، فلا تُرى المفاتيح
                        // إلا بالسحب (§13.6). ومكان العدّاد (ش5) فراغ بلون الأرضية.
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: 8) {
                                HomeHeader(now: now)
                                    .padding(.bottom, 6)
                                ForEach(Track.allCases, id: \.self) { track in
                                    card(for: track, narrow: narrow, proxy: proxy, viewport: geo.size.height)
                                        .id("card.\(track.rawValue)")
                                }
                            }
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardsHeight = $0 }
                            if openTrack == nil {
                                Spacer(minLength: 0)
                                // وإن لم يبقَ للإشارة مكان تحت البطاقات خفيت، والمفاتيح بالتمرير (§13.6).
                                if geo.size.height - Self.topPadding - 6 - cardsHeight >= Self.hintHeight {
                                    KeysHint()
                                }
                            }
                        }
                        .frame(minHeight: openTrack == nil ? geo.size.height - Self.topPadding - 6 : nil, alignment: .top)
                        SymbolKeys()
                            .padding(.top, openTrack == nil ? 6 : 14)
                            .padding(.bottom, 10)
                    }
                    .padding(.horizontal, margin)
                    .padding(.top, Self.topPadding)
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
        // وما سبق ش3 من أحزاب بلا دورة تبدأ دورته من أقدم إضافة (§14.1).
        .task {
            try? Library.reconcile(in: context)
            try? Cycles.ensure(in: context)
        }
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
        .sheet(item: $details) { request in
            let state = shading
            QuarterDetailsSheet(request: request,
                                history: QuarterDetails.history(request.quarter, readings: readings),
                                level: state.level(request.quarter), isToday: state.isToday(request.quarter),
                                now: now) {
                shade(request.quarter, in: request.track)
            }
        }
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
    private func card(for track: Track, narrow: Bool, proxy: ScrollViewProxy, viewport: CGFloat) -> some View {
        if track.isReview {
            let layout = reviewLayout(for: track)
            if layout.isEmpty {
                EmptyTrackCard(track: track) { addTrack = track }
            } else {
                let menu = HizbMenu(track: track) { hizb, frame in
                    hizbMenu = HizbMenuRequest(track: track, hizb: hizb, labelFrame: frame)
                }
                VStack(alignment: .leading, spacing: 4) {
                    LastEntryLine(track: track, date: LastEntry.latest(in: layout.quarters, readings: readings), now: now)
                    ReviewTrackCard(layout: layout, isOpen: openTrack == track, narrow: narrow, hizbMenu: menu,
                                    shading: shading, displayedHizb: pinned[track],
                                    onBookmarkRow: { offset in
                                        scrollToBookmark(track, rowOffset: offset, viewport: viewport, proxy: proxy)
                                    }) {
                        toggle(track, proxy: proxy)
                    } onAdd: {
                        addTrack = track
                    } onManage: { mode in
                        manage = ManageRequest(track: track, mode: mode)
                    } onFoldBarMove: { maxY in
                        foldBar.barMaxY = maxY
                    }
                }
            }
        } else {
            // اختيار الحزب الذي يُحفظ في المحفوظ الجديد في ش4.
            EmptyTrackCard(track: track)
        }
    }

    /// تخطيط مسار المراجعة بأرباعه المظلّلة في دورته الحالية (§14.1–14.2).
    private func reviewLayout(for track: Track, readings: [QuarterReading]? = nil) -> ReviewTrackLayout {
        let hizbs = Library.activeHizbs(in: track, from: placements)
        let quarters = hizbs.flatMap(Quran.quarters(ofHizb:))
        let start = Cycles.current(track, in: cycles)?.startedAt
        return ReviewTrackLayout(track: track, hizbs: hizbs,
                                 done: Cycles.done(quarters: quarters, readings: readings ?? self.readings, since: start))
    }

    /// حالة التظليل في الشاشة كلها: الربع واحد في السجلّ، فيظهر مظلّلاً حيث ظهر (7.1.1).
    private var shading: ShadingState {
        ShadingState(today: Shading.readToday(readings, now: now), levels: Age.levels(readings, now: now)) { quarter, track in
            shade(quarter, in: track)
        } details: { quarter, track, isShared in
            details = QuarterDetailsRequest(quarter: quarter, track: track, isShared: isShared)
        }
    }

    /// ضغطة على الربع = تلوته اليوم، وعلى ربع ظُلّل اليوم = تراجع (5.3، §13.2).
    /// ولا اهتزاز ولا إشعار عابر (ذ11): التغيّر يُرى في المربّع، ويُعلَن لقارئ الشاشة (§13.7).
    private func shade(_ quarter: Int, in track: Track) {
        let at = WirdClock.now()
        now = at
        let reviews = Track.allCases.filter(\.isReview)
        let before = Dictionary(uniqueKeysWithValues: reviews.map { ($0, reviewLayout(for: $0).bookmarkHizb) })
        do {
            let result = try Shading.tap(quarter: quarter, track: track, in: context, now: at)
            AccessibilityNotification.Announcement(result == .shaded ? "تلوته اليوم" : "تراجعت").post()
            let fresh = (try? context.fetch(FetchDescriptor<QuarterReading>())) ?? readings
            for review in reviews {
                follow(review, from: before[review] ?? nil, to: reviewLayout(for: review, readings: fresh).bookmarkHizb)
            }
        } catch {
            show("تعذّر التسجيل")
        }
    }

    /// انتقال موضع التوقّف إلى حزب آخر: يبقى الصفّ على حزبه 0.8 ث بلا إطار ولا علامة،
    /// ثم يتلاشى إلى الحزب الجديد في 0.25 ث، وفوراً مع «تقليل الحركة» (§14.3، ذ20).
    /// وكل ضغطة في المهلة تُعالَج كعادتها ثم يُعاد الحساب (م38): إن رجع الموضع إلى الحزب المعروض
    /// (كالتراجع) أُلغي الانتقال، وإلا بقيت المهلة، وعند انقضائها يُعرض حزب الموضع كما هو حينئذ.
    private func follow(_ track: Track, from old: Int?, to new: Int?) {
        let shown = pinned[track] ?? old
        if new == shown {
            pinTasks[track]?.cancel()
            pinTasks[track] = nil
            pinned[track] = nil
            return
        }
        guard let shown, new != nil, pinned[track] == nil else { return }
        pinned[track] = shown
        pinTasks[track] = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.pinSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                pinned[track] = nil
            }
            pinTasks[track] = nil
            let current = reviewLayout(for: track)
            if let q = current.bookmarkQuarter {
                AccessibilityNotification.Announcement(
                    "موضع التوقّف: الحزب \(Digits.en(Quran.quarter(q).hizb))، الربع \(Digits.en(Quran.position(ofQuarter: q)))"
                ).post()
            }
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
            // يُعرض من أعلى البطاقة، ثم ينزل إلى موضع التوقّف حين يُقاس صفّه (ذ18).
            pendingBookmark = track
            proxy.scrollTo("card.\(track.rawValue)", anchor: .top)
        }
    }

    /// النزول التلقائي (§14.2، ذ18): يُفتح الأرشيف وصفّ أول ظهور لموضع التوقّف عند 30% مما يُرى
    /// فوق شريط «طيّ» الملتصق، بلا حركة تمرير. وإن كان قريباً من أعلى البطاقة بقي العرض من أعلاها،
    /// فلا يتجاوز أعلى الأرشيف. ولا ينزل في غير الفتح، فالتظليل في الأرشيف لا يحرّك الشاشة.
    private func scrollToBookmark(_ track: Track, rowOffset: CGFloat, viewport: CGFloat, proxy: ScrollViewProxy) {
        guard pendingBookmark == track, openTrack == track else { return }
        pendingBookmark = nil
        guard viewport > 0, let id = reviewLayout(for: track).bookmarkRowID else { return }
        let visible = viewport - Self.foldBarHeight
        let target = visible * 0.3
        // سطر «آخر إدخال» فوق البطاقة نحو 22 (18 وفراغ 4).
        guard rowOffset + Self.lastEntryHeight > target else { return }
        var plain = Transaction()
        plain.disablesAnimations = true
        withTransaction(plain) {
            proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: target / viewport))
        }
    }

    /// ارتفاع شريط «طيّ» الملتصق: 35 وحشو 8 وخطّ 1.
    private static let foldBarHeight: CGFloat = 44
    private static let lastEntryHeight: CGFloat = 22
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
