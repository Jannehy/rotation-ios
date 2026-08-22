import SwiftUI
import UIKit

/// The palettes the card can be drawn in – the same four the web interface
/// and the Android client offer.
enum CardTheme: String, CaseIterable, Identifiable {
    case sunset, mint, night, coal

    var id: String { rawValue }

    var stops: [UIColor] {
        switch self {
        case .sunset: return [UIColor(hex: 0xFF5A3C), UIColor(hex: 0xB3234A), UIColor(hex: 0x7C6CFF)]
        case .mint:   return [UIColor(hex: 0x2AD4A4), UIColor(hex: 0x0F766E), UIColor(hex: 0x123A4F)]
        case .night:  return [UIColor(hex: 0x4353D6), UIColor(hex: 0x6C2BD9), UIColor(hex: 0x140F2E)]
        case .coal:   return [UIColor(hex: 0x4A4A58), UIColor(hex: 0x23232E), UIColor(hex: 0x0A0A0F)]
        }
    }

    var label: UIColor {
        switch self {
        case .sunset, .coal: return UIColor(hex: 0xFF5A3C)
        case .mint: return UIColor(hex: 0x2AD4A4)
        case .night: return UIColor(hex: 0x8F9BFF)
        }
    }

    var ink: UIColor {
        switch self {
        case .mint: return UIColor(hex: 0xEAF6F2)
        case .night: return UIColor(hex: 0xE8E9F6)
        default: return UIColor(hex: 0xECEAF2)
        }
    }

    var title: String {
        switch self {
        case .sunset: return NSLocalizedString("Sunset", comment: "")
        case .mint: return NSLocalizedString("Mint", comment: "")
        case .night: return NSLocalizedString("Midnight", comment: "")
        case .coal: return NSLocalizedString("Coal", comment: "")
        }
    }

    var swatch: LinearGradient {
        LinearGradient(colors: stops.map(Color.init(uiColor:)),
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

/// Draws the share card.
///
/// Deliberately drawn rather than laid out: the web interface and the Android
/// client paint the same picture at the same coordinates, and a card made on
/// one of them should be indistinguishable from a card made on another.
enum RotationCard {

    static let size = CGSize(width: 1080, height: 1920)

    static func render(data: Wrapped, name: String, cover: UIImage?,
                       theme: CardTheme) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size, format: {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            format.opaque = true
            return format
        }())

        return renderer.image { context in
            let ctx = context.cgContext
            let width = size.width, height = size.height

            UIColor(hex: 0x0A0A0F).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // The band at the top, with the year written across it as a pattern.
            let band: CGFloat = 880
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 0, width: width, height: band))
            let colours = theme.stops.map(\.cgColor) as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colours, locations: [0, 0.55, 1]) {
                ctx.drawLinearGradient(gradient, start: .zero,
                                       end: CGPoint(x: width, y: band), options: [])
            }
            ctx.saveGState()
            ctx.rotate(by: -0.18)
            // Three repeats per line, every other line shifted by half a
            // repeat: San Francisco sets digits narrower than the web font,
            // so a single "2026 2026" would leave the tail of the pattern off
            // the edge and show nothing but twos and zeros.
            for row in -1...4 {
                draw("\(data.year) \(data.year) \(data.year)",
                     baseline: CGPoint(x: -220, y: 150 + CGFloat(row) * 235),
                     font: .systemFont(ofSize: 235, weight: .black),
                     colour: UIColor(white: 1, alpha: 0.13))
            }
            ctx.restoreGState()
            ctx.restoreGState()

