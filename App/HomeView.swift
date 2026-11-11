import SwiftData
import Combine
import SwiftUI
import UIKit

/// الشاشة الرئيسية «الورد اليومي» (7.1) كما تُبنى في ش1: المسارات الثلاثة بترتيب المالك،
/// كل بطاقة مطويّة على موضع توقّفها، والأرشيف يُفتح من شريط الإسدال.
/// وفي ش2: الضغطة على الربع تظلّله بتاريخه ووقته وعليه علامة «اليوم» (5.3، §13.1).
/// وفي ش5: العدّاد تحت البطاقات، وشريطاً أسفل الشاشة مع الأرشيف المفتوح (5.7، §16).
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var placements: [HizbPlacement]
    @Query private var readings: [QuarterReading]
    /// دورات مسارَي المراجعة (5.5، §14.1).
    @Query private var cycles: [ReviewCycle]
    /// إتمام الأوجه في المحفوظ الجديد (5.6).
    @Query private var completions: [PageCompletion]
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
    /// تأكيد «ابدأ دورة جديدة» (§14.5، ذ21).
    @State private var newCycle: Track?
    /// حوار اكتمال الحزب (§15.5): يظهر بعد 0.45 ث من الضغطة التي أتمّت آخر أوجهه (ذ34).
    @State private var completedHizb: Int?
    @State private var completedTask: Task<Void, Never>?
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
    /// صفّ الأوجه الباقي في المحفوظ الجديد بعد انتقال موضع التوقّف عنه، مدّة المهلة (§15.3، ذ30).
    @State private var pinnedPages: FiveRow?
    @State private var pinPagesTask: Task<Void, Never>?
    /// مهلة بقاء الصفّ 0.8 ث. وفي اختبارات الواجهة تطول بـ`-pin-seconds` ليُقرأ الصفّ فيها على محاكٍ بطيء.
    static let pinSeconds: Double = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-ui-testing"), let i = args.firstIndex(of: "-pin-seconds"), i + 1 < args.count,
           let value = Double(args[i + 1]) { return value }
        return 0.8
    }()

    /// العدّاد (5.7، §16.8): في `UserDefaults` وحده، لا في SwiftData.
    @AppStorage(CounterStore.key) private var count = 0
    /// ارتفاع «تصفير» فوق الدائرة، لحساب القطر من المكان الباقي (§16.1).
    @State private var resetHeight: CGFloat = 26
    /// الشاشة القصيرة (ذ44): العدّاد صفّ أفقي، وتضيق ثلاث مسافات حتى يُرى كاملاً بلا تمرير.
    @State private var isShort = false
    /// حافّة الشاشة السفلى الآمنة، ليكون الشريط 88 من أسفل الشاشة والإشعار فوقه (§16.5).
    @State private var safeBottom: CGFloat = 0
    @State private var screenWidth: CGFloat = 393

    /// المسار الذي فُتح أرشيفه للتوّ، وينتظر قياس صفّ موضع التوقّف لينزل إليه (ذ18).
    @State private var pendingBookmark: Track?

    /// موضع شريط «طيّ» في أسفل البطاقة المفتوحة، لإلصاقه بأسفل الشاشة إن نزل تحتها (م23).
    @State private var foldBar = FoldBarPosition()

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = geo.size.width < 390 ? 16 : 20
            // عرض الصفّ داخل البطاقة المطويّة: الشاشة ناقص الهامشين وحشو البطاقة وحدّها.
            let narrow = geo.size.width - margin * 2 - 34 < 330
            // الشريط مع الأرشيف المفتوح 88 من أسفل الشاشة، ويأخذ من التمرير ما فوق الحافّة الآمنة (§16.5).
            let barInside = openTrack == nil ? 0 : max(0, CounterLayout.barHeight - geo.safeAreaInsets.bottom)
            let viewport = geo.size.height - barInside
            // مطويّاً تمتدّ الصفحة تحت الحافّة الآمنة السفلى حتى 10 من أسفل الشاشة، كما في المرجع
            // (s5-fold: الإشارة أسفلها 22 من أسفل الشاشة)، فيأخذ العدّاد ما بقي كلّه (§16.1).
            let foldHeight = geo.size.height + max(0, geo.safeAreaInsets.bottom - 10)
            let counterMode = foldCounterMode(height: foldHeight)
            VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // الحالة المطويّة تملأ الشاشة، وفي أسفلها إشارة «اسحب للأعلى»، فلا تُرى المفاتيح
                        // إلا بالسحب (§13.6). والعدّاد بين البطاقات والإشارة (§16.1، §16.6).
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: isShort && openTrack == nil ? 6 : 8) {
                                HomeHeader(now: now)
                                    .padding(.bottom, 6)
                                ForEach(Track.allCases, id: \.self) { track in
                                    card(for: track, narrow: narrow, proxy: proxy, viewport: viewport)
                                        .id("card.\(track.rawValue)")
                                }
                            }
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardsHeight = $0 }
                            if openTrack == nil {
                                // العدّاد مكان الفراغ تحت البطاقات (§16.1): كبيراً في وسط ما بقي والإشارة تحته،
                                // أو صفّاً أفقياً بلا إشارة إن لم يتّسع للدائرة 76 (ذ44).
                                switch counterMode {
                                case .big:
                                    Spacer(minLength: 8)
                                    CounterView(mode: counterMode, count: count, onTap: increment)
                                        .padding(.bottom, 4)
                                        .onGeometryChange(for: CGFloat.self) { proxy in
                                            proxy.size.height
                                        } action: { height in
                                            if case .big(let d) = counterMode { resetHeight = max(0, height - 4 - 6 - d) }
                                        }
                                    Spacer(minLength: 0)
                                    KeysHint()
                                default:
                                    CounterView(mode: .row, count: count, onTap: increment)
                                        .padding(.top, 6)
                                        .padding(.bottom, 4)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .frame(minHeight: openTrack == nil ? foldHeight - Self.topPadding - 6 : nil, alignment: .top)
                        SymbolKeys()
                            .padding(.top, openTrack == nil ? 6 : 14)
                            .padding(.bottom, 10)
                    }
                    .padding(.horizontal, margin)
                    .padding(.top, Self.topPadding)
                    .padding(.bottom, 24 + (openTrack == nil ? geo.safeAreaInsets.bottom : 0))
                }
                .scrollIndicators(.hidden)
                // لا يمرّ المحتوى تحت شريط الحالة عند التمرير.
                .clipped()
                .ignoresSafeArea(.container, edges: openTrack == nil ? .bottom : [])
                .coordinateSpace(.named(FoldBarPosition.space))
                .overlay(alignment: .bottom) {
                    // الشريط في أسفل البطاقة، ولا يلتصق بأسفل الشاشة إلا حين يكون تحتها
                    // والبطاقة ظاهرة، كالتصاق CSS sticky في التصميم (7.1، م23). وفوق العدّاد مباشرة (§16.5).
                    if let open = openTrack, foldBar.isBelow(viewportHeight: viewport) {
                        StickyFoldBar(track: open) { toggle(open, proxy: proxy) }
                            .padding(.horizontal, margin)
                    }
                }
            }
            if openTrack != nil {
                // العدّاد شريطاً ملتصقاً بأسفل الشاشة خارج التمرير، بالعدد نفسه (§16.5).
                Color.clear
                    .frame(height: barInside)
                    .overlay(alignment: .top) {
                        CounterView(mode: .bar, count: count, onTap: increment)
                    }
            }
            }
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { safeBottom = $0 }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { screenWidth = $0 }
            .onChange(of: counterMode, initial: true) { _, mode in isShort = mode == .row }
            // اهتزاز خفيف مع كل ضغطة تزيد العدد (5.7، §16.3، ذ41)، ولا شيء غيره ولا صوت.
            // ويتبع إعداد «اللمس» في الجهاز، ولا يُجرَّب على المحاكي.
            .sensoryFeedback(trigger: count, CounterLayout.feedback(from:to:))
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
                // ومع الشريط فوقه: أسفله 104 من أسفل الشاشة، و96 على 375 (§16.5).
                ToastView(text: toast)
                    .padding(.bottom, openTrack == nil ? 42 : max(42, (screenWidth < 390 ? 96 : 104) - safeBottom))
                    .transition(.opacity)
            }
        }
        .overlay {
            // قائمة الحزب بالضغط المطوّل (§12.5).
            if let request = hizbMenu {
                HizbMenuOverlay(request: request) { action in
                    hizbMenu = nil
                    switch action {
                    case .move(let target): move([request.hizb], from: request.track, to: target)
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
            ManageSheet(request: request, hizbs: Library.activeHizbs(in: request.track, from: placements)) { hizbs, target in
                if request.mode == .remove {
                    remove(hizbs, from: request.track)
                } else {
                    move(hizbs, from: request.track, to: target)
                }
            }
        }
        .overlay {
            // تأكيد الإزالة من قائمة الحزب (§12.5).
            if let removal {
                ChoiceDialog(
                    title: Phrase.removeQuestion(removal.hizbs, from: removal.track),
                    note: Phrase.removeNote(removal.hizbs.count, from: removal.track),
                    primary: Phrase.removeAnswer(removal.hizbs.count), primaryID: "remove.confirm",
                    quiet: "إلغاء", quietID: "remove.cancel",
                    titleID: "remove.question"
                ) { confirmed in
                    self.removal = nil
                    if confirmed { remove(removal.hizbs, from: removal.track) }
                }
            }
        }
        .overlay {
            // حوار اكتمال الحزب (§15.5): «ارفعه إلى مراجعة القريب» أو «لاحقاً»، ولا ينقل التطبيق شيئاً بنفسه.
            if let hizb = completedHizb {
                HizbCompleteDialog(hizb: hizb) { raising in
                    completedHizb = nil
                    if raising { raise(hizb) }
                }
            }
        }
        .overlay {
            // تأكيد «ابدأ دورة جديدة»، لأن ما تقدّم من الدورة لا يعود بالتراجع (ذ21).
            if let track = newCycle {
                ChoiceDialog(
                    title: Phrase.newCycleQuestion(track),
                    note: Phrase.newCycleNote,
                    primary: "ابدأ دورة جديدة", primaryID: "newcycle.confirm",
                    quiet: "إلغاء", quietID: "newcycle.cancel",
                    titleID: "newcycle.question"
                ) { confirmed in
                    newCycle = nil
                    if confirmed { restartCycle(track) }
                }
            }
        }
    }

    /// ينقل إلى مسار آخر فوراً بلا سؤال، لأن النقل لا يمحو شيئاً (ذ6)، ثم يؤكّده بإشعار.
    /// ونقل حزب مكتمل من الجديد إلى القريب هو الرفع (§15.5–15.6) بإشعاره (ذ36)، وغير المكتمل «نُقل» (م48).
    private func move(_ hizbs: [Int], from track: Track, to target: Track) {
        let raising = track == .newMemorization && target == .nearReview && hizbs.count == 1
            && newLayout.isComplete(hizbs[0])
        let bookmarkBefore = target.isReview ? reviewLayout(for: target).bookmarkHizb : nil
        do {
            let moved = try Library.move(hizbs, from: track, to: target, in: context, now: WirdClock.now())
            foldIfEmptied(track, removing: moved)
            guard !moved.isEmpty else { return }
            if raising {
                completedHizb = nil
                let after = reviewLayout(for: target,
                                         readings: (try? context.fetch(FetchDescriptor<QuarterReading>())) ?? readings,
                                         cycles: (try? context.fetch(FetchDescriptor<ReviewCycle>())) ?? cycles,
                                         placements: (try? context.fetch(FetchDescriptor<HizbPlacement>())) ?? placements)
                // ذ22: إن انتقل إليه موضع التوقّف في القريب قاله الإشعار. والقريب الفارغ لا موضع له قبله.
                let bookmark = bookmarkBefore != nil && after.bookmarkHizb == moved[0] && bookmarkBefore != moved[0]
                show(Phrase.raisedToast(moved[0], bookmark: bookmark))
            } else {
                show(Phrase.movedToast(moved, to: target))
            }
        } catch {
            show("تعذّر النقل")
        }
    }

    /// الرفع إلى القريب من الحوار أو الزرّ (§15.5).
    private func raise(_ hizb: Int) {
        move([hizb], from: .newMemorization, to: .nearReview)
    }

    /// تنتهي الدورة بيد المالك وتبدأ غيرها: «0 من 36»، والإطار على أول ربع، والصفّ على أول حزب (§14.5).
    private func restartCycle(_ track: Track) {
        pinTasks[track]?.cancel()
        pinTasks[track] = nil
        pinned[track] = nil
        do {
            try Cycles.restart(track, in: context, now: WirdClock.now())
            show(Phrase.newCycleToast(track))
        } catch {
            show("تعذّر بدء دورة جديدة")
        }
    }

    /// يزيل بعد التأكيد، ويبقى سجلّ التلاوة محفوظاً (5.1)، ثم يؤكّده بإشعار.
    private func remove(_ hizbs: [Int], from track: Track) {
        do {
            let removed = try Library.remove(hizbs, from: track, in: context, now: WirdClock.now())
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
            let bookmarkBefore = track.isReview ? reviewLayout(for: track).bookmarkHizb : nil
            let changed = try Library.add(hizbs, to: track, in: context, moving: moving, now: WirdClock.now())
            // ما كان في مسار آخر قد نُقل، وما سواه أُضيف جديداً.
            let moved = changed.filter { before[$0] != nil && before[$0] != track }
            let added = changed.filter { !moved.contains($0) }
            guard !changed.isEmpty else { return show("لم يُضف شيء") }
            // §14.6 (ذ22): إن كان المضاف قبل موضع التوقّف انتقل إليه الموضع والصفّ المطويّ بغير ضغطة،
            // فيقوله الإشعار. والمسار الذي كان فارغاً لا موضع له قبلها.
            let after = reviewLayout(for: track,
                                     readings: (try? context.fetch(FetchDescriptor<QuarterReading>())) ?? readings,
                                     cycles: (try? context.fetch(FetchDescriptor<ReviewCycle>())) ?? cycles,
                                     placements: (try? context.fetch(FetchDescriptor<HizbPlacement>())) ?? placements)
            if let old = bookmarkBefore, let new = after.bookmarkHizb, new != old, changed.contains(new) {
                pinTasks[track]?.cancel()
                pinTasks[track] = nil
                pinned[track] = nil
                show(Phrase.addedWithBookmark(added: added, moved: moved, bookmark: new, to: track))
            } else {
                show(Phrase.addedToast(added: added, moved: moved, to: track))
            }
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
                VStack(alignment: .leading, spacing: isShort && openTrack == nil ? 2 : 4) {
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
                    } onNewCycle: {
                        newCycle = track
                    } onFoldBarMove: { maxY in
                        foldBar.barMaxY = maxY
                    }
                }
            }
        } else {
            // المحفوظ الجديد (§15.1–15.2): فارغاً حتى يختار المالك الحزب الذي يحفظه، ثم أوجهه.
            let layout = newLayout
            if layout.isEmpty {
                EmptyTrackCard(track: track) { addTrack = track }
            } else {
                VStack(alignment: .leading, spacing: isShort && openTrack == nil ? 2 : 4) {
                    LastEntryLine(track: track, date: LastEntry.latest(inPages: layout.pages, completions: completions),
                                  now: now)
                    NewTrackCard(layout: layout, isOpen: openTrack == track, displayedRow: pinnedPages,
                                 hizbMenu: HizbMenu(track: track) { hizb, frame in
                                     hizbMenu = HizbMenuRequest(track: track, hizb: hizb, labelFrame: frame)
                                 },
                                 onPage: { completePage($0) }, onRaise: { raise($0) }) {
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
        }
    }

    /// ضغطة على الوجه (5.6، §15.3): أتممته الآن، وعلى ما أُتمّ اليوم تراجع، وعلى ما أُتمّ قبل اليوم إشعار
    /// بتاريخ إتمامه ولا يتغيّر شيء (ذ29). ولا اهتزاز ولا إشعار للإتمام والتراجع (ذ11)، ويُعلَنان لقارئ الشاشة.
    private func completePage(_ page: Int) {
        let at = WirdClock.now()
        now = at
        let layoutBefore = newLayout
        let before = layoutBefore.foldedRow
        do {
            let result = try Pages.tap(page: page, in: context, now: at)
            switch result {
            case .completed:
                AccessibilityNotification.Announcement("أتممته اليوم").post()
            case .undone:
                AccessibilityNotification.Announcement("تراجعت").post()
                completedTask?.cancel()
            case .completedBefore(let date):
                show(Phrase.pageDoneBefore(page, on: date, now: at))
                return
            }
            let fresh = (try? context.fetch(FetchDescriptor<PageCompletion>())) ?? completions
            let after = newLayout(completions: fresh)
            // الضغطة التي أتمّت آخر وجه في حزب: يمتلئ الوجه، ثم بعد 0.45 ث الحوار (ذ34)، ولا مهلة للصفّ.
            if result == .completed,
               let done = after.hizbs.first(where: { after.isComplete($0) && !layoutBefore.isComplete($0)
                                                   && Quran.pages(ofHizb: $0).contains(page) }) {
                completedTask?.cancel()
                completedTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    guard !Task.isCancelled else { return }
                    completedHizb = done
                }
                return
            }
            followPages(from: before, to: after.foldedRow)
        } catch {
            show("تعذّر التسجيل")
        }
    }

    /// انتقال موضع التوقّف إلى صفّ أوجه آخر (ذ30): يبقى الصفّ 0.8 ث بما أُتمّ وعلامة «اليوم» بلا إطار،
    /// ثم يتلاشى إلى صفّ الموضع في 0.25 ث، وفوراً مع «تقليل الحركة». والتراجع في المهلة يُبقيه (كما في م38).
    private func followPages(from old: FiveRow?, to new: FiveRow?) {
        guard openTrack != .newMemorization else { return }
        let shown = pinnedPages ?? old
        if new == shown {
            pinPagesTask?.cancel()
            pinPagesTask = nil
            pinnedPages = nil
            return
        }
        guard let shown, new != nil, pinnedPages == nil else { return }
        pinnedPages = shown
        pinPagesTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.pinSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                pinnedPages = nil
            }
            pinPagesTask = nil
            if let page = newLayout.bookmarkPage {
                AccessibilityNotification.Announcement("موضع التوقّف: الوجه \(Digits.en(page))").post()
            }
        }
    }

    /// تخطيط المحفوظ الجديد: أحزابه، وأوجهه المتمّة، وما أُتمّ منها اليوم (§15.2).
    private var newLayout: NewTrackLayout { newLayout(completions: completions) }

    private func newLayout(completions: [PageCompletion]) -> NewTrackLayout {
        let calendar = WirdDate.calendar()
        return NewTrackLayout(hizbs: Library.activeHizbs(in: .newMemorization, from: placements),
                              completed: Set(completions.map(\.page)),
                              today: Set(completions.filter { calendar.isDate($0.completedAt, inSameDayAs: now) }.map(\.page)))
    }

    /// تخطيط مسار المراجعة بأرباعه المظلّلة في دورته الحالية (§14.1–14.2).
    private func reviewLayout(for track: Track, readings: [QuarterReading]? = nil,
                              cycles: [ReviewCycle]? = nil, placements: [HizbPlacement]? = nil) -> ReviewTrackLayout {
        let readings = readings ?? self.readings
        let cycles = cycles ?? self.cycles
        let placements = placements ?? self.placements
        let hizbs = Library.activeHizbs(in: track, from: placements)
        let quarters = hizbs.flatMap(Quran.quarters(ofHizb:))
        let start = Cycles.current(track, in: cycles)?.startedAt
        return ReviewTrackLayout(track: track, hizbs: hizbs,
                                 done: Cycles.done(quarters: quarters, readings: readings, since: start,
                                                   floors: Library.leftNew(from: placements)),
                                 completedDays: Cycles.completedDays(track, quarters: quarters, cycles: cycles,
                                                                     readings: readings, now: now))
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
            let (result, changes) = try Cycles.tap(quarter: quarter, track: track, in: context, now: at)
            var announcement = result == .shaded ? "تلوته اليوم" : "تراجعت"
            for review in reviews {
                if case .completed(let days) = changes[review] {
                    // §14.4: يُعلَن الاكتمال، وعودة الموضع إلى أول المسار.
                    announcement += "، اكتملت دورة \(review.title) في \(Phrase.days(days))، وعاد موضع التوقّف إلى أول المسار"
                }
            }
            AccessibilityNotification.Announcement(announcement).post()
            let freshReadings = (try? context.fetch(FetchDescriptor<QuarterReading>())) ?? readings
            let freshCycles = (try? context.fetch(FetchDescriptor<ReviewCycle>())) ?? cycles
            for review in reviews {
                follow(review, from: before[review] ?? nil,
                       to: reviewLayout(for: review, readings: freshReadings, cycles: freshCycles).bookmarkHizb)
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

    /// ضغطة على الدائرة تزيد العدد واحداً، ويُعلَن العدد الجديد لقارئ الشاشة (§16.2، §16.8).
    private func increment() {
        count += 1
        AccessibilityNotification.Announcement(CounterLayout.text(count)).post()
    }

    /// حالة العدّاد في الشاشة المطويّة (§16.1، ذ44): القطر ما بقي بين البطاقات والإشارة بعد «تصفير»،
    /// وإن قلّ عن 76 فصفّ أفقي. والمسافات الضيّقة في الصفّ تُضاف إلى الحساب حتى لا يتردّد بين الحالين.
    private func foldCounterMode(height: CGFloat) -> CounterView.Mode {
        let saved: CGFloat = isShort ? Self.shortSavings : 0
        let room = height - Self.topPadding - 6 - (cardsHeight + saved) - 8 - Self.hintHeight - resetHeight - 6 - 4 - 8
        if let d = CounterLayout.diameter(room: room) { return .big(d) }
        return .row
    }

    /// ما تضيّقه الشاشة القصيرة (ذ44): بين البطاقات 6 بدل 8 (ثلاث)، وتحت «آخر إدخال» 2 بدل 4 (ثلاث).
    private static let shortSavings: CGFloat = 12

    /// لا يُفتح إلا مسار واحد في وقت واحد؛ فتح مسار يطوي غيره (7.1).
    private func toggle(_ track: Track, proxy: ScrollViewProxy) {
        foldBar = FoldBarPosition()
        pinPagesTask?.cancel()
        pinPagesTask = nil
        pinnedPages = nil
        if openTrack == track {
            openTrack = nil
            proxy.scrollTo("card.\(track.rawValue)", anchor: .top)
        } else {
            openTrack = track
            // يُعرض من أعلى البطاقة، ثم ينزل إلى موضع التوقّف حين يُقاس صفّه (ذ18).
            // ولا نزول في المحفوظ الجديد (§15.3).
            pendingBookmark = track.isReview ? track : nil
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
