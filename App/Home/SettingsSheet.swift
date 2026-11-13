import SwiftUI
#if WIRD_ICLOUD
import CloudKit
#endif

/// حالة النسخ الاحتياطي (5.8، §17.3). الحالة بشكل الشارة لا بلونها (8.3، ذ50).
enum BackupStatus: String, CaseIterable {
    /// بناء بلا iCloud (المثبَّت بالحساب المجاني): السجلّ في الجهاز وحده.
    case device
    /// iCloud يعمل.
    case iCloudOn = "on"
    /// iCloud غير مفعّل في الجهاز.
    case iCloudOff = "off"

    /// في اختبارات الواجهة `-backup on|off|device` يفرض الحالة للمعاينة.
    static var forcedForUITesting: BackupStatus? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ui-testing"), let i = args.firstIndex(of: "-backup"), i + 1 < args.count else { return nil }
        return BackupStatus(rawValue: args[i + 1])
    }

    /// الحالة عند فتح الورقة، قبل سؤال iCloud: في بناء iCloud تُقدَّر من تسجيل الدخول في الجهاز.
    static var current: BackupStatus {
        if let forced = forcedForUITesting { return forced }
        guard Cloud.isBuiltIn else { return .device }
        return FileManager.default.ubiquityIdentityToken != nil ? .iCloudOn : .iCloudOff
    }

    /// الحالة من iCloud نفسه (5.8): «iCloud» إن كان الحساب متاحاً، وإلا «متوقّف».
    /// ولا يُسأل iCloud إلا في بنائه، فسؤاله بلا صلاحية يوقف التطبيق.
    static func resolved() async -> BackupStatus {
        if let forced = forcedForUITesting { return forced }
        #if WIRD_ICLOUD
        do {
            let account = try await CKContainer(identifier: Cloud.containerID).accountStatus()
            return account == .available ? .iCloudOn : .iCloudOff
        } catch {
            return .iCloudOff
        }
        #else
        return .device
        #endif
    }

    var title: String {
        switch self {
        case .device: "في هذا الجهاز"
        case .iCloudOn, .iCloudOff: "iCloud"
        }
    }

    /// السطر تحت العنوان. ونصّ «متوقّف» بنصّ 5.8 حرفاً.
    var subtitle: String {
        switch self {
        case .device: "سجلّك محفوظ في هذا الجهاز"
        case .iCloudOn: "يُنسخ سجلّك إلى iCloud تلقائياً"
        case .iCloudOff: "النسخ الاحتياطي متوقّف: iCloud غير مفعّل"
        }
    }

    /// الشرح تحت المجموعة. و«في هذا الجهاز» بنصّ م53 بلا اسم الشريحة.
    var footnote: String {
        switch self {
        case .device: "النسخ إلى iCloud يأتي في تحديث قريب، ويُنقل إليه سجلّك كما هو."
        case .iCloudOn: "كل ما تظلّله وتحفظه يُنسخ إلى حسابك في iCloud، فيعود كاملاً إن حذفت التطبيق ثم ثبّتّه. والعدّاد في هذا الجهاز وحده."
        case .iCloudOff: "يعمل التطبيق في هذا الجهاز، وسجلّك محفوظ فيه. ويبدأ النسخ وحده متى سجّلت الدخول إلى iCloud في إعدادات الجهاز."
        }
    }
}

/// ورقة الإعدادات (7.4، §17.3، ذ50): بارتفاع الشاشة كورقة الإضافة، و«تمّ» يغلقها.
/// مجموعتان: «النسخ الاحتياطي» بحالة من ثلاث، و«التطبيق» بالإصدار و«عن التطبيق» تُدفع داخل الورقة.
/// ولا غير ذلك: لا إعدادات ورد (12)، ولا اختيار للوضع الليلي، ولا شيء للعدّاد.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showsAbout = false
    @State private var status: BackupStatus = .current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SheetTitleBar(title: "الإعدادات", done: { dismiss() })
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsGroupHeading(text: "النسخ الاحتياطي")
                        SettingsGroup {
                            BackupRow(status: status)
                        }
                        Text(verbatim: status.footnote)
                            .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 6)
                            .padding(.top, 8)
                            .accessibilityIdentifier("settings.backup.note")
                        SettingsGroupHeading(text: "التطبيق")
                        SettingsGroup {
                            HStack {
                                Text(verbatim: "الإصدار")
                                    .foregroundStyle(Theme.ink)
                                Spacer(minLength: 12)
                                Text(verbatim: AppInfo.version)
                                    .foregroundStyle(Theme.muted)
                                    .monospacedDigit()
                            }
                            .font(Theme.font(.regular, size: 16, relativeTo: .body))
                            .settingsRow()
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("settings.version")
                            Rectangle().fill(Theme.line).frame(height: 1)
                            Button { showsAbout = true } label: {
                                HStack {
                                    Text(verbatim: "عن التطبيق")
                                        .font(Theme.font(.regular, size: 16, relativeTo: .body))
                                        .foregroundStyle(Theme.ink)
                                    Spacer(minLength: 12)
                                    // «إلى الأمام» في RTL يشير يساراً.
                                    Image(systemName: "chevron.forward")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.muted)
                                        .accessibilityHidden(true)
                                }
                                .settingsRow()
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("settings.about")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }
            .background(Theme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showsAbout) {
                AboutPage(done: { dismiss() })
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        // تُسأل حالة iCloud كلما فُتحت الورقة، فيظهر تسجيل الدخول أو الخروج في إعدادات الجهاز.
        .task { status = await BackupStatus.resolved() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.Radius.sheet)
        .presentationBackground(Theme.paper)
    }
}

