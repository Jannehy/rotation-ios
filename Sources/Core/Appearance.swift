import SwiftUI
import UIKit

/// The colours Rotation can wear. Ready-made palettes rather than a free
/// colour picker: an accent has to carry text on it and stand apart from the
/// surface behind it, and a free choice loses that faster than it looks.
enum Accent: String, CaseIterable, Identifiable {
    case sunset, mint, violet, ocean, gold, rose

    var id: String { rawValue }

    /// The stored choice, read wherever a colour is needed.
    static var current: Accent {
        Accent(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .sunset
    }

    static let key = "rotation.accent"

    var accent: Color {
        switch self {
        case .sunset: return Color(hex: 0xFF5A3C)
        case .mint:   return Color(hex: 0x2AD4A4)
        case .violet: return Color(hex: 0xA06BFF)
        case .ocean:  return Color(hex: 0x3F9DFF)
        case .gold:   return Color(hex: 0xF0B429)
        case .rose:   return Color(hex: 0xFF5D8F)
        }
    }

    var second: Color {
        switch self {
        case .sunset: return Color(hex: 0x7C6CFF)
        case .mint:   return Color(hex: 0x4AA8FF)
        case .violet: return Color(hex: 0xFF6BD6)
        case .ocean:  return Color(hex: 0x22D3EE)
        case .gold:   return Color(hex: 0xFF7A45)
        case .rose:   return Color(hex: 0xFFA26B)
        }
    }

    var deep: Color {
        switch self {
        case .sunset: return Color(hex: 0xB3234A)
        case .mint:   return Color(hex: 0x0F766E)
        case .violet: return Color(hex: 0x6C2BD9)
        case .ocean:  return Color(hex: 0x1D4ED8)
        case .gold:   return Color(hex: 0xB45309)
        case .rose:   return Color(hex: 0xC2185B)
        }
    }

    /// The alternate app icon that matches – nil is the one in the bundle.
    var iconName: String? {
        self == .sunset ? nil : "AppIcon-" + rawValue.capitalized
    }

    /// Puts the colour on the home screen too. iOS only accepts this from
    /// the foreground, and it is the only place that shows an alert of its
    /// own, so a failure is simply left alone.
    static func applyIcon(_ accent: Accent) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let wanted = accent.iconName
        guard UIApplication.shared.alternateIconName != wanted else { return }
        UIApplication.shared.setAlternateIconName(wanted)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Rotation's colours, so the app looks like the web interface.
enum Palette {
    static var accent: Color { Accent.current.accent }
    static var accentAlt: Color { Accent.current.second }
    static var deep: Color { Accent.current.deep }

    /// A stable colour per name, so artwork-less entries still look deliberate.
    static func placeholder(for text: String) -> LinearGradient {
        var hash: UInt64 = 5381
        for byte in text.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        let hue = Double(hash % 360) / 360
        return LinearGradient(
            colors: [Color(hue: hue, saturation: 0.55, brightness: 0.55),
                     Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1),
                           saturation: 0.65, brightness: 0.32)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
