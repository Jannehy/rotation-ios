import SwiftUI
import UIKit

struct WrappedView: View {
    @EnvironmentObject private var session: Session
    @State private var data: Wrapped?
    @State private var year: Int?
    @State private var selectedMonth: Int?
    @State private var rendered: Image?
    @State private var cardImage: UIImage?
    @State private var isSharing = false
    @State private var detail: DetailTarget?
    @State private var cover: UIImage?
    @State private var storyOpen = false
    @AppStorage("rotation.cardtheme") private var themeName = CardTheme.sunset.rawValue
    @AppStorage("season.always") private var seasonAlways = false

    private var theme: CardTheme { CardTheme(rawValue: themeName) ?? .sunset }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let data, data.hasData {
                        header(data)
                        // The page is here all year; only the story steps
                        // forward in December – or whenever it is asked to.
                        if session.me?.season?.open == true || seasonAlways {
                            Button {
                                storyOpen = true
                            } label: {
                                Label(String(localized: "Watch as a story"),
                                      systemImage: "play.fill")
                                    .font(.headline)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Palette.accent)
                        }
                        hero(data)
                        if let artist = data.artists.first { artistOfTheYear(data, artist) }
                        topLists(data)
                        months(data)
                        facts(data)
                        shareSection(data)
                    } else if data != nil {
                        Text("No data for this year.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Wrapped")
            .sheet(item: $detail) { target in
                DetailSheet(target: target).environmentObject(session)
            }
            .fullScreenCover(isPresented: $storyOpen) {
                if let data {
                    StoryView(data: data).environmentObject(session)
                }
            }
        }
        .task(id: "\(year ?? 0)-\(session.viewing?.id ?? "me")") { await load() }
    }

    // MARK: - Pieces

    private func header(_ data: Wrapped) -> some View {
        HStack {
            if data.years.count > 1 {
                Picker("Year", selection: Binding(
                    get: { data.year },
                    set: { year = $0 }
                )) {
                    ForEach(data.years, id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Palette.accent)
            } else {
                Text(String(data.year)).font(.headline)
            }
            Spacer()
        }
    }

    /// The card, the palette choice and the button – one block at the end.
    private func shareSection(_ data: Wrapped) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "To share").uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            shareCard

            HStack(spacing: 12) {
                ForEach(CardTheme.allCases) { option in
                    Button {
                        themeName = option.rawValue
                        rendered = nil
                        render(data)
                    } label: {
                        Circle()
                            .fill(option.swatch)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .strokeBorder(theme == option ? Color.primary : .clear,
                                                  lineWidth: 2)
                                    .padding(-4)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                }
                Spacer()
                if cardImage != nil {
                    Button {
                        isSharing = true
                    } label: {
                        Label("Share image", systemImage: "square.and.arrow.up")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Palette.accent)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sheet(isPresented: $isSharing) {
            if let cardImage {
                ActivityView(items: [cardImage])
            }
        }
    }

    /// The rendered image itself, so what is on screen and what gets shared
    /// are literally the same picture.
    private var shareCard: some View {
        Group {
            if let rendered {
                rendered
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .aspectRatio(1080.0 / 1920.0, contentMode: .fit)
                    .overlay(ProgressView())
            }
        }
    }

    private func hero(_ data: Wrapped) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "%d plays"), data.summary.plays))
                .font(.system(size: 42, weight: .heavy, design: .rounded))
            Text("\(Format.duration(data.summary.seconds)) · "
                 + String(format: String(localized: "%d artists"), data.summary.artists))
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            if let previous = data.previous {
                let delta = Int(((Double(data.summary.plays) - Double(previous.plays))
                                 / Double(previous.plays) * 100).rounded())
                Text("\(delta >= 0 ? "+" : "")\(delta)% "
                     + String(format: String(localized: "compared with %d"), previous.year))
                    .font(.footnote).foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            LinearGradient(colors: [Palette.accent, Palette.deep, Palette.accentAlt],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func artistOfTheYear(_ data: Wrapped, _ artist: ArtistEntry) -> some View {
        Card(String(localized: "Your artist of the year")) {
            Button { detail = .artist(artist.id, String(data.year)) } label: {
                HStack(spacing: 14) {
                    Artwork(art: artist.art, name: artist.name, size: 72, rounded: true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(artist.name).font(.title3.weight(.bold)).lineLimit(2)
                        Text(String(format: String(localized: "%d plays"), artist.plays))
                            .font(.footnote).foregroundStyle(.secondary)
                        Text(String(format: String(localized: "%d%% of everything you played"),
                                    data.devotion))
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// The five names behind the card, each one a door.
    private func topLists(_ data: Wrapped) -> some View {
        VStack(spacing: 14) {
            if !data.tracks.isEmpty {
                Card(String(localized: "Top tracks")) {
                    VStack(spacing: 10) {
                        ForEach(Array(data.tracks.prefix(5).enumerated()), id: \.offset) { index, track in
                            Button { detail = .track(track.id, String(data.year)) } label: {
                                TopRow(rank: index + 1, title: track.title,
                                       subtitle: track.artist, art: track.art,
                                       plays: track.plays,
                                       share: Double(track.plays)
                                           / Double(max(data.tracks.first?.plays ?? 1, 1)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if !data.albums.isEmpty {
                Card(String(localized: "Top albums")) {
                    VStack(spacing: 10) {
                        ForEach(Array(data.albums.prefix(5).enumerated()), id: \.offset) { index, album in
                            Button { detail = .album(album.id, String(data.year)) } label: {
                                TopRow(rank: index + 1, title: album.name,
                                       subtitle: album.artist ?? "", art: album.art,
                                       plays: album.plays,
                                       share: Double(album.plays)
                                           / Double(max(data.albums.first?.plays ?? 1, 1)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func months(_ data: Wrapped) -> some View {
        Card(String(localized: "Across the year")) {
            VStack(alignment: .leading, spacing: 8) {
                MonthBars(months: data.months, selected: $selectedMonth)
                Text(monthCaption(data))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(height: 16)
            }
        }
    }

    private func monthCaption(_ data: Wrapped) -> String {
        let month = selectedMonth ?? data.topMonth?.month
        guard let month, data.months.indices.contains(month - 1) else { return "" }
        let entry = data.months[month - 1]
        let name = Format.months.indices.contains(month - 1) ? Format.months[month - 1] : ""
        return "\(name) · " + String(format: String(localized: "%d plays"), entry.plays)
    }

    private func facts(_ data: Wrapped) -> some View {
        Card(String(localized: "Your year")) {
            VStack(alignment: .leading, spacing: 12) {
                if let first = data.firstPlay {
                    fact(String(localized: "It started with"), "\(first.title) — \(first.artist)")
                }
                fact(String(localized: "Longest streak"),
                     String(format: String(localized: "%d days"), data.streak))
                if let hour = data.clock.peakHour {
                    fact(String(localized: "Your hour"), Format.hour(hour))
                }
                if !data.discoveries.isEmpty {
                    fact(String(localized: "New to you"),
                         data.discoveries.prefix(3).map(\.name).joined(separator: ", "))
                }
            }
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline)
        }
    }

    // MARK: - Loading

    private func load() async {
        guard let source = session.source else { return }
        data = await session.perform {
            try await source.wrapped(year: year, user: session.viewing?.id)
        }
        selectedMonth = nil
        rendered = nil
        cardImage = nil
        cover = nil
        guard let data, data.hasData else { return }
        cover = await artwork(for: data)
        render(data)
    }

    /// The cover has to be a finished image before the card is drawn –
    /// anything still loading would simply be missing from the result.
    private func artwork(for data: Wrapped) async -> UIImage? {
        guard let art = data.artists.first?.art,
              let url = session.source?.artworkURL(art, size: 600),
              let (bytes, _) = try? await URLSession.shared.data(from: url)
        else { return nil }
        return UIImage(data: bytes)
    }

    /// Rendering happens once per year and palette, not on every redraw.
    @MainActor
    private func render(_ data: Wrapped) {
        let image = RotationCard.render(
            data: data,
            name: data.user?.name ?? session.me?.user.name ?? "",
            cover: cover, theme: theme)
        rendered = Image(uiImage: image)
        cardImage = image
    }
}
