import Foundation

// Models mirror the wmp watch contract verified 2026-06-14 (origin/master).
// All Sendable so they can cross the API actor boundary.

// MARK: /api/watch/snapshot
struct Snapshot: Decodable, Sendable {
    let fetched_at: String?
    let cgm: CGM?
    let readiness: Readiness?
    let dol_next: DOLNext?
    let water_today: WaterToday?
    let protocol_progress: ProtocolProgress?
    let supplement_am_done: Bool?
    let supplement_pm_done: Bool?
    let last_thermal_session: ThermalSession?

    struct CGM: Decodable, Sendable {
        let glucose_mg_dl: Int?
        let trend: String?
        let fresh_seconds_ago: Int?
    }
    struct Readiness: Decodable, Sendable {
        let recovery: Int?
        let hrv: Int?
        let sleep: Int?
        let rhr: Int?
        let focus: String?
    }
    struct DOLNext: Decodable, Sendable {
        let id: String?
        let title: String?
        let due_at: String?
    }
    struct ProtocolProgress: Decodable, Sendable {
        let done: Int?
        let total: Int?
        let current_segment: String?
        let next_segment_at: String?
    }
    struct ThermalSession: Decodable, Sendable {
        let mode: String?
        let completed_at: String?
        let duration_sec: Int?
        let temp_f: Double?
    }
}

// MARK: /api/watch/hydration/today
struct WaterToday: Decodable, Sendable {
    let ml: Double?
    let goal_ml: Double?
    let pace_ml: Double?
    let brand: String?
    let oasis_score: Double?
}

// MARK: /api/watch/hydration/log  (POST body)
struct HydrationLog: Encodable, Sendable {
    let amount_ml: Double
    let brand: String?
    let logged_at: String
}

// MARK: /api/watch/protocol/today  and  /toggle response
struct ProtocolToday: Decodable, Sendable {
    let segments: [ProtocolSegment]
}
struct ProtocolSegment: Decodable, Sendable, Identifiable {
    let name: String            // Morning | Afternoon | Evening | Sleep
    let rangeStart: String?
    let rangeEnd: String?
    let items: [ProtocolItem]
    var id: String { name }
}
struct ProtocolItem: Decodable, Sendable, Identifiable {
    let id: String
    let time: String            // "HH:MM" MT, empty if unscheduled
    let label: String
    let done: Bool
    let tempF: Double?
}

// MARK: /api/watch/protocol/item/{id}/toggle  (POST body)
struct ProtocolToggle: Encodable, Sendable {
    let done: Bool
    let toggled_at: String
}
