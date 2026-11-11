import SwiftUI

/// العدّاد (5.7، design/system.md §16): عدد صحيح واحد في `UserDefaults` وحده (القرار 10، §16.8)،
/// لا في SwiftData ولا في `SchemaV1`، فلا يمسّه ترحيل ولا مزامنة، ولا تاريخ له ولا مسار.
enum CounterStore {
    static let key = "counter.count"

    /// اختبارات الواجهة: يبدأ العدّاد صفراً في كل تشغيل، أو بالعدد بعد `-counter`.
    /// ومع `-keep-counter` يبقى ما حُفظ، لاختبار الحفظ بعد إعادة التشغيل.
    static func prepareForUITesting(_ arguments: [String] = ProcessInfo.processInfo.arguments,
                                    defaults: UserDefaults = .standard) {
        guard arguments.contains("-ui-testing"), !arguments.contains("-keep-counter") else { return }
        var value = 0
        if let i = arguments.firstIndex(of: "-counter"), i + 1 < arguments.count, let n = Int(arguments[i + 1]) {
            value = max(0, n)
        }
        defaults.set(value, forKey: key)
    }
}

/// مقاسات العدّاد (§16.1، §16.5، §16.7). منطق خالص بلا واجهة.
enum CounterLayout {
    /// القطر ما بقي من الشاشة بين 76 و136 (§6، ت6).
    static let minDiameter: CGFloat = 76
    static let maxDiameter: CGFloat = 136
    /// دائرة الصفّ الأفقي والشريط.
    static let small: CGFloat = 64
    /// الشريط مع الأرشيف المفتوح: 88 من أسفل الشاشة، وحشوه الأسفل 14 (§16.5).
    static let barHeight: CGFloat = 88
    static let barBottomPadding: CGFloat = 14

    /// القطر من المكان الباقي، و`nil` إن لم يتّسع لـ76 فيصير العدّاد صفّاً أفقياً بدائرة 64 (ذ44).
    static func diameter(room: CGFloat) -> CGFloat? {
        room < minDiameter ? nil : min(maxDiameter, room.rounded(.down))
    }

    /// حجم الرقم بعدد خاناته (ذ39): حتى ثلاث 0.39 من القطر، وأربع 0.31، وخمس فأكثر 0.25.
    static func numberRatio(_ count: Int) -> CGFloat {
        switch String(count).count {
        case ...3: 0.39
        case 4: 0.31
        default: 0.25
        }
    }

    /// حجم الرقم في الدائرة: في الكبيرة نسبته من القطر، وفي الشريط من 64 مضروبة في 0.96 (§6: 24 لثلاث خانات).
    static func numberSize(count: Int, diameter: CGFloat, isBar: Bool) -> CGFloat {
        (diameter * numberRatio(count) * (isBar ? 0.96 : 1)).rounded()
    }

    /// «+» تحت العدد: 0.18 من القطر، و14 في الشريط.
    static func plusSize(diameter: CGFloat, isBar: Bool) -> CGFloat {
        isBar ? 14 : (diameter * 0.18).rounded()
    }

    /// العدد بأرقام إنجليزية بلا فاصل آلاف (ذ39): «12500».
    static func text(_ count: Int) -> String { String(count) }
}

/// دائرة العدّاد: `ink` ممتلئة، والعدد بلون `paper` وتحته «+» (§16.1). والضغط في أي موضع منها
/// يزيد العدد واحداً عند رفع الإصبع، والسحب الذي يبدأ عليها تمرير لا ضغطة (§16.2).
struct CounterCircle: View {
    let count: Int
    let diameter: CGFloat
    /// الشريط والصفّ الأفقي: الرقم من 64 مضروبة في 0.96، و«+» 14.
    var isBar = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                Text(verbatim: CounterLayout.text(count))
                    .font(Theme.fixedFont(.semiBold, size: CounterLayout.numberSize(count: count, diameter: diameter, isBar: isBar)))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                Text(verbatim: "+")
                    .font(Theme.fixedFont(.regular, size: CounterLayout.plusSize(diameter: diameter, isBar: isBar)))
                    .opacity(0.8)
            }
            .foregroundStyle(Theme.paper)
            .environment(\.layoutDirection, .leftToRight)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(Theme.ink))
            .contentShape(Circle())
        }
        .buttonStyle(CounterPressStyle())
        .accessibilityLabel(Text(verbatim: "العدّاد"))
        .accessibilityValue(Text(verbatim: CounterLayout.text(count)))
        .accessibilityHint(Text(verbatim: "ضغطة: زيادة واحد"))
        .accessibilityAdjustableAction { direction in
            if direction == .increment { onTap() }
        }
        .accessibilityIdentifier("counter.circle")
    }
}

/// ما دام الإصبع على الدائرة تصغر إلى 0.96 وتخفت إلى 86% في 0.08 ث، والرقم ساكن (ذ40).
struct CounterPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// «تصفير»: كبسولة بحدّ `line` (§6، §16.4). والعدد صفر: نصّها `muted`، هادئة لا تعمل (ذ43).
/// ومساحة لمسها 44 لا تزيد ارتفاعها. والإمساك للتصفير في المرحلة 3.
struct CounterResetButton: View {
    let isIdle: Bool
    /// فوق الدائرة الكبيرة 13، وبجانب دائرة الشريط 12.
    var isBig = true

    var body: some View {
        Text(verbatim: "تصفير")
            .font(Theme.font(.regular, size: isBig ? 13 : 12, relativeTo: .caption))
            .foregroundStyle(isIdle ? Theme.muted : Theme.ink)
            .padding(.vertical, 3)
            .padding(.horizontal, isBig ? 14 : 12)
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
            .padding(.vertical, 9)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .padding(.vertical, -9)
            .padding(.horizontal, -4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "تصفير العدّاد"))
            .accessibilityHint(Text(verbatim: "اضغط مطوّلاً للتصفير"))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("counter.reset")
    }
}

/// العدّاد بحالاته الثلاث (§6، §16.1، §16.5، §16.7): كبير تحت البطاقات و«تصفير» فوقه بـ6،
/// أو صفّ أفقي بدائرة 64 و«تصفير» بجانبها بـ18 (القصيرة)، أو شريط أسفل الشاشة مع الأرشيف المفتوح.
struct CounterView: View {
    enum Mode: Equatable {
        case big(CGFloat)
        case row
        case bar
    }

    let mode: Mode
    let count: Int
    let onTap: () -> Void

    var body: some View {
        switch mode {
        case .big(let diameter):
            VStack(spacing: 6) {
                CounterResetButton(isIdle: count == 0)
                CounterCircle(count: count, diameter: diameter, onTap: onTap)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("counter")
        case .row:
            HStack(spacing: 18) {
                CounterResetButton(isIdle: count == 0)
                CounterCircle(count: count, diameter: CounterLayout.small, isBar: true, onTap: onTap)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("counter")
        case .bar:
            VStack(spacing: 0) {
                Rectangle().fill(Theme.line).frame(height: 1)
                HStack(spacing: 18) {
                    CounterResetButton(isIdle: count == 0, isBig: false)
                    CounterCircle(count: count, diameter: CounterLayout.small, isBar: true, onTap: onTap)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, CounterLayout.barBottomPadding)
            }
            .frame(height: CounterLayout.barHeight)
            .background(Theme.paper)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("counter.bar")
        }
    }
}
