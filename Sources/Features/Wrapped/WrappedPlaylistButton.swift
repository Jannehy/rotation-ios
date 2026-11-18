import SwiftUI

/// Puts the year's most played songs into Navidrome as a playlist, in order.
///
/// The same button belongs in two places – the last story card and the foot of
/// the recap – so it is one view used twice. What has been written is
/// remembered in the `Session`, not here, so both places agree.
///
/// Nothing is drawn where there is nothing to write: a friend's recap and the
/// demo both arrive without a playlist block.
struct WrappedPlaylistButton: View {
    let data: Wrapped
    /// The story card: white text, and without the explaining line or the
    /// second button, because that card is already full.
    var onDark = false

    @EnvironmentObject private var session: Session
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        if let info = data.playlist {
            content(for: info)
        }
    }

    @ViewBuilder
    private func content(for info: WrappedPlaylist) -> some View {
        // What this run has written outranks what the recap was fetched with.
        let written = session.wrappedPlaylists[info.year] ?? (info.exists ? info : nil)

        VStack(alignment: onDark ? .center : .leading, spacing: 6) {
            if let written, !busy {
                Text(String(format: String(localized: "%1$@ is in your playlists – %2$d tracks, in order."),
                            written.name, written.tracks))
                    .font(.footnote)
                    .multilineTextAlignment(onDark ? .center : .leading)
                    .foregroundStyle(muted)
                // Until the year is over the list still grows, so writing it
                // again has a point – but not on the story card.
                if !onDark {
                    Button(String(localized: "Write it again")) {
                        Task { await write(info) }
                    }
                    .font(.callout)
                    .tint(Palette.accent)
                }
            } else {
                if !onDark {
                    Text(String(format: String(localized: "The %1$d most played songs of %2$d, in that order, written into your library."),
                                info.size, info.year))
                        .font(.footnote)
                        .foregroundStyle(muted)
                }
                Button {
                    Task { await write(info) }
                } label: {
                    if busy {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        // Centred so that a label long enough to wrap does not
                        // sit left under its own first line.
                        Text(String(format: String(localized: "Save the top %d as a playlist"),
                                    info.size))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .disabled(busy)
            }
            if failed {
                Text(String(localized: "The playlist could not be created."))
                    .font(.footnote)
                    .multilineTextAlignment(onDark ? .center : .leading)
                    .foregroundStyle(onDark ? Color.white : Color.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: onDark ? .center : .leading)
    }

    private var muted: Color {
        onDark ? Color.white.opacity(0.75) : Color.secondary
    }

    private func write(_ info: WrappedPlaylist) async {
        // The source is unwrapped first: optional chaining inside `perform`
        // would hand back an optional inside an optional.
        guard !busy, let source = session.source else { return }
        busy = true
        failed = false
        defer { busy = false }
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let written = await session.perform {
            try await source.wrappedPlaylist(year: info.year, language: language)
        }
        if let written, written.ok {
            session.wrappedPlaylists[info.year] = written.playlist
        } else {
            failed = true
        }
    }
}
