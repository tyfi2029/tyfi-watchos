import Foundation

/// wmp watch API client.
/// Contract (verified against tyfi2029/wmp origin/master, 2026-06-14):
///  - Base: https://life.tyfi.fyi
///  - Envelope: { "ok": true, "data": {...} } | { "ok": false, "error": "..." }
///  - Auth: Authorization: Bearer <raw>  (token issued once by POST /api/watch/auth/redeem;
///          only its SHA-256 is stored server-side). Single-user.
/// Only /api/watch/* accepts this bearer token — /api/glance is Authelia-gated and NOT watch-callable.
enum APIError: Error { case notAuthed, http(Int), envelope(String), decode }

struct Envelope<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: String?
}

actor API {
    static let shared = API()
    private let base = URL(string: "https://life.tyfi.fyi")!
    private let session: URLSession

    /// Default uses the standard session; tests inject a session whose configuration
    /// carries `MockURLProtocol` so POST request bodies can be verified offline (§3).
    init(session: URLSession = URLSession(configuration: .default)) {
        self.session = session
    }

    // MARK: Authenticated requests (require paired token)

    private func request(_ path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let token = WatchAuth.shared.token else { throw APIError.notAuthed }
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return req
    }

    func get<T: Decodable>(_ path: String, as _: T.Type) async throws -> T {
        try await send(request(path), as: T.self)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B, as _: T.Type) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await send(request(path, method: "POST", body: data), as: T.self)
    }

    // MARK: Unauthenticated request (used by PairingView to redeem a code)

    func postPublic<T: Decodable, B: Encodable>(_ path: String, body: B, as _: T.Type) async throws -> T {
        let data = try JSONEncoder().encode(body)
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        return try await send(req, as: T.self)
    }

    // MARK: Private

    private func send<T: Decodable>(_ req: URLRequest, as _: T.Type) async throws -> T {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.http(-1) }
        // §4.3 — 401 clears the stored token and posts a re-pair notification.
        if http.statusCode == 401 {
            await WatchAuth.shared.clear()
            NotificationCenter.default.post(name: Notification.Name("watchAuthExpired"), object: nil)
        }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
        let env = try JSONDecoder().decode(Envelope<T>.self, from: data)
        guard env.ok, let payload = env.data else { throw APIError.envelope(env.error ?? "unknown") }
        return payload
    }
}
