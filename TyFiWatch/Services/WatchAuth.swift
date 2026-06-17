import Foundation
import Security

/// Persists the watch bearer token in the device Keychain.
/// Both the app and complications extension declare keychain-access-groups
/// with "E5HE9TGHFQ.fyi.tyfi.watch.shared" so the extension can read this token.
/// Thread-safe via Keychain's own internal locking.
/// Marked @unchecked Sendable because all mutable state lives in Keychain, not in Swift memory.
final class WatchAuth: @unchecked Sendable {
    static let shared = WatchAuth()
    private let service     = "fyi.tyfi.watch"
    private let account     = "bearerToken"
    private let accessGroup = "E5HE9TGHFQ.fyi.tyfi.watch.shared"

    var token: String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecAttrAccessGroup:  accessGroup,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str  = String(data: data, encoding: .utf8),
              !str.isEmpty else { return nil }
        return str
    }

    var isPaired: Bool { token != nil }

    func set(_ newToken: String) {
        let data = Data(newToken.utf8)
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     account,
            kSecAttrAccessGroup: accessGroup
        ]
        let attrs: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func clear() {
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     account,
            kSecAttrAccessGroup: accessGroup
        ]
        SecItemDelete(query as CFDictionary)
    }
}
