import SwiftUI

/// Cover art from the server, or a coloured stand-in when there is none –
/// which is always the case in the demo.
struct Artwork: View {
    let art: String?
    let name: String
    var size: CGFloat = 44
    var rounded: Bool = false

    @EnvironmentObject private var session: Session

    var body: some View {
        Group {
            if let url = session.source?.artworkURL(art, size: Int(size * 3)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: rounded ? size / 2 : size * 0.18,
                                    style: .continuous))
    }

    private var placeholder: some View {
        Palette.placeholder(for: name)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            )
    }
}
