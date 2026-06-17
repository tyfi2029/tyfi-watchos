@preconcurrency import WidgetKit
import SwiftUI

// MARK: - Design Tokens

private extension Color {
    static let tyAccent  = Color(red: 0.878, green: 0.506, blue: 0.243)  // #e0813e
    static let tyWarn    = Color(red: 0.878, green: 0.631, blue: 0.302)  // #e0a14d
    static let tyGood    = Color(red: 0.373, green: 0.722, blue: 0.561)  // #5fb88f
    static let tyCool    = Color(red: 0.478, green: 0.663, blue: 0.812)  // #7aa9cf
    static let tyBad     = Color(red: 0.878, green: 0.443, blue: 0.443)  // #e07171
    static let tyInk     = Color.white
    static let tyInk2    = Color.white.opacity(0.60)
    static let tyInk3    = Color.white.opacity(0.34)
}

// MARK: - Color Helpers

private func glucoseColor(_ v: Int?) -> Color {
    guard let v else { return .tyInk }
    if v < 70 || v > 180 { return .tyBad }
    if (v >= 70 && v < 80) || (v >= 140 && v <= 180) { return .tyWarn }
    return .tyGood
}

private func trendArrow(_ t: String?) -> String {
    switch t {
    case "rising_rapidly":  return "↑↑"
    case "rising":          return "↑"
    case "falling_rapidly": return "↓↓"
    case "falling":         return "↓"
    default:                return "→"
    }
}

private func recoveryColor(_ v: Int?) -> Color {
    guard let v else { return .tyBad }
    if v >= 67 { return .tyGood }
    if v >= 34 { return .tyWarn }
    return .tyBad
}

// MARK: - Snapshot Model

struct WatchSnapshot: Codable, Sendable {
    var glucose_mg_dl: Int?
    var glucose_trend: String?
    var recovery: Int?
    var water_ml: Double?
    var water_goal_ml: Double?
    var protocol_done: Int?
    var protocol_total: Int?
    var next_title: String?
    var next_eta_min: Int?
    var steps: Int?
    var hrv: Int?
}

// MARK: - Placeholder

private extension WatchSnapshot {
    static let placeholder = WatchSnapshot(
        glucose_mg_dl: 88,
        glucose_trend: "rising",
        recovery: 72,
        water_ml: 1600,
        water_goal_ml: 2500,
        protocol_done: 3,
        protocol_total: 9,
        next_title: "Cold plunge",
        next_eta_min: 41,
        steps: 6400,
        hrv: 47
    )
}

// MARK: - Timeline Entry

struct TyFiEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshot
}

// MARK: - Keychain Token Reader

