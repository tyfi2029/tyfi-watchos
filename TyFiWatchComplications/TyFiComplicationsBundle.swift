import WidgetKit
import SwiftUI

// MARK: - Shared snapshot model (fetched from /api/watch/snapshot)
struct WatchSnapshot: Codable {
    var glucose_mg_dl: Int?
    var recovery: Int?
    var water_ml: Double?
    var steps: Int?
    var hrv: Int?
}

// MARK: - Timeline Entry
struct TyFiEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshot
}

// MARK: - Keychain token reader (matches WatchAuth.swift kSecAttrService)
private final class WatchAuthStore {
    static let shared = WatchAuthStore()
    var token: String? {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: "fyi.tyfi.watch",
            kSecAttrAccount as String: "bearerToken",
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(q as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Timeline Provider
struct TyFiProvider: TimelineProvider {
    func placeholder(in context: Context) -> TyFiEntry {
        TyFiEntry(date: Date(),
                  snapshot: WatchSnapshot(glucose_mg_dl: 92, recovery: 74,
                                          water_ml: 1200, steps: 4200, hrv: 48))
    }

    func getSnapshot(in context: Context, completion: @escaping (TyFiEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TyFiEntry>) -> Void) {
        Task {
            let snap = await fetchSnapshot()
            let entry = TyFiEntry(date: Date(), snapshot: snap)
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func fetchSnapshot() async -> WatchSnapshot {
        guard let token = WatchAuthStore.shared.token,
              let url = URL(string: "https://life.tyfi.fyi/api/watch/snapshot") else {
            return WatchSnapshot()
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return WatchSnapshot() }
        struct Envelope: Decodable {
            let ok: Bool
            let data: SnapData?
            struct SnapData: Decodable {
                let cgm: CGM?
                let readiness: Readiness?
                let water_today: WaterToday?
                let steps: Int?
                struct CGM: Decodable { let glucose_mg_dl: Int? }
                struct Readiness: Decodable { let recovery: Int?; let hrv: Int? }
                struct WaterToday: Decodable { let ml: Double? }
            }
        }
        guard let env = try? JSONDecoder().decode(Envelope.self, from: data),
              env.ok, let d = env.data else { return WatchSnapshot() }
        return WatchSnapshot(
            glucose_mg_dl: d.cgm?.glucose_mg_dl,
            recovery: d.readiness?.recovery,
            water_ml: d.water_today?.ml,
            steps: d.steps,
            hrv: d.readiness?.hrv
        )
    }
}

// MARK: - Glucose Widget
struct GlucoseWidget: Widget {
    let kind = "TyFiGlucose"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TyFiProvider()) { entry in
            GlucoseView(entry: entry).containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Glucose")
        .description("Live CGM reading")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

struct GlucoseView: View {
    let entry: TyFiEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        let g = entry.snapshot.glucose_mg_dl
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(g.map { "\($0)" } ?? "—")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("mg/dL").font(.system(size: 9))
                }
            }
        case .accessoryCorner:
            Text(g.map { "\($0)" } ?? "—")
                .font(.system(size: 16, weight: .bold))
        default:
            Text(g.map { "Glucose: \($0) mg/dL" } ?? "Glucose: —")
        }
    }
}

// MARK: - Recovery Widget
struct RecoveryWidget: Widget {
    let kind = "TyFiRecovery"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TyFiProvider()) { entry in
            RecoveryView(entry: entry).containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Recovery")
        .description("Daily readiness score")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

struct RecoveryView: View {
    let entry: TyFiEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        let r = entry.snapshot.recovery
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Gauge(value: Double(r ?? 0) / 100) {
                    Image(systemName: "heart.fill")
                } currentValueLabel: {
                    Text(r.map { "\($0)" } ?? "—")
                }
                .gaugeStyle(.accessoryCircular)
            }
        default:
            Text(r.map { "Readiness \($0)%" } ?? "Readiness: —")
        }
    }
}

// MARK: - Steps Widget
struct StepsWidget: Widget {
    let kind = "TyFiSteps"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TyFiProvider()) { entry in
            Text(entry.snapshot.steps.map { "\($0)" } ?? "—")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Steps")
        .description("Today's step count")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

// MARK: - Water Widget
struct WaterWidget: Widget {
    let kind = "TyFiWater"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TyFiProvider()) { entry in
            let oz = Int((entry.snapshot.water_ml ?? 0) / 29.5738)
            Text("\(oz) oz")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Water")
        .description("Today's hydration")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

// MARK: - HRV Widget
struct HRVWidget: Widget {
    let kind = "TyFiHRV"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TyFiProvider()) { entry in
            Text(entry.snapshot.hrv.map { "\($0)" } ?? "—")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("HRV")
        .description("Heart rate variability")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

// MARK: - Bundle entry point
@main
struct TyFiComplicationsBundle: WidgetBundle {
    var body: some Widget {
        GlucoseWidget()
        RecoveryWidget()
        StepsWidget()
        WaterWidget()
        HRVWidget()
    }
}
