import SwiftUI

/// What to look at: a track, an artist or an album – and over which period.
///
/// The period travels with the target so the numbers here match the list the
/// name was tapped in. The recap page passes its year, everything else the
/// period its picker is set to.
struct DetailTarget: Hashable, Identifiable {
    let kind: String
    let key: String
    let range: String

    var id: String { "\(kind)-\(range)-\(key)" }

    static func track(_ id: String, _ range: String) -> DetailTarget {
        .init(kind: "track", key: id, range: range)
    }
    static func artist(_ id: String, _ range: String) -> DetailTarget {
        .init(kind: "artist", key: id, range: range)
    }
    static func album(_ id: String, _ range: String) -> DetailTarget {
        .init(kind: "album", key: id, range: range)
    }
}

/// The sheet every name in a list opens. Inside it, names keep working, so
/// an artist leads to a track and a track back to its album.
struct DetailSheet: View {
    let target: DetailTarget
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DetailBody(target: target)
                .navigationDestination(for: DetailTarget.self) { DetailBody(target: $0) }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Done")) { dismiss() }
                    }
                }
        }
    }
}

struct DetailBody: View {
    let target: DetailTarget
    @EnvironmentObject private var session: Session
    @State private var data: ItemDetail?
    @State private var missing = false
    @StateObject private var preview = TrackPreview()

