import SwiftUI
import UIKit

/// نظام التصميم في الكود: الألوان والخطّ والقياسات من `design/system.md` (§1، §3، §4).
/// لا يُكتب لون خارج هذه الأسماء (system.md §11).
enum Theme {
    enum Weight: String, CaseIterable {
        // أسماء PostScript كما في ملفات الخط.
        case regular = "IBMPlexSansArabic"
        case medium = "IBMPlexSansArabic-Medm"
        case semiBold = "IBMPlexSansArabic-SmBld"
        case bold = "IBMPlexSansArabic-Bold"
    }

    /// IBM Plex Sans Arabic، ويتبع حجم الخط في الجهاز (Dynamic Type).
    static func font(_ weight: Weight, size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }

    /// خطّ ثابت لا يكبر مع حجم الخط، للأرقام داخل المربّعات حتى لا ينكسر صفّ الأرباع (§3).
    static func fixedFont(_ weight: Weight, size: CGFloat) -> Font {
        .custom(weight.rawValue, fixedSize: size)
    }

    // MARK: §1 · الألوان (نهاراً / ليلاً)

    /// الأرضية: ورقي دافئ نهاراً، كحلي ليلاً.
    static let background = dynamic(light: 0xF7F4EC, dark: 0x13283E)
    static var paper: Color { background }
    /// البطاقة.
    static let card = dynamic(light: 0xFFFDF8, dark: 0x1B3450)
    /// النصّ، وإطار موضع التوقّف.
    static let text = dynamic(light: 0x0F3F6E, dark: 0xF2EDE2)
    static var ink: Color { text }
    /// النصّ الهادئ.
    static let muted = dynamic(light: 0x5C6F86, dark: 0xA9B8C9)
    /// الحدود والفواصل.
    static let line = dynamic(light: 0x0F3F6E, dark: 0xF2EDE2, lightAlpha: 0.14, darkAlpha: 0.16)
    static let far = dynamic(light: 0x0F3F6E, dark: 0xD3DEEA)
    static let near = dynamic(light: 0x145DA0, dark: 0x6FA8E6)
    static let new = dynamic(light: 0xDF8C16, dark: 0xDF8C16)
    static let newInk = dynamic(light: 0x9A5800, dark: 0xDF8C16)
    static let onFar = dynamic(light: 0xFFFFFF, dark: 0x13283E)
    static let onNear = dynamic(light: 0xFFFFFF, dark: 0x13283E)
    static let onNew = dynamic(light: 0x13283E, dark: 0x13283E)
    /// ذهبي الزخرفة: زينة بلا معنى (§10).
    static let gilt = dynamic(light: 0xDF8C16, dark: 0xE39A33)
    static let ghost = dynamic(light: 0x0F3F6E, dark: 0xF2EDE2, lightAlpha: 0.09, darkAlpha: 0.10)
    static let scrim = dynamic(light: 0x0A1624, dark: 0x000000, lightAlpha: 0.42, darkAlpha: 0.50)

    /// لون المسار (شريطه وتعبئة مربّعاته).
    static func trackColor(_ track: Track) -> Color {
        switch track {
        case .farReview: far
        case .nearReview: near
        case .newMemorization: new
        }
    }

    /// لون رقم المربّع وحدّه في غير الممتلئ (§5).
    static func tileInk(_ track: Track) -> Color {
        switch track {
        case .farReview: far
        case .nearReview: near
        case .newMemorization: newInk
        }
    }

    // MARK: §4 · المسافات والزوايا

    enum Radius {
        static let tile: CGFloat = 11
        static let iconButton: CGFloat = 12
        static let button: CGFloat = 14
        static let sura: CGFloat = 18
        static let card: CGFloat = 22
        static let dialog: CGFloat = 24
        static let sheet: CGFloat = 28
    }

    enum Size {
        static let tile: CGFloat = 44
        static let touch: CGFloat = 44
        static let rowHeight: CGFloat = 52
        static let hizbLabelWidth: CGFloat = 48
        static let hizbLabelWidthNarrow: CGFloat = 44
    }

    private static func dynamic(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(UIColor {
            $0.userInterfaceStyle == .dark ? uiColor(dark, alpha: darkAlpha) : uiColor(light, alpha: lightAlpha)
        })
    }

    private static func uiColor(_ hex: UInt32, alpha: CGFloat) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