            // The artist of the year, as artwork.
            let coverSize: CGFloat = 430
            let coverRect = CGRect(x: (width - coverSize) / 2, y: 210,
                                   width: coverSize, height: coverSize)
            let rounded = UIBezierPath(roundedRect: coverRect, cornerRadius: 18)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 16), blur: 40,
                          color: UIColor(white: 0, alpha: 0.45).cgColor)
            UIColor(hex: 0x14141D).setFill()
            rounded.fill()
            ctx.restoreGState()

            if let cover {
                ctx.saveGState()
                rounded.addClip()
                cover.draw(in: coverRect)
                ctx.restoreGState()
            } else {
                let initial = String((data.artists.first?.name ?? name).prefix(1)).uppercased()
                draw(initial,
                     baseline: CGPoint(x: coverRect.midX, y: coverRect.midY + 62),
                     font: .systemFont(ofSize: 180, weight: .semibold),
                     colour: UIColor(white: 1, alpha: 0.85), align: .centre)
            }

            draw(String(localized: "YOUR YEAR \(String(data.year))").uppercased(),
                 baseline: CGPoint(x: width / 2, y: 130),
                 font: .systemFont(ofSize: 34, weight: .semibold),
                 colour: UIColor(white: 1, alpha: 0.85), align: .centre)
            draw(name, baseline: CGPoint(x: width / 2, y: 780),
                 font: .systemFont(ofSize: 62, weight: .heavy),
                 colour: .white, align: .centre, maxWidth: width - 200)

            // Two columns, the way everybody reads this kind of card.
            func column(_ title: String, _ items: [String],
                        x: CGFloat, top: CGFloat, columnWidth: CGFloat) {
                draw(title.uppercased(), baseline: CGPoint(x: x, y: top),
                     font: .systemFont(ofSize: 30, weight: .semibold), colour: theme.label)
                for (index, item) in items.prefix(5).enumerated() {
                    let line = top + 76 + CGFloat(index) * 74
                    draw("\(index + 1).", baseline: CGPoint(x: x, y: line),
                         font: .systemFont(ofSize: 40, weight: .semibold),
                         colour: theme.ink.withAlphaComponent(0.5))
                    draw(item, baseline: CGPoint(x: x + 62, y: line),
                         font: .systemFont(ofSize: 40, weight: .semibold),
                         colour: theme.ink, maxWidth: columnWidth - 70)
                }
            }
            column(String(localized: "Top artists"), data.artists.map(\.name),
                   x: 84, top: 1010, columnWidth: 420)
            column(String(localized: "Top tracks"), data.tracks.map(\.title),
                   x: 570, top: 1010, columnWidth: 440)

            // Four facts at the bottom, the mirror image of the columns.
            func fact(_ title: String, _ value: String,
                      x: CGFloat, top: CGFloat, boxWidth: CGFloat, size: CGFloat) {
                draw(title.uppercased(), baseline: CGPoint(x: x, y: top),
                     font: .systemFont(ofSize: 30, weight: .semibold), colour: theme.label)
                draw(value, baseline: CGPoint(x: x, y: top + size + 14),
                     font: .systemFont(ofSize: size, weight: .heavy),
                     colour: theme.ink, maxWidth: boxWidth)
            }
            let minutes = Int((Double(data.summary.seconds) / 60).rounded())
            fact(String(localized: "Minutes listened"), Format.number(minutes),
                 x: 84, top: 1480, boxWidth: 420, size: 76)
            fact(String(localized: "Top genre"), data.genres.first?.name ?? "—",
                 x: 570, top: 1480, boxWidth: 440, size: 62)
            fact(String(localized: "Artists"), Format.number(data.summary.artists),
                 x: 84, top: 1650, boxWidth: 420, size: 62)
            fact(String(localized: "Tracks"), Format.number(data.summary.tracks),
                 x: 570, top: 1650, boxWidth: 440, size: 62)

            draw("Rotation · Navidrome", baseline: CGPoint(x: 84, y: height - 70),
                 font: .systemFont(ofSize: 30, weight: .semibold),
                 colour: theme.ink.withAlphaComponent(0.55))
        }
    }

    private enum Align { case leading, centre }

    /// Draws one line on its baseline, the way a canvas does – UIKit measures
    /// from the top of the line, which is what shifted the text before.
    private static func draw(_ text: String, baseline: CGPoint, font: UIFont,
                             colour: UIColor, align: Align = .leading,
                             maxWidth: CGFloat? = nil) {
        var value = text
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colour]
        if let maxWidth {
            while value.count > 1,
                  (value as NSString).size(withAttributes: attributes).width > maxWidth {
                value = String(value.dropLast())
            }
            if value != text, value.count > 1 {
                value = String(value.dropLast()) + "…"
            }
        }
        let measured = (value as NSString).size(withAttributes: attributes)
        let x = align == .centre ? baseline.x - measured.width / 2 : baseline.x
        (value as NSString).draw(at: CGPoint(x: x, y: baseline.y - font.ascender),
                                 withAttributes: attributes)
    }
}
