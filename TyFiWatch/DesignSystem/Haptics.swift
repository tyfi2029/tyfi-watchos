import WatchKit

/// Design haptic events (§ handoff: .success / .click / value-bump). Thin wrapper
/// over `WKInterfaceDevice` so call sites read as intent, not Watch API.
enum Haptics {
    /// Light tick for taps / optimistic value bumps.
    static func click()   { play(.click) }
    /// Positive confirmation for completed actions (logged, saved, finished).
    static func success() { play(.success) }
    /// Negative feedback when an action fails.
    static func failure() { play(.failure) }
    /// Session/timer begin & end.
    static func start()   { play(.start) }
    static func stop()    { play(.stop) }

    private static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}
