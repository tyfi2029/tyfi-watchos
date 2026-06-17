import Foundation

/// Last-good `/snapshot` cache for offline resilience (§4 T84).
///
/// Persists the most recent successful snapshot to `UserDefaults` with the wall-clock
/// time it was stored, so a failed refresh can fall back to last-known values with an
/// honest "as of …" timestamp instead of an empty screen. Standalone (no App Group), so
/// it needs no provisioning; widget↔app sharing is a separate concern (T80).
enum SnapshotCache {
    private static let key = "lastGoodSnapshot.v1"

    private struct Entry: Codable {
        let snapshot: Snapshot
        let storedAt: Date
    }

    static func save(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(Entry(snapshot: snapshot, storedAt: Date())) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Returns the cached snapshot and how long ago it was stored, if any.
    static func load() -> (snapshot: Snapshot, storedAt: Date)? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entry = try? JSONDecoder().decode(Entry.self, from: data) else { return nil }
        return (entry.snapshot, entry.storedAt)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }

    /// Short relative label e.g. "2m ago", "just now" for the stale banner.
    static func staleLabel(for date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 60 { return "just now" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        if secs < 86400 { return "\(secs / 3600)h ago" }
        return "\(secs / 86400)d ago"
    }
}