/// «عن التطبيق» (§17.3): «‹ الإعدادات» للرجوع، والعنوان في الوسط، و«تمّ». ثم أيقونة التطبيق واسمه وإصداره (ذ53)،
/// ثم مصدر البيانات القرآنية بنسبته التي تشترطها الرخصة (`data/SOURCE.md`).
/// ولا اسم للمالك ولا شعار: التطبيق عامّ (القرار 32).
struct AboutPage: View {
    @Environment(\.dismiss) private var pop
    let done: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(verbatim: "عن التطبيق")
                    .font(Theme.font(.semiBold, size: 17, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Button { pop() } label: {
                        HStack(spacing: 2) {
                            // «رجوع» في RTL يشير يميناً.
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 15, weight: .semibold))
                            Text(verbatim: "الإعدادات")
                                .font(Theme.font(.regular, size: 16, relativeTo: .body))
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(minHeight: Theme.Size.touch)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: "رجوع إلى الإعدادات"))
                    .accessibilityIdentifier("about.back")
                    Spacer()
                    DoneButton(action: done)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 6) {
                        // أيقونة التطبيق 76 بزاوية 17 وحدّ `line`: الفاتحة نهاراً والداكنة ليلاً (ذ53). زينة.
                        Image("AboutIcon")
                            .resizable()
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                            .accessibilityHidden(true)
                            .accessibilityIdentifier("about.icon")
                        Text(verbatim: AppInfo.name)
                            .font(Theme.font(.semiBold, size: 20, relativeTo: .title3))
                            .foregroundStyle(Theme.ink)
                            .padding(.top, 8)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("about.name")
                        Text(verbatim: "الإصدار \(AppInfo.version)")
                            .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
                            .foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("about.app")
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)
                    .padding(.bottom, 4)
                    SettingsGroupHeading(text: "مصدر البيانات القرآنية")
                    SettingsGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: "حدود الأوجه والأرباع والأحزاب والسور من بيانات مشروع «تنزيل» المفتوحة، على مصحف المدينة النبوية.")
                            Text(verbatim: "وصُحّح منها 26 حدّاً على طبعة مجمّع الملك فهد.")
                            Text(verbatim: "Tanzil.net · رخصة CC BY 3.0")
                                .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
                                .foregroundStyle(Theme.muted)
                        }
                        .font(Theme.font(.regular, size: 14.5, relativeTo: .subheadline))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("about.source")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.paper)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// رأس الورقة: العنوان 21/600 و«تمّ».
private struct SheetTitleBar: View {
    let title: String
    let done: () -> Void

    var body: some View {
        HStack {
            Text(verbatim: title)
                .font(Theme.font(.semiBold, size: 21, relativeTo: .title3))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("settings.title")
            Spacer()
            DoneButton(action: done)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 6)
    }
}

private struct DoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: "تمّ")
                .font(Theme.font(.regular, size: 16, relativeTo: .body))
                .foregroundStyle(Theme.ink)
                .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.done")
    }
}

/// عنوان المجموعة 13 `muted`.
private struct SettingsGroupHeading: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 6)
            .padding(.top, 18)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

/// المجموعة: بطاقة `card` بزاوية 16 وحدّ `line`.
private struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }
}

private extension View {
    /// صفّ 52 بحشو 10/16.
    func settingsRow() -> some View {
        frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
    }
}

/// صفّ حالة النسخ: الشارة زينة، والعنوان والحالة عنصر واحد لقارئ الشاشة (§17.3).
private struct BackupRow: View {
    let status: BackupStatus

    var body: some View {
        HStack(spacing: 12) {
            BackupBadge(status: status)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: status.title)
                    .font(Theme.font(.regular, size: 16, relativeTo: .body))
                    .foregroundStyle(Theme.ink)
                Text(verbatim: status.subtitle)
                    .font(Theme.font(.regular, size: 13, relativeTo: .footnote))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .settingsRow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "النسخ الاحتياطي: \(status.title)، \(status.subtitle)"))
        .accessibilityIdentifier("settings.backup.\(status.rawValue)")
    }
}

/// الشارة 26 (ذ50): صحّ في دائرة ممتلئة · سحابة مشطوبة بحدّ `muted` · هاتف بحدّ `ink`. رموز النظام 13 في مركزها (م52).
private struct BackupBadge: View {
    let status: BackupStatus

    var body: some View {
        switch status {
        case .iCloudOn:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.paper)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.ink))
        case .iCloudOff:
            Image(systemName: "icloud.slash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(Theme.muted, lineWidth: 1.5))
        case .device:
            Image(systemName: "iphone")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 1.5))
        }
    }
}
