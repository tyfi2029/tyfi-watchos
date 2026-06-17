import Foundation

// Models mirror the wmp watch contract verified 2026-06-14 (origin/master).
// All Sendable so they can cross the API actor boundary.

// MARK: /api/watch/snapshot
struct Snapshot: Codable, Sendable {
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

    struct CGM: Codable, Sendable {
        let glucose_mg_dl: Int?
        let trend: String?
        let fresh_seconds_ago: Int?
    }
    struct Readiness: Codable, Sendable {
        let recovery: Int?
        let hrv: Int?
        let sleep: Int?
        let rhr: Int?
        let focus: String?
    }
    struct DOLNext: Codable, Sendable {
        let id: String?
        let title: String?
        let due_at: String?
    }
    struct ProtocolProgress: Codable, Sendable {
        let done: Int?
        let total: Int?
        let current_segment: String?
        let next_segment_at: String?
    }
    struct ThermalSession: Codable, Sendable {
        let mode: String?
        let completed_at: String?
        let duration_sec: Int?
        let temp_f: Double?
    }
}

// MARK: /api/watch/hydration/today
struct WaterToday: Codable, Sendable {
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
// NOTE: groupBySegment returns camelCase keys (rangeStart, rangeEnd, tempF).
// Swift field names already match — no CodingKeys needed.
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

// MARK: /api/watch/hydration/brands
struct HydrationBrands: Decodable, Sendable {
    let brands: [HydrationBrand]?
}
struct HydrationBrand: Decodable, Sendable, Identifiable {
    let id: Int?
    let name: String?
    let oasis_score: Double?
    let oasis_rating: String?
    let last_used_at: String?
}

// MARK: /api/watch/session/start  (POST body + result)
struct SessionStartBody: Encodable, Sendable {
    let mode: String            // "cold" | "sauna"
    let temp_f: Double
    let target_sec: Int
    let started_at: String
    let backfill_sec: Int?
    let detection_source: String?
    let detection_score: Double?
}
struct SessionStartResult: Decodable, Sendable {
    let session_id: Int?
}

// MARK: /api/watch/session/end  (POST body + result)
struct SessionEndBody: Encodable, Sendable {
    let session_id: Int
    let elapsed_sec: Int
    let ended_at: String
    let hr_avg: Double?
    let hr_peak: Double?
    let completion_status: String?
}
struct SessionEndResult: Decodable, Sendable {
    let session_id: Int?
    let total_duration: Int?
    let status: String?
}

// MARK: /api/watch/nutrition
struct NutritionData: Decodable, Sendable {
    let today: MacroTotals?
    let glucose: NutritionGlucose?
    let targets: MacroTargets?

    struct MacroTotals: Decodable, Sendable {
        let calories: Int?
        let protein: Int?
        let carbs: Int?
        let fat: Int?
        let meal_count: Int?
        let last_logged: String?
    }
    struct NutritionGlucose: Decodable, Sendable {
        let glucose: Int?
        let trend: String?
        let seconds_ago: Int?
    }
    struct MacroTargets: Decodable, Sendable {
        let calories: Int?
        let protein: Int?
        let carbs: Int?
        let fat: Int?
    }
}

// MARK: /api/watch/flight
struct FlightData: Decodable, Sendable {
    let active_flight: ActiveFlight?
    let jetlag: JetlagData?

