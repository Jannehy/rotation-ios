import Foundation

// The wire format of the Rotation API. The demo source builds the very same
// structures locally, so nothing above this layer knows where data came from.

struct Person: Codable, Hashable, Identifiable {
    let id: String
    let userName: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case userName = "user_name"
    }
}

struct Bounds: Codable {
    let firstPlay: Int
    let lastPlay: Int
    let historyPlays: Int
    let lifetimePlays: Int

    enum CodingKeys: String, CodingKey {
        case firstPlay = "first_play"
        case lastPlay = "last_play"
        case historyPlays = "history_plays"
        case lifetimePlays = "lifetime_plays"
    }
}

struct MeInfo: Codable {
    let user: Person
    let bounds: Bounds
    let years: [Int]
    let timezone: String
    let discoverable: Bool
    let season: Season?
    let version: String
}

/// When the recap steps forward by itself: 1 December to 31 January.
/// The server decides it so every client agrees on the date.
/// A playlist Rotation keeps up to date in Navidrome.
struct ManagedPlaylist: Codable, Identifiable {
    let range: String
    let size: Int
    let name: String
    let playlistID: String
    let tracks: Int
    let updatedAt: Int

    var id: String { range }

    enum CodingKeys: String, CodingKey {
        case range, size, name, tracks
        case playlistID = "playlist_id"
        case updatedAt = "updated_at"
    }
}

struct ManagedPlaylists: Codable {
    let playlists: [ManagedPlaylist]
}

struct PlaylistWritten: Codable {
    let ok: Bool
    let playlist: ManagedPlaylist
    let tracks: Int
}

struct Season: Codable {
    let open: Bool
    let year: Int
    let start: Int
    let end: Int
}

struct RangeInfo: Codable {
    let key: String
    let label: String
    let start: Int
    let end: Int
    let days: Int

    enum CodingKeys: String, CodingKey {
        case key, label, start, end, days
    }
}

struct Summary: Codable {
    let plays: Int
    let seconds: Int
    let tracks: Int
    let artists: Int
    let albums: Int
    let activeDays: Int

    enum CodingKeys: String, CodingKey {
        case plays, seconds, tracks, artists, albums
        case activeDays = "active_days"
    }
}

struct TrackEntry: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let art: String?
    let plays: Int
    let seconds: Int

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album, art, plays, seconds
    }
}

struct ArtistEntry: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let plays: Int
    let seconds: Int
    let tracks: Int
    let art: String?

    enum CodingKeys: String, CodingKey {
        case id, name, plays, seconds, tracks, art
    }
}

struct AlbumEntry: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let artist: String?
    let plays: Int
    let seconds: Int
    let tracks: Int
    let art: String?

    enum CodingKeys: String, CodingKey {
        case id, name, artist, plays, seconds, tracks, art
    }
}

struct GenreEntry: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let plays: Int
    let seconds: Int
}

struct DayEntry: Codable, Identifiable, Hashable {
    var id: String { date }
    let date: String            // yyyy-MM-dd, local
    let plays: Int
    let seconds: Int
}

struct ClockInfo: Codable {
    let matrix: [[Int]]         // 7 weekdays × 24 hours, Monday first
    let hours: [Int]
    let weekdays: [Int]
    let peakHour: Int?
    let peakWeekday: Int?

    enum CodingKeys: String, CodingKey {
        case matrix, hours, weekdays
        case peakHour = "peak_hour"
        case peakWeekday = "peak_weekday"
    }
}

struct Streaks: Codable {
    let current: Int
    let longest: Int

    enum CodingKeys: String, CodingKey {
        case current, longest
    }
}

struct Discovery: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let plays: Int
    let firstPlay: Int

    enum CodingKeys: String, CodingKey {
        case id, name, plays
        case firstPlay = "first_play"
    }
}

struct Overview: Codable {
    let user: Person
    let range: RangeInfo
    let summary: Summary
    let tracks: [TrackEntry]
    let artists: [ArtistEntry]
    let albums: [AlbumEntry]
    let genres: [GenreEntry]
    let timeline: [DayEntry]
    let clock: ClockInfo
    let streaks: Streaks
    let discoveries: [Discovery]
}

