import Foundation
import SwiftUI

/// Who is signed in, against which server – and whether this is the demo.
@MainActor
final class Session: ObservableObject {
    enum Stage: Equatable {
        case loading
        case server          // no address yet
        case login           // address known, not signed in
        case ready
    }

    @Published private(set) var stage: Stage = .loading
    @Published private(set) var me: MeInfo?
    @Published private(set) var source: DataSource?
    @Published var errorMessage: String?
    /// A one-line confirmation, shown and then forgotten.
    @Published var notice: String?
    @Published var isWorking = false
    /// Set while looking at a friend's numbers instead of one's own.
    @Published var viewing: Person?

    static let shared = Session()

    private let defaults = UserDefaults.standard
    private let addressKey = "rotation.server"
    private let userKey = "rotation.username"

    var serverAddress: String? {
        get { defaults.string(forKey: addressKey) }
        set { defaults.set(newValue, forKey: addressKey) }
    }

    var username: String? {
        get { defaults.string(forKey: userKey) }
        set { defaults.set(newValue, forKey: userKey) }
    }

    var isDemo: Bool { source?.isDemo ?? false }
    private var client: APIClient? { source as? APIClient }

    // MARK: - Start-up

    func restore() async {
        if let address = serverAddress, let url = APIClient.normalise(address) {
            let client = APIClient(baseURL: url)
            source = client
            do {
                me = try await client.me()
                stage = .ready
                return
            } catch APIError.unauthorized {
                // The server forgot us – sign in again with the stored password.
                if let user = username, let password = Keychain.get(user) {
                    await signIn(username: user, password: password, quiet: true)
                    if stage == .ready { return }
                }
                stage = .login
                return
            } catch {
                stage = .login
                errorMessage = error.localizedDescription
                return
            }
        }
        stage = .server
    }

    // MARK: - Connecting

    /// Checks that a Rotation server answers, and remembers the address.
    func connect(to address: String) async -> Bool {
        guard let url = APIClient.normalise(address) else {
            errorMessage = APIError.badURL.localizedDescription
            return false
        }
        isWorking = true
        defer { isWorking = false }
        let client = APIClient(baseURL: url)
        do {
            _ = try await client.probe()
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        serverAddress = url.absoluteString
        source = client
        errorMessage = nil
        stage = .login
        return true
    }

    func signIn(username user: String, password: String, quiet: Bool = false) async {
        guard let client else { return }
        if !quiet { isWorking = true }
        defer { isWorking = false }
        do {
            _ = try await client.login(username: user, password: password)
            me = try await client.me()
            username = user
            Keychain.set(password, for: user)
            errorMessage = nil
            stage = .ready
        } catch {
            if !quiet { errorMessage = error.localizedDescription }
        }
    }

    func startDemo() {
        guard let demo = DemoSource() else {
            errorMessage = NSLocalizedString("The demo data is missing.", comment: "")
            return
        }
        source = demo
        Task {
            me = try? await demo.me()
            stage = .ready
        }
    }

    func signOut() {
        viewing = nil
        if let user = username { Keychain.set(nil, for: user) }
        Task { await client?.logout() }
        me = nil
        if isDemo {
            // Leaving the demo lands where a new user starts.
            source = nil
            stage = serverAddress == nil ? .server : .login
            if let address = serverAddress, let url = APIClient.normalise(address) {
                source = APIClient(baseURL: url)
            }
        } else {
            stage = .login
        }
    }

    func forgetServer() {
        serverAddress = nil
        username = nil
        source = nil
        me = nil
        stage = .server
    }

    /// Runs a request and turns an expired session into a silent re-sign-in.
    func perform<T>(_ work: () async throws -> T) async -> T? {
        do {
            return try await work()
        } catch APIError.unauthorized {
            if let user = username, let password = Keychain.get(user) {
                await signIn(username: user, password: password, quiet: true)
                return try? await work()
            }
            stage = .login
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
