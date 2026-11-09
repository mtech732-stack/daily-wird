import SwiftUI
import UIKit

/// ألوان وخطّ مبدئية من الوثيقة (8.2، 8.3) إلى أن يسلّم المصمّم نظام التصميم.
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

    /// الأرضية: ورقي دافئ نهاراً، كحلي ليلاً.
    static let background = dynamic(light: 0xF7F4EC, dark: 0x13283E)
    /// النصّ: كحلي داكن نهاراً، فاتح ليلاً.
    static let text = dynamic(light: 0x0F3F6E, dark: 0xF2EDE2)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light) })
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