    var body: some View {
        ScrollView {
            if let data {
                VStack(alignment: .leading, spacing: 18) {
                    header(data)
                    tiles(data)
                    if data.months.count >= 1 { months(data) }
                    if data.hours.contains(where: { $0 > 0 }) { hours(data) }
                    if let tracks = data.topTracks, !tracks.isEmpty {
                        section(String(localized: "Top tracks")) {
                            ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                                NavigationLink(value: DetailTarget.track(track.id, target.range)) {
                                    TopRow(rank: index + 1, title: track.title,
                                           subtitle: track.artist, art: track.art,
                                           plays: track.plays,
                                           share: share(track.plays, tracks.first?.plays))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if let albums = data.topAlbums, !albums.isEmpty {
                        section(String(localized: "Top albums")) {
                            ForEach(Array(albums.enumerated()), id: \.offset) { index, album in
                                NavigationLink(value: DetailTarget.album(album.id, target.range)) {
                                    TopRow(rank: index + 1, title: album.name,
                                           subtitle: album.artist ?? "", art: album.art,
                                           plays: album.plays,
                                           share: share(album.plays, albums.first?.plays))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            } else if missing {
                Text("There is no data for that.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.top, 40)
            } else {
                ProgressView().padding(.top, 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(data?.displayName ?? "")
        .task(id: target.id) { await load() }
        .onDisappear { preview.stop() }
    }

    // MARK: - Pieces

    private func header(_ data: ItemDetail) -> some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Artwork(art: data.art, name: data.displayName, size: 84,
                        rounded: data.kind == "artist")
                // A song can be listened to, not only counted. The badge is
                // always there: on a touch screen nothing reveals itself.
                if data.kind == "track" {
                    Image(systemName: preview.isPlaying(data.id) ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 28, height: 28)
                        .background(Palette.accent, in: Circle())
                        .offset(x: 5, y: 5)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard data.kind == "track" else { return }
                preview.toggle(data.id, source: session.source)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(data.displayName).font(.title3.weight(.bold)).lineLimit(2)
                if !data.subtitle.isEmpty {
                    Text(data.subtitle).font(.footnote).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if data.kind == "artist", let tracks = data.tracks, let albums = data.albums {
                    Text("\(String(format: String(localized: "%d tracks"), tracks)) · "
                         + String(format: String(localized: "%d albums"), albums))
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if let range = data.range {
                        Text(Self.periodName(range.key))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    if data.rank > 0 {
                        Text("\(String(localized: "No.")) \(data.rank)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Palette.accent, in: Capsule())
                            .foregroundStyle(.black)
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }

    private func tiles(_ data: ItemDetail) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(value: Format.number(data.plays),
                     label: String(localized: "Plays"), accent: true)
            StatTile(value: Format.duration(data.seconds),
                     label: String(localized: "Listening time"))
            if data.firstPlay > 0 {
                StatTile(value: Date(timeIntervalSince1970: TimeInterval(data.firstPlay))
                            .formatted(date: .abbreviated, time: .omitted),
                         label: String(localized: "First heard"))
                StatTile(value: Format.ago(data.lastPlay), label: String(localized: "Last"))
            }
            if data.kind == "album", let total = data.trackTotal, total > 0 {
                StatTile(value: "\(data.tracks ?? 0)/\(total)",
                         label: String(localized: "Tracks heard"))
            }
        }
    }

    /// The months, padded out to a year – two plays in two months would draw
    /// two slabs otherwise.
    private func months(_ data: ItemDetail) -> some View {
        let series = Self.padded(data.months, to: 12)
        let peak = max(series.map(\.plays).max() ?? 1, 1)
        return section(String(localized: "Over the months") + " · "
                       + Period.all.label) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(series) { point in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Palette.accent.opacity(point.plays > 0 ? 0.85 : 0.2))
                        .frame(height: max(3, 70 * CGFloat(point.plays) / CGFloat(peak)))
                        .frame(maxWidth: 26)
                }
            }
            .frame(height: 70, alignment: .bottom)
            HStack {
                Text(series.first?.month ?? "")
                Spacer()
                Text(series.last?.month ?? "")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.tertiary)
        }
    }

    private func hours(_ data: ItemDetail) -> some View {
        let peak = max(data.hours.max() ?? 1, 1)
        return section(String(localized: "Time of day") + " · "
                       + Period.all.label) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(data.hours.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Palette.accentAlt.opacity(value > 0 ? 0.85 : 0.25))
                        .frame(height: max(2, 46 * CGFloat(value) / CGFloat(peak)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 46, alignment: .bottom)
            HStack {
                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    Text("\(hour)").frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.tertiary)
        }
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func share(_ value: Int, _ top: Int?) -> Double {
        guard let top, top > 0 else { return 0 }
        return Double(value) / Double(top)
    }

    private func load() async {
        guard let source = session.source else { return }
        data = await session.perform {
            try await source.detail(kind: target.kind, id: target.key,
                                    range: target.range,
                                    user: session.viewing?.id)
        }
        missing = data == nil
    }

    static func periodName(_ key: String) -> String {
        Period(rawValue: key)?.label ?? key
    }

    /// Fills the gaps between first and last month, then keeps extending
    /// backwards until the chart has enough columns to look like one.
    static func padded(_ months: [MonthPoint], to minimum: Int) -> [MonthPoint] {
        guard let first = months.first, let last = months.last else { return [] }
        let counts = Dictionary(uniqueKeysWithValues: months.map { ($0.month, $0.plays) })
        func parts(_ key: String) -> (year: Int, month: Int) {
            let pieces = key.split(separator: "-").map { Int($0) ?? 0 }
            return (pieces.first ?? 0, pieces.count > 1 ? pieces[1] : 1)
        }
        func key(_ year: Int, _ month: Int) -> String {
            String(format: "%04d-%02d", year, month)
        }
        var filled: [MonthPoint] = []
        var (year, month) = parts(first.month)
        let end = parts(last.month)
        while year < end.year || (year == end.year && month <= end.month) {
            let name = key(year, month)
            filled.append(MonthPoint(month: name, plays: counts[name] ?? 0))
            month += 1
            if month > 12 { month = 1; year += 1 }
        }
        var (headYear, headMonth) = parts(first.month)
        while filled.count < minimum {
            headMonth -= 1
            if headMonth < 1 { headMonth = 12; headYear -= 1 }
            filled.insert(MonthPoint(month: key(headYear, headMonth), plays: 0), at: 0)
        }
        return filled
    }
}
