import Foundation

/// What a screen needs, regardless of where the numbers come from.
///
/// `APIClient` answers from a Rotation server, `DemoSource` answers from the
/// invented library bundled with the app. Nothing above this protocol has to
/// know which one is in play.
protocol DataSource {
    var isDemo: Bool { get }

    func me() async throws -> MeInfo
    func overview(period: Period, user: String?) async throws -> Overview
    func recent(limit: Int, user: String?) async throws -> RecentPlays
    func wrapped(year: Int?, user: String?) async throws -> Wrapped
    func friends() async throws -> FriendLists
    func addFriend(_ userID: String) async throws -> Bool
    func removeFriend(_ userID: String, withdraw: Bool) async throws
    func compare(with userID: String, period: Period) async throws -> Comparison
    func setDiscoverable(_ value: Bool) async throws
    /// `kind` is "track", "artist" or "album".
    func detail(kind: String, id: String, range: String,
                user: String?) async throws -> ItemDetail
    func artworkURL(_ art: String?, size: Int) -> URL?

    /// A track to play behind the recap story, or nil where there is no
    /// server to stream from – as in the demo.
    func streamURL(_ trackID: String?) -> URL?

    /// The playlists Rotation looks after for this user.
    func playlists() async throws -> [ManagedPlaylist]
    /// Creates the playlist for this period, or rewrites the existing one.
    func writePlaylist(range: String, language: String) async throws -> PlaylistWritten
    /// Stops looking after it – the playlist itself stays in Navidrome.
    func dropPlaylist(range: String) async throws
}

extension DataSource {
    func overview(period: Period) async throws -> Overview {
        try await overview(period: period, user: nil)
    }
}

enum APIError: LocalizedError {
    case badURL
    case unauthorized
    case forbidden
    case unreachable(String)
    case server(String)
    case notARotationServer

    var errorDescription: String? {
        switch self {
        case .badURL:
            return NSLocalizedString("That address does not look right.", comment: "")
        case .unauthorized:
            return NSLocalizedString("Wrong username or password.", comment: "")
        case .forbidden:
            return NSLocalizedString("You are not allowed to see that.", comment: "")
        case .unreachable(let detail):
            return String(format: NSLocalizedString("Server not reachable (%@).", comment: ""), detail)
        case .server(let detail):
            return detail
        case .notARotationServer:
            return NSLocalizedString("There is no Rotation server at that address.", comment: "")
        }
    }
}