struct PlayEntry: Codable, Identifiable, Hashable {
    var id: String { "\(playedAt)-\(trackID)" }
    let playedAt: Int
    let trackID: String
    let title: String
    let artist: String
    let album: String?
    let art: String?

    enum CodingKeys: String, CodingKey {
        case playedAt = "played_at"
        case trackID = "id"
        case title, artist, album, art
    }
}

struct RecentPlays: Codable {
    let plays: [PlayEntry]
}

struct MonthEntry: Codable, Identifiable, Hashable {
    var id: Int { month }
    let month: Int
    let plays: Int
    let seconds: Int
}

struct FirstPlay: Codable {
    let playedAt: Int
    let title: String
    let artist: String
    let art: String?

    enum CodingKeys: String, CodingKey {
        case playedAt = "played_at"
        case title, artist, art
    }
}

struct PreviousYear: Codable {
    let year: Int
    let plays: Int
    let seconds: Int
}

struct Wrapped: Codable, Identifiable {
    /// A year identifies a recap – enough for `fullScreenCover(item:)`, which
    /// is how the story is presented once its data has arrived.
    var id: Int { year }

    let year: Int
    let years: [Int]
    let user: Person?
    let summary: Summary
    let months: [MonthEntry]
    let topMonth: MonthEntry?
    let clock: ClockInfo
    let tracks: [TrackEntry]
    let artists: [ArtistEntry]
    let albums: [AlbumEntry]
    let genres: [GenreEntry]
    let discoveries: [Discovery]
    let firstPlay: FirstPlay?
    let streak: Int
    let devotion: Int
    let previous: PreviousYear?
    /// The song behind the artist card, chosen by the server from ids.
    let artistTrack: TrackEntry?
    /// The song behind the genre card.
    let genreTrack: TrackEntry?
    let hasData: Bool

    enum CodingKeys: String, CodingKey {
        case year, years, user, summary, months, clock, tracks, artists, albums
        case genres, discoveries, streak, devotion, previous
        case topMonth = "top_month"
        case firstPlay = "first_play"
        case artistTrack = "artist_track"
        case genreTrack = "genre_track"
        case hasData = "has_data"
    }
}

struct FriendLists: Codable {
    let friends: [Person]
    let incoming: [Person]
    let outgoing: [Person]
    let suggestions: [Person]
}

struct ComparisonSide: Codable {
    let user: Person
    let summary: Summary
    let artists: [ArtistEntry]
    let tracks: [TrackEntry]
}

struct SharedArtist: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let art: String?
    let mine: Int
    let theirs: Int
}

struct Comparison: Codable {
    let range: RangeInfo
    let me: ComparisonSide
    let them: ComparisonSide
    let shared: [SharedArtist]
}

struct VersionInfo: Codable {
    let name: String?
    let version: String
}

/// The periods the app offers, in one place.
enum Period: String, CaseIterable, Identifiable {
    case week = "7d"
    case month = "30d"
    case quarter = "90d"
    case year
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: return NSLocalizedString("7 days", comment: "")
        case .month: return NSLocalizedString("30 days", comment: "")
        case .quarter: return NSLocalizedString("90 days", comment: "")
        case .year: return NSLocalizedString("This year", comment: "")
        case .all: return NSLocalizedString("All time", comment: "")
        }
    }
}

// MARK: - Lenient decoding
//
// A server may leave a field out of one payload while including it in
// another. Swift would fail the whole decode over that; these initialisers
// fall back to empty values instead, so a screen shows what it has.

extension RangeInfo {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        key = try values.decodeIfPresent(String.self, forKey: .key) ?? ""
        label = try values.decodeIfPresent(String.self, forKey: .label) ?? ""
        start = try values.decodeIfPresent(Int.self, forKey: .start) ?? 0
        end = try values.decodeIfPresent(Int.self, forKey: .end) ?? 0
        days = try values.decodeIfPresent(Int.self, forKey: .days) ?? 0
    }
}

