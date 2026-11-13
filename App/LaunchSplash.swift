import SwiftUI

/// حركة البداية (ملاحظتا المالك 13 نوفمبر 2026، ش7): بعد كل إغلاق كلي للتطبيق ينسدل شريط العلامة من الأعلى بهدوء
/// على شريط رأس السورة، ثم تظهر الشاشة الرئيسية بتلاشٍ هادئ، بلا أيقونة بينهما (الملاحظة الثانية 19:39 UTC).
/// نحو 1.7 ث، ولمسة تتخطّاها.
///
/// شاشة البداية الثابتة (`LaunchScreen.storyboard`) هي أول هذه الحركة: الأرضية والشريط وحدهما، بالقياسات نفسها
/// (§17.2)، فلا قفزة بينهما. ومع «تقليل الحركة» لا انسدال: تظهر العلامة في موضعها ثم التلاشي.
/// ولا تُعرض عند الرجوع من الخلفية، لأن التطبيق لم يُغلق.
struct LaunchSplash: View {
    enum Phase: String { case band, ribbon, fading }

    /// في اختبارات الواجهة لا تُعرض إلا بـ`-launch-splash`، فلا تؤخّر غيرها.
    static var isEnabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        return !args.contains("-ui-testing") || args.contains("-launch-splash")
    }

    /// منتصف التلاشي للقطة (`-splash-freeze fading-half`).
    static var isHalfFade: Bool {
        ProcessInfo.processInfo.arguments.contains("fading-half")
    }

    /// `-splash-freeze band|ribbon|fading-half` في اختبارات الواجهة: تقف الحركة على مرحلة لتُلتقط.
    static var frozen: Phase? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ui-testing"), let i = args.firstIndex(of: "-splash-freeze"), i + 1 < args.count else { return nil }
        return args[i + 1] == "fading-half" ? .fading : Phase(rawValue: args[i + 1])
    }

    // الأزمنة بالثواني. مبدئية (1.4).
    /// الشريط وحده لحظة قبل الانسدال، فلا يفوت الانسدالَ أولُ رسم للتطبيق.
    static let lead = 0.2
    static let ribbonDrop = 0.6
    static let ribbonRest = 0.3
    /// التلاشي إلى الشاشة الرئيسية، هادئاً. يجري داخل الحركة نفسها (`fading`)، لا بانتقال إزالة العنصر،
    /// لأن انتقال الإزالة ظهر في المعاينة ومضة في إطار واحد.
    static let fadeOut = 0.6

    let done: () -> Void
    @State private var phase: Phase = .band
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            // كما في الـstoryboard: العلامة من أعلى الشاشة إلى أسفل الشريط + 32 + 2.04، ومركزها 68.35% من العرض.
            let ribbonHeight = h / 2 + 42.5 + 34.04
            ZStack {
                Color("LaunchPaper")
                ZStack {
                    Image("LaunchBand")
                        .frame(width: w, height: 85)
                        .clipped()
                        .position(x: w / 2, y: h / 2)
                    Image("LaunchRibbon")
                        .frame(width: 48.62, height: ribbonHeight, alignment: .bottom)
                        .clipped()
                        .position(x: w * 0.6835, y: ribbonHeight / 2)
                        .offset(y: phase == .band ? -ribbonHeight : 0)
                }
            }
        }
        .opacity(phase == .fading ? (Self.isHalfFade ? 0.5 : 0) : 1)
        .ignoresSafeArea()
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Rectangle())
        .onTapGesture { done() }
        // م56: لا يقف VoiceOver على عنصر صامت لحظة الحركة.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: AppInfo.name))
        .accessibilityIdentifier("splash.\(phase.rawValue)")
        .task { await run() }
    }

    /// `-splash-lead ث` في اختبارات الواجهة: تسجيل المعاينة على محاكي الفحص البطيء يبدأ بعد أن يُرسم التطبيق.
    static var leadTime: Double {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ui-testing"), let i = args.firstIndex(of: "-splash-lead"), i + 1 < args.count,
              let value = Double(args[i + 1]) else { return lead }
        return value
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func run() async {
        if let frozen = Self.frozen {
            phase = frozen
            return
        }
        await pause(Self.leadTime)
        if reduceMotion {
            phase = .ribbon
            await pause(Self.ribbonRest + 0.15)
        } else {
            withAnimation(.easeOut(duration: Self.ribbonDrop)) { phase = .ribbon }
            await pause(Self.ribbonDrop + Self.ribbonRest)
        }
        withAnimation(.easeInOut(duration: Self.fadeOut)) { phase = .fading }
        await pause(Self.fadeOut)
        done()
    }
}