private final class WatchAuthStore: @unchecked Sendable {
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

// MARK: - Network Fetch

private func fetchSnapshot() async -> WatchSnapshot {
    guard
        let token = WatchAuthStore.shared.token,
        let url = URL(string: "https://life.tyfi.fyi/api/watch/snapshot")
    else { return .placeholder }

    var req = URLRequest(url: url)
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    guard
        let (data, _) = try? await URLSession.shared.data(for: req)
    else { return .placeholder }

    struct Envelope: Decodable {
        let ok: Bool
        let data: SnapData?
        struct SnapData: Decodable {
            let cgm: CGM?
            let readiness: Readiness?
            let water_today: WaterToday?
            let protocol_progress: ProtocolProgress?
            let dol_next: DolNext?
            let steps: Int?
            struct CGM: Decodable {
                let glucose_mg_dl: Int?
                let trend: String?
            }
            struct Readiness: Decodable {
                let recovery: Int?
                let hrv: Int?
            }
            struct WaterToday: Decodable {
                let ml: Double?
                let goal_ml: Double?
            }
            struct ProtocolProgress: Decodable {
                let done: Int?
                let total: Int?
            }
            struct DolNext: Decodable {
                let title: String?
                let due_at: String?
            }
        }
    }

    guard
        let env = try? JSONDecoder().decode(Envelope.self, from: data),
        env.ok,
        let d = env.data
    else { return .placeholder }

    var etaMin: Int? = nil
    if let dueStr = d.dol_next?.due_at {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var due: Date? = fmt.date(from: dueStr)
        if due == nil {
            let fmt2 = ISO8601DateFormatter()
            fmt2.formatOptions = [.withInternetDateTime]
            due = fmt2.date(from: dueStr)
        }
        if let due, due > Date() {
            let comps = Calendar.current.dateComponents([.minute], from: Date(), to: due)
            etaMin = comps.minute
        }
    }

    return WatchSnapshot(
        glucose_mg_dl:   d.cgm?.glucose_mg_dl,
        glucose_trend:   d.cgm?.trend,
        recovery:        d.readiness?.recovery,
        water_ml:        d.water_today?.ml,
        water_goal_ml:   d.water_today?.goal_ml,
        protocol_done:   d.protocol_progress?.done,
        protocol_total:  d.protocol_progress?.total,
        next_title:      d.dol_next?.title,
        next_eta_min:    etaMin,
        steps:           d.steps,
        hrv:             d.readiness?.hrv
    )
}

// MARK: - Timeline Provider

struct TyFiProvider: TimelineProvider {
    func placeholder(in context: Context) -> TyFiEntry {
        TyFiEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TyFiEntry) -> Void) {
        completion(TyFiEntry(date: Date(), snapshot: .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TyFiEntry>) -> Void) {
        let task = Task {
            let snap = await fetchSnapshot()
            let entry = TyFiEntry(date: Date(), snapshot: snap)
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
        _ = task
    }
}

// MARK: - Water Formatting

private func waterLabel(_ ml: Double?) -> String {
    guard let ml else { return "—" }
    if ml >= 1000 {
        let l = ml / 1000.0
        return String(format: l.truncatingRemainder(dividingBy: 1) == 0 ? "%.0fL" : "%.1fL", l)
    }
    return "\(Int(ml))ml"
}

// MARK: - GlucoseWidget

struct GlucoseWidget: Widget {
    let kind = "TyFiGlucose"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TyFiProvider()) { entry in
            GlucoseView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Glucose")
        .description("Live CGM reading with trend")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct GlucoseView: View {
    let entry: TyFiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let g     = entry.snapshot.glucose_mg_dl
        let trend = entry.snapshot.glucose_trend
        let color = glucoseColor(g)
        let arrow = trendArrow(trend)
        let gStr  = g.map { "\($0)" } ?? "—"

        switch family {

        case .accessoryRectangular:
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(gStr)
                            .font(.system(size: 36, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(color)
                        Text(arrow)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(color)
                    }
                    Text("mg/dL")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.tyInk3)
                }
                Spacer(minLength: 0)
                Gauge(value: Double(g ?? 60), in: 60...200) {
                    Text("")
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(color)
                .frame(maxWidth: 72)
            }

        case .accessoryCircular:
            Gauge(value: Double(g ?? 60), in: 60...200) {
                Text("")
            } currentValueLabel: {
                Text(gStr)
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)

        case .accessoryCorner:
            Text("\(gStr)\(arrow)")
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .widgetLabel {
                    Text("mg/dL")
                        .foregroundStyle(Color.tyInk3)
                }

        default:
            Text("\(gStr) \(arrow) mg/dL")
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

// MARK: - RecoveryWidget

struct RecoveryWidget: Widget {
    let kind = "TyFiRecovery"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TyFiProvider()) { entry in
            RecoveryView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Recovery")
        .description("Daily readiness score")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
        ])
    }
}

struct RecoveryView: View {
    let entry: TyFiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let r     = entry.snapshot.recovery
        let color = recoveryColor(r)
        let rStr  = r.map { "\($0)" } ?? "—"

        switch family {

        case .accessoryCircular:
            Gauge(value: Double(r ?? 0), in: 0...100) {
                Text("")
            } currentValueLabel: {
                Text(rStr)
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            } minimumValueLabel: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(color)
            } maximumValueLabel: {
                Text("")
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)

        case .accessoryCorner:
            Image(systemName: "bolt.fill")
                .foregroundStyle(color)
                .widgetLabel {
                    Gauge(value: Double(r ?? 0), in: 0...100) {
                        Text("")
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(color)
                }

        default:
            Text("Readiness \(rStr)%")
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

// MARK: - WaterWidget

struct WaterWidget: Widget {
    let kind = "TyFiWater"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TyFiProvider()) { entry in
            WaterView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Hydration")
        .description("Today's water intake")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
        ])
    }
}