extension ClockInfo {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        matrix = try values.decodeIfPresent([[Int]].self, forKey: .matrix) ?? []
        hours = try values.decodeIfPresent([Int].self, forKey: .hours) ?? []
        weekdays = try values.decodeIfPresent([Int].self, forKey: .weekdays) ?? []
        peakHour = try values.decodeIfPresent(Int.self, forKey: .peakHour)
        peakWeekday = try values.decodeIfPresent(Int.self, forKey: .peakWeekday)
    }
}

extension Streaks {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        current = try values.decodeIfPresent(Int.self, forKey: .current) ?? 0
        longest = try values.decodeIfPresent(Int.self, forKey: .longest) ?? 0
    }
}

extension Summary {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        plays = try values.decodeIfPresent(Int.self, forKey: .plays) ?? 0
        seconds = try values.decodeIfPresent(Int.self, forKey: .seconds) ?? 0
        tracks = try values.decodeIfPresent(Int.self, forKey: .tracks) ?? 0
        artists = try values.decodeIfPresent(Int.self, forKey: .artists) ?? 0
        albums = try values.decodeIfPresent(Int.self, forKey: .albums) ?? 0
        activeDays = try values.decodeIfPresent(Int.self, forKey: .activeDays) ?? 0
    }
}

// MARK: - One item, in detail

struct MonthPoint: Codable, Identifiable, Hashable {
    var id: String { month }
    let month: String           // yyyy-MM
    let plays: Int
}

/// The answer of `/api/track`, `/api/artist` and `/api/album`.
///
/// One structure for all three: they differ in which fields they fill, not in
/// what they mean.
struct ItemDetail: Codable {
    let kind: String
    let id: String
    let title: String?
    let name: String?
    let artist: String?
    let album: String?
    let art: String?
    let plays: Int
    let seconds: Int
    let totalPlays: Int?
    let firstPlay: Int
    let lastPlay: Int
    let rank: Int
    let tracks: Int?
    let albums: Int?
    let trackTotal: Int?
    let range: RangeInfo?
    let months: [MonthPoint]
    let hours: [Int]
    let topTracks: [TrackEntry]?
    let topAlbums: [AlbumEntry]?

    enum CodingKeys: String, CodingKey {
        case kind, id, title, name, artist, album, art, plays, seconds, rank
        case tracks, albums, months, hours, range
        case totalPlays = "total_plays"
        case firstPlay = "first_play"
        case lastPlay = "last_play"
        case trackTotal = "track_total"
        case topTracks = "top_tracks"
        case topAlbums = "top_albums"
    }

    var displayName: String { title ?? name ?? "" }

    var subtitle: String {
        switch kind {
        case "track": return [artist, album].compactMap { $0 }.filter { !$0.isEmpty }
                                            .joined(separator: " · ")
        case "album": return artist ?? ""
        default: return ""
        }
    }
}

extension TrackEntry {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? ""
        artist = try values.decodeIfPresent(String.self, forKey: .artist) ?? ""
        album = try values.decodeIfPresent(String.self, forKey: .album)
        art = try values.decodeIfPresent(String.self, forKey: .art)
        plays = try values.decodeIfPresent(Int.self, forKey: .plays) ?? 0
        seconds = try values.decodeIfPresent(Int.self, forKey: .seconds) ?? 0
    }
}

extension AlbumEntry {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        artist = try values.decodeIfPresent(String.self, forKey: .artist)
        art = try values.decodeIfPresent(String.self, forKey: .art)
        plays = try values.decodeIfPresent(Int.self, forKey: .plays) ?? 0
        seconds = try values.decodeIfPresent(Int.self, forKey: .seconds) ?? 0
        tracks = try values.decodeIfPresent(Int.self, forKey: .tracks) ?? 0
    }
}

extension ArtistEntry {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        art = try values.decodeIfPresent(String.self, forKey: .art)
        plays = try values.decodeIfPresent(Int.self, forKey: .plays) ?? 0
        seconds = try values.decodeIfPresent(Int.self, forKey: .seconds) ?? 0
        tracks = try values.decodeIfPresent(Int.self, forKey: .tracks) ?? 0
    }
}
