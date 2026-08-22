import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var session: Session
    @State private var period: Period = .month
    @State private var data: Overview?
    @State private var isLoading = false
    @State private var detail: DetailTarget?
    @State private var storyYear: Wrapped?
    @State private var playlists: [ManagedPlaylist] = []
    @State private var writing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Once a year the recap announces itself here, the way the
                    // one everybody knows does. The setting in Options is
                    // about the recap page, not about this.
                    if let season = session.me?.season, season.open {
                        SeasonBanner(year: season.year) { await openStory(season.year) }
                    }
                    PeriodPicker(period: $period)

                    if let data {
                        tiles(data)

                        Card(String(localized: "Over time")) {
                            TimelineChart(days: data.timeline)
                        }
                        Card(String(localized: "Time of day")) {
                            RecordClock(clock: data.clock)
                        }
                        Card(String(localized: "Top artists")) {
                            VStack(spacing: 10) {
                                ForEach(Array(data.artists.prefix(10).enumerated()),
                                        id: \.offset) { index, artist in
                                    Button { detail = .artist(artist.id, period.rawValue) } label: {
                                        TopRow(rank: index + 1, title: artist.name,
                                               subtitle: String(format: String(localized: "%d tracks"),
                                                                artist.tracks),
                                               art: artist.art, plays: artist.plays,
                                               share: share(artist.plays, data.artists.first?.plays),
                                               rounded: true)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        Card(String(localized: "Top tracks"), action: playlistAction) {
                            VStack(spacing: 10) {
                                ForEach(Array(data.tracks.prefix(10).enumerated()),
                                        id: \.offset) { index, track in
                                    Button { detail = .track(track.id, period.rawValue) } label: {
                                        TopRow(rank: index + 1, title: track.title,
                                               subtitle: track.artist, art: track.art,
                                               plays: track.plays,
                                               share: share(track.plays, data.tracks.first?.plays))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        Card(String(localized: "Top albums")) {
                            VStack(spacing: 10) {
                                ForEach(Array(data.albums.prefix(10).enumerated()),
                                        id: \.offset) { index, album in
                                    Button { detail = .album(album.id, period.rawValue) } label: {
                                        TopRow(rank: index + 1, title: album.name,
                                               subtitle: album.artist ?? "", art: album.art,
                                               plays: album.plays,
                                               share: share(album.plays, data.albums.first?.plays))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if !data.genres.isEmpty {
                            Card(String(localized: "Genres")) { genres(data.genres) }
                        }
                        if !data.discoveries.isEmpty {
                            Card(String(localized: "Newly discovered")) {
                                discoveries(data.discoveries)
                            }
                        }
                    } else if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else {
                        Text("Nothing here for this period yet.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(session.viewing?.name ?? String(localized: "Overview"))
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await load() }
            .task(id: period) { await loadPlaylists() }
            .alert(session.notice ?? "", isPresented: Binding(
                get: { session.notice != nil },
                set: { if !$0 { session.notice = nil } })) {
                Button("OK", role: .cancel) { }
            }
            .sheet(item: $detail) { target in
                DetailSheet(target: target).environmentObject(session)
            }
            // Presented by the recap itself, not by a second flag: with two
            // pieces of state the cover could come up in the moment between
            // them and show an empty screen.
            .fullScreenCover(item: $storyYear) { recap in
                StoryView(data: recap).environmentObject(session)
            }
        }
        .task(id: "\(period.rawValue)-\(session.viewing?.id ?? "me")") { await load() }
    }

    private func tiles(_ data: Overview) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(value: Format.number(data.summary.plays),
                     label: String(localized: "Plays"), accent: true)
            StatTile(value: Format.duration(data.summary.seconds),
                     label: String(localized: "Listening time"))
            StatTile(value: Format.number(data.summary.artists),
                     label: String(localized: "Artists"))
            StatTile(value: Format.number(data.summary.tracks),
                     label: String(localized: "Tracks"))
            StatTile(value: Format.number(data.summary.activeDays),
                     label: String(localized: "Active days"))
            StatTile(value: "\(data.streaks.current)",
                     label: String(localized: "Streak · days"))
        }
    }

    private func genres(_ genres: [GenreEntry]) -> some View {
        VStack(spacing: 8) {
            ForEach(genres) { genre in
                HStack(spacing: 10) {
                    Text(genre.name).font(.footnote).lineLimit(1)
                        .frame(width: 96, alignment: .leading)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15))
                            Capsule().fill(Palette.accent)
                                .frame(width: max(3, geometry.size.width
                                                  * share(genre.plays, genres.first?.plays)))
                        }
                    }
                    .frame(height: 8)
                    Text(Format.number(genre.plays))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    private func discoveries(_ items: [Discovery]) -> some View {
        FlowLayout(spacing: 7) {
            ForEach(items) { item in
                Button { detail = .artist(item.id, period.rawValue) } label: {
                    HStack(spacing: 5) {
                        Text(item.name).font(.footnote)
                        Text("\(item.plays)")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func share(_ value: Int, _ top: Int?) -> Double {
        guard let top, top > 0 else { return 0 }
        return Double(value) / Double(top)
    }

    /// The banner fetches its own year before the story opens, so the first
    /// card is never an empty screen.
    private func openStory(_ year: Int) async {
        guard let source = session.source else { return }
        storyYear = await session.perform {
            try await source.wrapped(year: year, user: nil)
        }
    }

    /// The button over the top tracks: it says what it will do, and offers a
    /// way out once Rotation is looking after a list.
    private var playlistAction: CardAction? {
        guard !session.isDemo, session.viewing == nil else { return nil }
        let existing = playlists.first { $0.range == period.rawValue }
        return CardAction(
            title: existing == nil
                ? String(localized: "Create a playlist")
                : String(localized: "Refresh the playlist"),
            busy: writing,
            secondary: existing == nil ? nil : String(localized: "stop maintaining"),
            run: { await writePlaylist() },
            runSecondary: { await dropPlaylist() })
    }

    private func writePlaylist() async {
        // The source is unwrapped first: optional chaining inside `perform`
        // would hand back an optional inside an optional.
        guard let source = session.source else { return }
        writing = true
        defer { writing = false }
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let written = await session.perform {
            try await source.writePlaylist(range: period.rawValue, language: language)
        }
        if let written {
            session.notice = String(format: String(localized: "%1$@ is in Navidrome – %2$d tracks, refreshed daily."),
                                    written.playlist.name, written.tracks)
        }
        await loadPlaylists()
    }

    private func dropPlaylist() async {
        guard let source = session.source else { return }
        _ = await session.perform {
            try await source.dropPlaylist(range: period.rawValue)
        }
        session.notice = String(localized: "No longer refreshed. The playlist stays in Navidrome.")
        await loadPlaylists()
    }

    private func loadPlaylists() async {
        guard !session.isDemo, session.viewing == nil,
              let source = session.source else { playlists = []; return }
        playlists = (try? await source.playlists()) ?? []
    }

    private func load() async {
        guard let source = session.source else { return }
        isLoading = data == nil
        data = await session.perform {
            try await source.overview(period: period, user: session.viewing?.id)
        }
        isLoading = false
    }
}

/// Chips that wrap onto the next line – SwiftUI has no such stack of its own.
/// The card that brings the recap forward once a year.
struct SeasonBanner: View {
    let year: Int
    let open: () async -> Void
    @State private var loading = false

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: String(localized: "Your %d recap is here"), year))
                    .font(.system(size: 21, weight: .black))
                Text("Twelve months of music, told in two minutes.")
                    .font(.footnote).opacity(0.85)
            }
            Spacer(minLength: 0)
            Button {
                loading = true
                Task { await open(); loading = false }
            } label: {
                if loading { ProgressView().tint(.black) }
                else { Label(String(localized: "Watch"), systemImage: "play.fill") }
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(
            LinearGradient(colors: [Palette.accent, Palette.deep, Palette.accentAlt],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
