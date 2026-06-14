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
    let steps: Int?

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

// MARK: /api/watch/sleep  (Phase 2 — health_daily_facts derived)
struct SleepReport: Decodable, Sendable {
    let date: String?
    let duration: Duration?
    let stages: Stages?
    let overnight: Overnight?
    let recovery_score: Int?
    let hypnogram: [Int]?

    struct Duration: Decodable, Sendable {
        let total_min: Int?
        let efficiency_pct: Double?
        let score: Int?
        let debt_hrs: Double?
        let consistency: Double?
    }
    struct Stages: Decodable, Sendable {
        let deep_pct: Double?
        let rem_pct: Double?
        let light_pct: Double?
        let deep_min: Int?
        let rem_min: Int?
        let light_min: Int?
        let cycles: Int?
    }
    struct Overnight: Decodable, Sendable {
        let hrv_avg: Double?
        let hrv_min: Double?
        let hrv_max: Double?
        let rhr: Double?
        let skin_temp_deviation: Double?
        let avg_breath: Double?
        let spo2: Double?
    }
}

// MARK: /api/watch/trends  (Phase 2 — 7-day per-metric series)
struct Trends: Decodable, Sendable {
    let window_days: Int?
    let from: String?
    let to: String?
    let series: [String: [Point]]?
    let summary: [String: MetricSummary?]?

    struct Point: Decodable, Sendable {
        let date: String
        let value: Double?
    }
    struct MetricSummary: Decodable, Sendable {
        let avg: Double?
        let min: Double?
        let max: Double?
        let first: Double?
        let last: Double?
        let delta: Double?
        let n: Int?
    }
}

// MARK: /api/watch/environment  (Phase 2 — AQI/UV/pollen/noise advisory)
struct EnvironmentReport: Decodable, Sendable {
    let date: String?
    let air_quality: AirQuality?
    let uv: UV?
    let pollen: Pollen?
    let noise: Noise?
    let daylight_min: Double?
    let steps: Double?
    let advisory: String?

    struct AirQuality: Decodable, Sendable {
        let aqi: Double?
        let category: String?
        let pm2_5: Double?
        let no2: Double?
        let o3: Double?
    }
    struct UV: Decodable, Sendable {
        let index: Double?
        let category: String?
    }
    struct Pollen: Decodable, Sendable {
        let grass: Double?
        let ragweed: Double?
        let dominant: String?
        let level: String?
    }
    struct Noise: Decodable, Sendable {
        let env_db: Double?
        let headphone_db: Double?
        let advisory: String?
    }
}

// MARK: /api/watch/session  (Phase 2 — recent thermal/recovery sessions)
struct SessionList: Decodable, Sendable {
    let sessions: [WatchSession]
    let count: Int?
    let rolling_7d: Rollup?

    struct WatchSession: Decodable, Sendable, Identifiable {
        let id: Int
        let mode: String?
        let temp_f: Double?
        let duration_sec: Int?
        let duration_min: Int?
        let started_at: String?
        let completed_at: String?
        let date: String?
        let source: String?
    }
    struct Rollup: Decodable, Sendable {
        let heat_min: Int?
        let cold_min: Int?
        let sessions: Int?
    }
}

// MARK: /api/watch/fasting  (Phase 3 — health_fasting_logs)
struct FastingState: Decodable, Sendable {
    let active: ActiveFast?
    let streak: Int?
    let eating_window: EatingWindow?

    struct ActiveFast: Decodable, Sendable {
        let id: Int?
        let started_at: String?
        let target_hrs: Double?
        let elapsed_hrs: Double?
        let remaining_hrs: Double?
        let progress_pct: Double?
        let reached_target: Bool?
        // E2 additions
        let stage: String?
        let `protocol`: String?
    }
    struct EatingWindow: Decodable, Sendable {
        let open: Bool?
        let last_meal_at: String?
        let hours_since_last_meal: Double?
    }
}
struct FastingAction: Encodable, Sendable { let action: String }   // "start" | "end"
struct FastingPostResult: Decodable, Sendable {
    let started: Bool?
    let ended: Bool?
    let streak: Int?
    let reason: String?
}

// MARK: /api/watch/breath  (Phase 3 — breathing_sessions)
struct BreathList: Decodable, Sendable {
    let sessions: [BreathSession]
    let count: Int?
    let rolling_7d: Rollup?

    struct Rollup: Decodable, Sendable {
        let sessions: Int?
        let avg_hrv_delta: Double?
        let total_min: Int?
    }
}
struct BreathSession: Decodable, Sendable, Identifiable {
    let session_id: String
    let technique: String?
    let status: String?
    let target_duration_seconds: Int?
    let actual_duration_seconds: Int?
    let hrv_delta: Double?
    let started_at: String?
    let completed_at: String?
    var id: String { session_id }
}
struct BreathStart: Encodable, Sendable {
    let action = "start"
    let technique: String
    let target_duration_seconds: Int
    let target_cycles: Int?
    let pre_hrv_deviation: Double?
    let pre_stress_tier: Int?
}
struct BreathEnd: Encodable, Sendable {
    let action = "end"
    let session_id: String
    let actual_duration_seconds: Int?
    let post_hrv_deviation: Double?
    let post_stress_tier: Int?
    let effectiveness_score: Double?
}
struct BreathStartResult: Decodable, Sendable {
    let started: Bool?
    let session: BreathSession?
}
