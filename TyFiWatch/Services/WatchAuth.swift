import Foundation

/// Holds the watch bearer token. Issued once by POST /api/watch/auth/token and
/// persisted in the keychain in a later pass; for the scaffold it reads from
/// UserDefaults so the app builds and runs without a live pairing.
/// Stateless wrapper over the thread-safe `UserDefaults`, hence `Sendable`.
final class WatchAuth: Sendable {
    static let shared = WatchAuth()
    private let key = "watch.bearerToken"

    var token: String? { UserDefaults.standard.string(forKey: key) }
    var isPaired: Bool { token?.isEmpty == false }
    func set(_ token: String) { UserDefaults.standard.set(token, forKey: key) }
}