    struct ActiveFlight: Decodable, Sendable {
        let flight_number: String?
        let origin: String?
        let destination: String?
        let departure_at: String?
        let arrival_at: String?
        let status: String?
    }
    struct JetlagData: Decodable, Sendable {
        let direction: String?
        let hours_shifted: Double?
        let recovery_day: Int?
    }
}

// MARK: /api/watch/home
struct HomeData: Decodable, Sendable {
    let scenes: [HomeScene]?
}
struct HomeScene: Decodable, Sendable, Identifiable {
    let id: Int?
    let name: String?
    let label: String?
    let icon: String?
}
struct HomeTriggerBody: Encodable, Sendable {
    let routine_id: Int
}
struct HomeTriggerResult: Decodable, Sendable {
    let triggered: Bool?
    let routine: String?
}

// MARK: /api/watch/venue/nearby
struct VenueList: Decodable, Sendable {
    let venues: [Venue]?
}
struct Venue: Decodable, Sendable, Identifiable {
    let id: Int?
    let name: String?
    let distance_mi: Double?
    let open_status: String?
    let last_visited_at: String?
}

// MARK: /api/watch/venue/checkin  (POST body + result)
struct VenueCheckinBody: Encodable, Sendable {
    let venue_id: Int
    let checked_in_at: String
    let lat: Double?
    let lng: Double?
}
struct VenueCheckinResult: Decodable, Sendable {
    let checkin_id: String?
    let venue_name: String?
}

// MARK: /api/watch/venue/rate  (POST body + result)
struct VenueRatingBody: Encodable, Sendable {
    let venue_id: Int
    let stars: Int               // 1–5
    let rated_at: String
}
struct VenueRatingResult: Decodable, Sendable {
    let venue_id: Int?
    let stars: Int?
}

// MARK: /api/watch/zone2
struct Zone2Data: Decodable, Sendable {
    let today: Zone2Period?
    let weekly: Zone2Weekly?
    let recent_sessions: [Zone2Session]?

    struct Zone2Period: Decodable, Sendable {
        let total_min: Int?
        let session_count: Int?
    }
    struct Zone2Weekly: Decodable, Sendable {
        let total_min: Int?
        let session_count: Int?
        let last_session: String?
        let target_min: Int?
        let pct: Int?
    }
    struct Zone2Session: Decodable, Sendable {
        let activity_type: String?
        let zone2_minutes: Int?
        let duration_minutes: Int?
        let avg_hr: Double?
        let started_at: String?
        let source_name: String?
    }
}

// MARK: /api/watch/winddown
struct WindDownData: Decodable, Sendable {
    let eight_sleep: EightSleepStatus?
    let checklist: [WindDownItem]?
    let scene: String?

    struct EightSleepStatus: Decodable, Sendable {
        let bedTempF: Double?
        let targetTempF: Double?
        let isOn: Bool?
    }
    struct WindDownItem: Decodable, Sendable, Identifiable {
        let id: String?
        let label: String?
        let done: Bool?
    }
}
struct WindDownSetTempBody: Encodable, Sendable {
    let action = "set_temp"
    let temp_f: Double
}
struct WindDownSetTempResult: Decodable, Sendable {
    let set: Bool?
    let temp_f: Double?
}

// MARK: /api/watch/capture/voice  (POST body + result)
// Single struct covers voice, meal, nfc, paste — all routes return { capture_id }
struct VoiceCaptureBody: Encodable, Sendable {
    let transcript: String
    let idempotency_key: String
    let tags: [String]?
    let duration_sec: Double?
    let captured_at: String?
    let audio_blob_b64: String?
}
struct CaptureResult: Decodable, Sendable {
    let capture_id: String?
}

// MARK: /api/watch/quick-log  (POST body + result)
struct QuickLogBody: Encodable, Sendable {
    let category: String
    let text: String?
    let logged_at: String?
    let metadata: [String: String]?
}
struct QuickLogResult: Decodable, Sendable {
    let id: String?
    let logged_at: String?
    let category: String?
}
// MARK: /api/watch/capture/voice  (POST body — CaptureBody)
// Required fields: transcript, idempotency_key. Optional: category_hint, captured_at, metadata.
// NOTE: VoiceCaptureBody (above) is the legacy struct with tags/duration/audio; CaptureBody is
// the frozen Wave C contract body used by CaptureView and VoiceNoteView.
struct CaptureBody: Encodable, Sendable {
    var transcript: String
    var idempotency_key: String
    var category_hint: String?
    var captured_at: String?
    var metadata: [String: String]?
}

