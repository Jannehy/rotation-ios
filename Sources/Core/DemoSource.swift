import Foundation

/// The demo: an invented library and a year of invented plays, aggregated on
/// the device with the same rules the server uses.
///
/// Plays are stored as offsets from today, so the demo is always "the last
/// few weeks" no matter when the app is opened.
final class DemoSource: DataSource {
    var isDemo: Bool { true }

    struct Library: Decodable {
        struct Artist: Decodable { let id: String; let name: String }
        struct Album: Decodable { let id: String; let name: String; let artist: String }
        struct Track: Decodable {
            let id: String, title: String, artist: String, album: String, genre: String
            let seconds: Int
        }
        struct Friend: Decodable {
            let id: String, name: String
            let plays: Int, seconds: Int
            let artists: [String]
        }
        let user: Person
        let artists: [Artist]
        let albums: [Album]
        let tracks: [Track]
        let plays: [[Int]]
        let friends: [Friend]
    }

    private struct Play {
        let timestamp: Int
        let track: Library.Track
    }

    private let library: Library
    private let calendar = Calendar.current
    private let events: [Play]
    private let artistsByID: [String: Library.Artist]
    private let albumsByID: [String: Library.Album]

    init?() {
        guard let url = Bundle.main.url(forResource: "demo", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let library = try? JSONDecoder().decode(Library.self, from: data)
        else { return nil }
        self.library = library
        artistsByID = Dictionary(uniqueKeysWithValues: library.artists.map { ($0.id, $0) })
        albumsByID = Dictionary(uniqueKeysWithValues: library.albums.map { ($0.id, $0) })

        let midnight = Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
        events = library.plays.compactMap { entry in
            guard entry.count == 3, entry[2] < library.tracks.count else { return nil }
            return Play(timestamp: midnight + entry[0] * 86_400 + entry[1],
                        track: library.tracks[entry[2]])
        }
    }

    // MARK: - Time

    private func bounds(_ period: Period) -> (start: Int, end: Int, days: Int) {
        let end = Int(calendar.startOfDay(for: Date()).timeIntervalSince1970) + 86_400
        switch period {
        case .week:    return (end - 7 * 86_400, end, 7)
        case .month:   return (end - 30 * 86_400, end, 30)
        case .quarter: return (end - 90 * 86_400, end, 90)
        case .year:
            let start = startOfYear(currentYear)
            return (start, end, max(1, (end - start) / 86_400))
        case .all:
            let start = events.first?.timestamp ?? end
            return (start, end, max(1, (end - start) / 86_400))
        }
    }

    private var currentYear: Int { calendar.component(.year, from: Date()) }

    private func startOfYear(_ year: Int) -> Int {
        var parts = DateComponents()
        parts.year = year
        parts.month = 1
        parts.day = 1
        return Int((calendar.date(from: parts) ?? Date()).timeIntervalSince1970)
    }

    /// The window behind a range key: one of the periods the picker offers,
    /// or a plain year, which is what the recap page asks detail pages for.
    private func window(_ key: String) -> (start: Int, end: Int, label: String) {
        if let period = Period(rawValue: key) {
            let span = bounds(period)
            return (span.start, span.end, period.label)
        }
        if let year = Int(key), year > 1900 {
            let today = Int(calendar.startOfDay(for: Date()).timeIntervalSince1970)
            return (startOfYear(year), min(startOfYear(year + 1), today + 86_400),
                    String(year))
        }
        let span = bounds(.month)
        return (span.start, span.end, Period.month.label)
    }

    private func slice(_ start: Int, _ end: Int) -> [Play] {
        events.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    private func dayKey(_ timestamp: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    // MARK: - Aggregation

    private func summary(_ plays: [Play]) -> Summary {
        let days = Set(plays.map { dayKey($0.timestamp) })
        return Summary(
            plays: plays.count,
            seconds: plays.reduce(0) { $0 + $1.track.seconds },
            tracks: Set(plays.map { $0.track.id }).count,
            artists: Set(plays.map { $0.track.artist }).count,
            albums: Set(plays.map { $0.track.album }).count,
            activeDays: days.count)
    }

    private func topTracks(_ plays: [Play], limit: Int) -> [TrackEntry] {
        group(plays, by: { $0.track.id }, limit: limit) { key, group in
            let track = group[0].track
            return TrackEntry(
                id: key, title: track.title,
                artist: artistsByID[track.artist]?.name ?? "",
                album: albumsByID[track.album]?.name, art: nil,
                plays: group.count, seconds: group.count * track.seconds)
        }
    }

    private func topArtists(_ plays: [Play], limit: Int) -> [ArtistEntry] {
        group(plays, by: { $0.track.artist }, limit: limit) { key, group in
            ArtistEntry(
                id: key, name: artistsByID[key]?.name ?? key,
                plays: group.count,
                seconds: group.reduce(0) { $0 + $1.track.seconds },
                tracks: Set(group.map { $0.track.id }).count, art: nil)
        }
    }

    private func topAlbums(_ plays: [Play], limit: Int) -> [AlbumEntry] {
        group(plays, by: { $0.track.album }, limit: limit) { key, group in
            let album = albumsByID[key]
            return AlbumEntry(
                id: key, name: album?.name ?? key,
                artist: artistsByID[album?.artist ?? ""]?.name,
                plays: group.count,
                seconds: group.reduce(0) { $0 + $1.track.seconds },
                tracks: Set(group.map { $0.track.id }).count, art: nil)
        }
    }

    private func topGenres(_ plays: [Play], limit: Int) -> [GenreEntry] {
        group(plays, by: { $0.track.genre }, limit: limit) { key, group in
            GenreEntry(name: key, plays: group.count,
                       seconds: group.reduce(0) { $0 + $1.track.seconds })
        }
    }

    /// One grouping routine for all of the top lists.
    private func group<T>(_ plays: [Play], by key: (Play) -> String, limit: Int,
                          make: (String, [Play]) -> T) -> [T] {
        var buckets: [String: [Play]] = [:]
        for play in plays { buckets[key(play), default: []].append(play) }
        return buckets
            .map { (count: $0.value.count, entry: make($0.key, $0.value)) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map(\.entry)
    }

    private func timeline(_ plays: [Play], start: Int, end: Int) -> [DayEntry] {
        var buckets: [String: (plays: Int, seconds: Int)] = [:]
        for play in plays {
            let key = dayKey(play.timestamp)
            let current = buckets[key] ?? (0, 0)
            buckets[key] = (current.plays + 1, current.seconds + play.track.seconds)
        }
        var days: [DayEntry] = []
        var cursor = start
        while cursor < end {
            let key = dayKey(cursor)
            let bucket = buckets[key] ?? (0, 0)
            days.append(DayEntry(date: key, plays: bucket.plays, seconds: bucket.seconds))
            cursor += 86_400
        }
        return days
    }

    private func clock(_ plays: [Play]) -> ClockInfo {
        var matrix = Array(repeating: Array(repeating: 0, count: 24), count: 7)
        var hours = Array(repeating: 0, count: 24)
        var weekdays = Array(repeating: 0, count: 7)
        for play in plays {
            let date = Date(timeIntervalSince1970: TimeInterval(play.timestamp))
            let hour = calendar.component(.hour, from: date)
            // Calendar counts Sunday as 1; Rotation starts the week on Monday.
            let weekday = (calendar.component(.weekday, from: date) + 5) % 7
            matrix[weekday][hour] += 1
            hours[hour] += 1
            weekdays[weekday] += 1
        }
        return ClockInfo(
            matrix: matrix, hours: hours, weekdays: weekdays,
            peakHour: hours.contains(where: { $0 > 0 }) ? hours.firstIndex(of: hours.max()!) : nil,
            peakWeekday: weekdays.contains(where: { $0 > 0 })
                ? weekdays.firstIndex(of: weekdays.max()!) : nil)
    }

    private func streaks(_ plays: [Play]) -> Streaks {
        let days = Set(plays.map { calendar.startOfDay(
            for: Date(timeIntervalSince1970: TimeInterval($0.timestamp))) })
            .map { Int($0.timeIntervalSince1970) / 86_400 }
            .sorted()
        guard let last = days.last else { return Streaks(current: 0, longest: 0) }
        var longest = 1, run = 1
        for (previous, day) in zip(days, days.dropFirst()) {
            run = day == previous + 1 ? run + 1 : 1
            longest = max(longest, run)
        }
        let today = Int(calendar.startOfDay(for: Date()).timeIntervalSince1970) / 86_400
        var current = 0
        if last == today || last == today - 1 {
            current = 1
            var cursor = last
            for day in days.dropLast().reversed() {
                if day == cursor - 1 { current += 1; cursor = day } else { break }
            }
        }
        return Streaks(current: current, longest: longest)
    }

    private func discoveries(_ start: Int, _ end: Int, limit: Int) -> [Discovery] {
        var first: [String: Int] = [:]
        var inRange: [String: Int] = [:]
        for play in events {
            let artist = play.track.artist
            if first[artist] == nil || play.timestamp < first[artist]! {
                first[artist] = play.timestamp
            }
            if play.timestamp >= start && play.timestamp < end {
                inRange[artist, default: 0] += 1
            }
        }
        return first
            .filter { $0.value >= start && $0.value < end }
            .map { Discovery(id: $0.key, name: artistsByID[$0.key]?.name ?? $0.key,
                             plays: inRange[$0.key] ?? 0, firstPlay: $0.value) }
            .sorted { $0.plays > $1.plays }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - DataSource

    func me() async throws -> MeInfo {
        let first = events.first?.timestamp ?? 0
        let last = events.last?.timestamp ?? 0
        let years = Set(events.map {
            calendar.component(.year, from: Date(timeIntervalSince1970: TimeInterval($0.timestamp)))
        }).sorted(by: >)
        return MeInfo(
            user: library.user,
            bounds: Bounds(firstPlay: first, lastPlay: last,
                           historyPlays: events.count, lifetimePlays: events.count),
            years: years, timezone: TimeZone.current.identifier,
            // The demo is always in season: a reviewer opening this in June
            // should still find the recap where the description says it is.
            discoverable: true,
            season: Season(open: true, year: years.first ?? 0, start: 0, end: 0),
            version: "demo")
    }

    func overview(period: Period, user: String?) async throws -> Overview {
        let (start, end, days) = bounds(period)
        let plays = slice(start, end)
        return Overview(
            user: library.user,
            range: RangeInfo(key: period.rawValue, label: period.label,
                             start: start, end: end, days: days),
            summary: summary(plays),
            tracks: topTracks(plays, limit: 25),
            artists: topArtists(plays, limit: 25),
            albums: topAlbums(plays, limit: 25),
            genres: topGenres(plays, limit: 10),
            timeline: timeline(plays, start: start, end: end),
            clock: clock(plays),
            streaks: streaks(events),
            discoveries: discoveries(start, end, limit: 12))
    }

    func recent(limit: Int, user: String?) async throws -> RecentPlays {
        let plays = events.suffix(limit).reversed().map { play in
            PlayEntry(playedAt: play.timestamp, trackID: play.track.id,
                      title: play.track.title,
                      artist: artistsByID[play.track.artist]?.name ?? "",
                      album: albumsByID[play.track.album]?.name, art: nil)
        }
        return RecentPlays(plays: Array(plays))
    }

    func wrapped(year: Int?, user: String?) async throws -> Wrapped {
        let target = year ?? currentYear
        let start = startOfYear(target)
        let end = min(startOfYear(target + 1),
                      Int(calendar.startOfDay(for: Date()).timeIntervalSince1970) + 86_400)
        let plays = slice(start, end)
        let years = Set(events.map {
            calendar.component(.year, from: Date(timeIntervalSince1970: TimeInterval($0.timestamp)))
        }).sorted(by: >)

        var months = (1...12).map { MonthEntry(month: $0, plays: 0, seconds: 0) }
        for play in plays {
            let month = calendar.component(
                .month, from: Date(timeIntervalSince1970: TimeInterval(play.timestamp)))
            let existing = months[month - 1]
            months[month - 1] = MonthEntry(month: month, plays: existing.plays + 1,
                                           seconds: existing.seconds + play.track.seconds)
        }

        let artists = topArtists(plays, limit: 10)
        let total = plays.count
        let first = plays.first
        let previousPlays = slice(startOfYear(target - 1), start)

        return Wrapped(
            year: target, years: years, user: library.user,
            summary: summary(plays), months: months,
            topMonth: months.max(by: { $0.plays < $1.plays }),
            clock: clock(plays),
            tracks: topTracks(plays, limit: 10),
            artists: artists,
            albums: topAlbums(plays, limit: 10),
            genres: topGenres(plays, limit: 8),
            discoveries: discoveries(start, end, limit: 12),
            firstPlay: first.map {
                FirstPlay(playedAt: $0.timestamp, title: $0.track.title,
                          artist: artistsByID[$0.track.artist]?.name ?? "", art: nil)
            },
            streak: streaks(plays).longest,
            devotion: total > 0 ? Int((Double(artists.first?.plays ?? 0) / Double(total) * 100).rounded()) : 0,
            previous: previousPlays.isEmpty ? nil : PreviousYear(
                year: target - 1, plays: previousPlays.count,
                seconds: previousPlays.reduce(0) { $0 + $1.track.seconds }),
            artistTrack: artists.first.flatMap { artist in
                topTracks(plays.filter { $0.track.artist == artist.id }, limit: 1).first
            },
            genreTrack: topGenres(plays, limit: 1).first.flatMap { genre in
                topTracks(plays.filter { $0.track.genre == genre.name }, limit: 1).first
            },
            hasData: !plays.isEmpty)
    }

    func friends() async throws -> FriendLists {
        FriendLists(
            friends: library.friends.map { Person(id: $0.id, userName: $0.name, name: $0.name) },
            incoming: [], outgoing: [], suggestions: [])
    }

    func addFriend(_ userID: String) async throws -> Bool { true }
    func removeFriend(_ userID: String, withdraw: Bool) async throws {}
    func setDiscoverable(_ value: Bool) async throws {}
    func artworkURL(_ art: String?, size: Int) -> URL? { nil }
    // The invented library has no audio; the story simply runs in silence.
    func streamURL(_ trackID: String?) -> URL? { nil }

    // Nothing to write to: the demo has no Navidrome behind it.
    func playlists() async throws -> [ManagedPlaylist] { [] }
    func writePlaylist(range: String, language: String) async throws -> PlaylistWritten {
        throw APIError.forbidden
    }
    func dropPlaylist(range: String) async throws {}

    func compare(with userID: String, period: Period) async throws -> Comparison {
        let (start, end, days) = bounds(period)
        let plays = slice(start, end)
        let mine = topArtists(plays, limit: 25)
        guard let friend = library.friends.first(where: { $0.id == userID }) else {
            throw APIError.forbidden
        }
        // The friend's numbers are scaled from the demo library, so the two
        // sides stay in a believable relation whatever period is picked.
        let factor = Double(friend.plays) / Double(max(events.count, 1))
        let theirs = mine.enumerated().map { index, artist -> ArtistEntry in
            let boost = friend.artists.contains(artist.name) ? 2.4 : 0.5
            let count = max(1, Int((Double(artist.plays) * factor * boost).rounded()))
            return ArtistEntry(id: artist.id, name: artist.name, plays: count,
                               seconds: count * 210, tracks: artist.tracks, art: nil)
        }.sorted { $0.plays > $1.plays }

        let theirPlays = theirs.reduce(0) { $0 + $1.plays }
        let person = Person(id: friend.id, userName: friend.name, name: friend.name)
        let shared = mine.prefix(12).compactMap { artist -> SharedArtist? in
            guard let match = theirs.first(where: { $0.id == artist.id }) else { return nil }
            return SharedArtist(name: artist.name, art: nil,
                                mine: artist.plays, theirs: match.plays)
        }

        return Comparison(
            range: RangeInfo(key: period.rawValue, label: period.label,
                             start: start, end: end, days: days),
            me: ComparisonSide(user: library.user, summary: summary(plays),
                               artists: Array(mine.prefix(10)),
                               tracks: topTracks(plays, limit: 5)),
            them: ComparisonSide(
                user: person,
                summary: Summary(plays: theirPlays,
                                 seconds: theirPlays * 215,
                                 tracks: theirs.reduce(0) { $0 + $1.tracks },
                                 artists: theirs.count,
                                 albums: max(1, theirs.count - 2),
                                 activeDays: max(1, days / 3)),
                artists: Array(theirs.prefix(10)), tracks: []),
            shared: Array(shared))
    }

    // MARK: - One item, in detail

    func detail(kind: String, id: String, range: String,
                user: String?) async throws -> ItemDetail {
        let span = window(range)
        switch kind {
        case "track": return try trackDetail(id, range, span)
        case "artist": return try artistDetail(id, range, span)
        default: return try albumDetail(id, range, span)
        }
    }

    /// Months and hours over the whole history, everything else inside the
    /// period being looked at – the same shape the server answers with.
    private func detail(_ history: [Play], scoped: [Play], id: String, kind: String,
                        rangeKey: String, span: (start: Int, end: Int, label: String),
                        title: String?, name: String?, artist: String?,
                        album: String?, tracks: Int?, albums: Int?,
                        trackTotal: Int? = nil,
                        topTracks: [TrackEntry]? = nil,
                        topAlbums: [AlbumEntry]? = nil,
                        rankKey: @escaping (Play) -> String) -> ItemDetail {
        var months: [String: Int] = [:]
        var hours = Array(repeating: 0, count: 24)
        for play in history {
            let local = calendar.dateComponents([.year, .month, .hour],
                                                from: Date(timeIntervalSince1970:
                                                            TimeInterval(play.timestamp)))
            months[String(format: "%04d-%02d", local.year ?? 0, local.month ?? 0),
                   default: 0] += 1
            hours[local.hour ?? 0] += 1
        }
        var counts: [String: Int] = [:]
        for play in slice(span.start, span.end) { counts[rankKey(play), default: 0] += 1 }
        let rank = counts.values.filter { $0 > scoped.count }.count + 1

        return ItemDetail(
            kind: kind, id: id, title: title, name: name, artist: artist, album: album,
            art: nil,
            plays: scoped.count,
            seconds: scoped.reduce(0) { $0 + $1.track.seconds },
            totalPlays: history.count,
            firstPlay: history.first?.timestamp ?? 0,
            lastPlay: history.last?.timestamp ?? 0,
            rank: scoped.isEmpty ? 0 : rank,
            tracks: tracks, albums: albums, trackTotal: trackTotal,
            range: RangeInfo(key: rangeKey, label: span.label,
                             start: span.start, end: span.end,
                             days: max(1, (span.end - span.start) / 86_400)),
            months: months.sorted { $0.key < $1.key }
                .map { MonthPoint(month: $0.key, plays: $0.value) },
            hours: hours,
            topTracks: topTracks, topAlbums: topAlbums)
    }

    private func trackDetail(_ id: String, _ rangeKey: String,
                             _ span: (start: Int, end: Int, label: String))
        throws -> ItemDetail {
        let history = events.filter { $0.track.id == id }
        guard let track = history.first?.track
                ?? library.tracks.first(where: { $0.id == id })
        else { throw APIError.server("unknown") }
        return detail(history, scoped: within(history, span), id: id, kind: "track",
                      rangeKey: rangeKey, span: span,
                      title: track.title, name: nil,
                      artist: artistsByID[track.artist]?.name,
                      album: albumsByID[track.album]?.name,
                      tracks: nil, albums: nil,
                      rankKey: { $0.track.id })
    }

    private func artistDetail(_ id: String, _ rangeKey: String,
                              _ span: (start: Int, end: Int, label: String))
        throws -> ItemDetail {
        let history = events.filter { $0.track.artist == id }
        guard !history.isEmpty else { throw APIError.server("unknown") }
        let plays = within(history, span)
        return detail(history, scoped: plays, id: id, kind: "artist",
                      rangeKey: rangeKey, span: span,
                      title: nil, name: artistsByID[id]?.name ?? id,
                      artist: nil, album: nil,
                      tracks: Set(plays.map { $0.track.id }).count,
                      albums: Set(plays.map { $0.track.album }).count,
                      topTracks: topTracks(plays, limit: 10),
                      topAlbums: topAlbums(plays, limit: 6),
                      rankKey: { $0.track.artist })
    }

    private func albumDetail(_ id: String, _ rangeKey: String,
                             _ span: (start: Int, end: Int, label: String))
        throws -> ItemDetail {
        let history = events.filter { $0.track.album == id }
        guard !history.isEmpty else { throw APIError.server("unknown") }
        let plays = within(history, span)
        return detail(history, scoped: plays, id: id, kind: "album",
                      rangeKey: rangeKey, span: span,
                      title: nil, name: albumsByID[id]?.name ?? id,
                      artist: artistsByID[albumsByID[id]?.artist ?? ""]?.name,
                      album: nil,
                      tracks: Set(plays.map { $0.track.id }).count, albums: nil,
                      trackTotal: library.tracks.filter { $0.album == id }.count,
                      topTracks: topTracks(plays, limit: 10),
                      rankKey: { $0.track.album })
    }

    private func within(_ plays: [Play],
                        _ span: (start: Int, end: Int, label: String)) -> [Play] {
        plays.filter { $0.timestamp >= span.start && $0.timestamp < span.end }
    }
}