struct WaterView: View {
    let entry: TyFiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let ml       = entry.snapshot.water_ml
        let goalMl   = entry.snapshot.water_goal_ml ?? 2500
        let progress = min(max((ml ?? 0) / goalMl, 0), 1)
        let label    = waterLabel(ml)
        let goalLbl  = waterLabel(goalMl)

        switch family {

        case .accessoryCircular:
            Gauge(value: progress) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(Color.tyCool)
            } currentValueLabel: {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.tyCool)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Color.tyCool)

        case .accessoryCorner:
            Image(systemName: "drop.fill")
                .foregroundStyle(Color.tyCool)
                .widgetLabel {
                    Gauge(value: progress) {
                        Text(label)
                            .monospacedDigit()
                            .foregroundStyle(Color.tyCool)
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(Color.tyCool)
                }

        default:
            Text("💧 \(label) / \(goalLbl)")
                .monospacedDigit()
                .foregroundStyle(Color.tyCool)
        }
    }
}

// MARK: - ProtocolWidget

struct ProtocolWidget: Widget {
    let kind = "TyFiProtocol"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TyFiProvider()) { entry in
            ProtocolView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Protocol")
        .description("Daily protocol completion")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
        ])
    }
}

struct ProtocolView: View {
    let entry: TyFiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let done     = entry.snapshot.protocol_done ?? 0
        let total    = entry.snapshot.protocol_total ?? 1
        let progress = Double(done) / Double(max(total, 1))
        let complete = done == total && total > 0
        let color: Color = complete ? .tyGood : .tyWarn
        let doneStr  = "\(done)"

        switch family {

        case .accessoryCircular:
            Gauge(value: progress) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(color)
            } currentValueLabel: {
                Text(doneStr)
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)

        case .accessoryCorner:
            Image(systemName: "list.bullet.clipboard")
                .foregroundStyle(color)
                .widgetLabel {
                    Gauge(value: progress) {
                        Text("\(done)/\(total)")
                            .monospacedDigit()
                            .foregroundStyle(color)
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(color)
                }

        default:
            Text("✓ \(done)/\(total) protocol")
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

// MARK: - NextWidget

struct NextWidget: Widget {
    let kind = "TyFiNext"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TyFiProvider()) { entry in
            NextView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Next Item")
        .description("Your next scheduled protocol item")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct NextView: View {
    let entry: TyFiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let title = entry.snapshot.next_title
        let eta   = entry.snapshot.next_eta_min

        switch family {

        case .accessoryRectangular:
            if let title, let eta {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("NEXT")
                            .font(.system(size: 10))
                            .tracking(1.2)
                            .foregroundStyle(Color.tyInk3)
                        Spacer()
                        Text("IN \(eta)M")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.tyAccent)
                    }
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.tyInk)
                        .lineLimit(2)
                }
            } else {
                Text("No items · on track")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.tyInk2)
            }

        default:
            if let title, let eta {
                Text("In \(eta)m · \(title)")
                    .monospacedDigit()
                    .foregroundStyle(Color.tyAccent)
            } else {
                Text("On track")
                    .foregroundStyle(Color.tyInk2)
            }
        }
    }
}

// MARK: - HRVWidget

struct HRVWidget: Widget {
    let kind = "TyFiHRV"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TyFiProvider()) { entry in
            HRVView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("HRV")
        .description("Heart rate variability")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryInline,
        ])
    }
}

struct HRVView: View {
    let entry: TyFiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let hrv    = entry.snapshot.hrv
        let hrvStr = hrv.map { "\($0)" } ?? "—"

        switch family {

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text(hrvStr)
                        .font(.system(size: 18, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.tyInk)
                    Text("HRV")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.tyInk3)
                }
            }

        default:
            Text("HRV \(hrvStr) ms")
                .monospacedDigit()
                .foregroundStyle(Color.tyInk)
        }
    }
}

// MARK: - Bundle Entry Point

@main
struct TyFiComplicationsBundle: WidgetBundle {
    var body: some Widget {
        GlucoseWidget()
        RecoveryWidget()
        WaterWidget()
        ProtocolWidget()
        NextWidget()
        HRVWidget()
    }
}