import Foundation

/// Talks to a Rotation server. Authentication is the server's session
/// cookie, which `URLSession.shared` stores – so `AsyncImage` sends it too
/// and artwork loads without any extra plumbing.
final class APIClient: DataSource {
    let baseURL: URL
    var isDemo: Bool { false }

    private let session: URLSession = .shared
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Accepts what people actually type: `nas.local`, `192.168.1.4:8770`,
    /// `https://rotation.example.org/`.
    static func normalise(_ input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        guard var components = URLComponents(string: text), let host = components.host,
              !host.isEmpty else { return nil }
        if components.port == nil && components.scheme == "http" {
            components.port = 8770
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    // MARK: - Plumbing

    private func url(_ path: String, _ items: [URLQueryItem] = []) -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !items.isEmpty { components.queryItems = items }
        return components.url!
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.unreachable(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unreachable("no response")
        }
        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.notARotationServer
            }
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        default:
            let detail = (try? decoder.decode([String: String].self, from: data))?["error"]
            throw APIError.server(detail ?? "HTTP \(http.statusCode)")
        }
    }

    private func get<T: Decodable>(_ path: String, _ items: [URLQueryItem] = [],
                                   as type: T.Type) async throws -> T {
        try await send(URLRequest(url: url(path, items)), as: type)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any] = [:],
                                    as type: T.Type) async throws -> T {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request, as: type)
    }

    // MARK: - Endpoints

    /// Checks that something Rotation-shaped answers, before asking for a password.
    func probe() async throws -> VersionInfo {
        let info = try await get("api/version", as: VersionInfo.self)
        guard info.name == "Rotation" else { throw APIError.notARotationServer }
        return info
    }

    struct LoginResponse: Codable { let ok: Bool; let user: Person }

    @discardableResult
    func login(username: String, password: String) async throws -> Person {
        let response = try await post(
            "api/login", body: ["username": username, "password": password],
            as: LoginResponse.self)
        return response.user
    }

    struct OK: Codable { let ok: Bool }

    func logout() async {
        _ = try? await post("api/logout", as: OK.self)
    }

    func me() async throws -> MeInfo {
        try await get("api/me", as: MeInfo.self)
    }

    func overview(period: Period, user: String?) async throws -> Overview {
        try await get("api/overview", items(period: period, user: user), as: Overview.self)
    }

    func recent(limit: Int, user: String?) async throws -> RecentPlays {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let user { query.append(URLQueryItem(name: "user", value: user)) }
        return try await get("api/recent", query, as: RecentPlays.self)
    }

    func wrapped(year: Int?, user: String?) async throws -> Wrapped {
        var query: [URLQueryItem] = []
        if let year { query.append(URLQueryItem(name: "year", value: String(year))) }
        if let user { query.append(URLQueryItem(name: "user", value: user)) }
        return try await get("api/wrapped", query, as: Wrapped.self)
    }

    func friends() async throws -> FriendLists {
        try await get("api/friends", as: FriendLists.self)
    }

    struct FriendResponse: Codable { let ok: Bool; let friends: Bool }

    func addFriend(_ userID: String) async throws -> Bool {
        try await post("api/friends", body: ["user_id": userID], as: FriendResponse.self).friends
    }

    func removeFriend(_ userID: String, withdraw: Bool) async throws {
        var components = URLComponents(
            url: url("api/friends/\(userID)"), resolvingAgainstBaseURL: false)!
        if withdraw { components.queryItems = [URLQueryItem(name: "withdraw", value: "1")] }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        _ = try await send(request, as: OK.self)
    }

    func compare(with userID: String, period: Period) async throws -> Comparison {
        try await get("api/compare",
                      [URLQueryItem(name: "user", value: userID),
                       URLQueryItem(name: "range", value: period.rawValue)],
                      as: Comparison.self)
    }

    func setDiscoverable(_ value: Bool) async throws {
        _ = try await post("api/settings", body: ["discoverable": value], as: OK.self)
    }

    func detail(kind: String, id: String, range: String,
                user: String?) async throws -> ItemDetail {
        var query = [URLQueryItem(name: "range", value: range)]
        if let user { query.append(URLQueryItem(name: "user", value: user)) }
        return try await get("api/\(kind)/\(id)", query, as: ItemDetail.self)
    }

    func artworkURL(_ art: String?, size: Int) -> URL? {
        guard let art, !art.isEmpty else { return nil }
        return url("api/art/\(art)", [URLQueryItem(name: "size", value: String(size))])
    }

    func playlists() async throws -> [ManagedPlaylist] {
        try await get("api/playlists", [], as: ManagedPlaylists.self).playlists
    }

    func writePlaylist(range: String, language: String) async throws -> PlaylistWritten {
        try await post("api/playlists",
                       body: ["range": range, "lang": language],
                       as: PlaylistWritten.self)
    }

    func dropPlaylist(range: String) async throws {
        var request = URLRequest(url: url("api/playlists/\(range)"))
        request.httpMethod = "DELETE"
        _ = try await send(request, as: OK.self)
    }

    func streamURL(_ trackID: String?) -> URL? {
        guard let trackID, !trackID.isEmpty else { return nil }
        return url("api/stream/\(trackID)", [])
    }

    private func items(period: Period, user: String?) -> [URLQueryItem] {
        var query = [URLQueryItem(name: "range", value: period.rawValue)]
        if let user { query.append(URLQueryItem(name: "user", value: user)) }
        return query
    }
}
