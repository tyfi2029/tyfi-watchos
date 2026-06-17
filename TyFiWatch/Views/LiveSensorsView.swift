import SwiftUI

/// Live sensors — environment data from /api/watch/environment plus
/// live HealthKit readings (HR, HRV, SpO2, skin temp, steps, calories).
@MainActor
final class EnvModel: ObservableObject {
    @Published var env: EnvironmentReport?
    @Published var error: String?
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        do { env = try await API.shared.get("/api/watch/environment", as: EnvironmentReport.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }
}

struct LiveSensorsView: View {
    @StateObject private var model = EnvModel()
    @ObservedObject private var hk = HealthKitManager.shared
    @EnvironmentObject var units: Units

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.S.gutter) {
                Text("LIVE SENSORS").font(Type.label).foregroundStyle(Tokens.C.ink3)

                // HealthKit live readings grid
                let cols = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: cols, spacing: Tokens.S.gutter) {
                    hrTile
                    hrvTile
                    spo2Tile
                    skinTempTile
                    stepsTile
                    calorieTile
                }

                Text("ENVIRONMENT").font(Type.label).foregroundStyle(Tokens.C.ink3)
                    .padding(.top, 4)

                if let e = model.env {
                    LazyVGrid(columns: cols, spacing: Tokens.S.gutter) {
                        StatTile(label: "AQI", value: e.air_quality?.aqi != nil ? "\(Int(e.air_quality!.aqi!))" : "—",
                                 color: aqiColor(e.air_quality?.aqi))
                        StatTile(label: "UV", value: e.uv?.index != nil ? "\(Int(e.uv!.index!))" : "—",
                                 color: uvColor(e.uv?.index))
                        StatTile(label: "Noise", value: e.noise?.env_db != nil ? "\(Int(e.noise!.env_db!))" : "—",
                                 unit: "dB", color: Tokens.C.cool)
                        StatTile(label: "Steps (API)", value: e.steps != nil ? "\(Int(e.steps!))" : "—", color: Tokens.C.accent)
                    }
                    if let p = e.pollen, p.level != nil {
                        StatTile(label: "Pollen \(p.dominant ?? "")", value: (p.level ?? "—").capitalized,
                                 color: pollenColor(p.level))
                    }
                    if let adv = e.advisory {
                        Card {
                            Text(adv).font(Type.caption).foregroundStyle(Tokens.C.ink2)
                        }
                    }
                } else if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else {
                    Text(model.error ?? "No environment data").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                }
            }
            .padding(.horizontal, 6)
        }
        .background(Tokens.C.bg)
        .task {
            await HealthKitManager.shared.requestAuth()
            HealthKitManager.shared.start()
            await model.load()
        }
    }

    // MARK: - HealthKit tiles

    private var hrTile: some View {
        StatTile(
            label: "Heart Rate",
            value: hk.heartRate.map { "\(Int($0))" } ?? "—",
            unit: hk.heartRate != nil ? "bpm" : nil,
            color: hrColor(hk.heartRate)
        )
    }

    private var hrvTile: some View {
        StatTile(
            label: "HRV",
            value: hk.hrv.map { "\(Int($0))" } ?? "—",
            unit: hk.hrv != nil ? "ms" : nil,
            color: Tokens.C.cool
        )
    }

    private var spo2Tile: some View {
        let pct = hk.spo2.map { Int($0 * 100) }
        return StatTile(
            label: "SpO2",
            value: pct.map { "\($0)" } ?? "—",
            unit: pct != nil ? "%" : nil,
            color: spo2Color(hk.spo2)
        )
    }

    private var skinTempTile: some View {
        let display: String
        if let c = hk.skinTempC {
            display = units.celsius
                ? String(format: "%.1f", c)
                : String(format: "%.1f", c * 9 / 5 + 32)
        } else {
            display = "—"
        }
        return StatTile(
            label: "Skin Temp",
            value: display,
            unit: hk.skinTempC != nil ? (units.celsius ? "°C" : "°F") : nil,
            color: Tokens.C.warn
        )
    }

    private var stepsTile: some View {
        StatTile(
            label: "Steps",
            value: hk.steps.map { "\($0)" } ?? "—",
            color: Tokens.C.accent
        )
    }

    private var calorieTile: some View {
        StatTile(
            label: "Active Cal",
            value: hk.activeCalories.map { "\(Int($0))" } ?? "—",
            unit: hk.activeCalories != nil ? "kcal" : nil,
            color: Tokens.C.good
        )
    }

    // MARK: - Color helpers

    private func hrColor(_ v: Double?) -> Color {
        guard let v else { return Tokens.C.ink }
        if v > 170 { return Tokens.C.bad }
        if v > 150 { return Tokens.C.warn }
        return Tokens.C.good
    }

    private func spo2Color(_ v: Double?) -> Color {
        guard let v else { return Tokens.C.ink }
        if v < 0.94 { return Tokens.C.bad }
        if v < 0.96 { return Tokens.C.warn }
        return Tokens.C.good
    }

    private func aqiColor(_ v: Double?) -> Color {
        guard let v else { return Tokens.C.ink }
        if v > 150 { return Tokens.C.bad }
        if v > 100 { return Tokens.C.warn }
        return Tokens.C.good
    }
    private func uvColor(_ v: Double?) -> Color {
        guard let v else { return Tokens.C.ink }
        if v >= 8 { return Tokens.C.bad }
        if v >= 6 { return Tokens.C.warn }
        return Tokens.C.good
    }
    private func pollenColor(_ level: String?) -> Color {
        switch level { case "very_high", "high": return Tokens.C.bad; case "moderate": return Tokens.C.warn; default: return Tokens.C.good }
    }
}

#Preview { LiveSensorsView().environmentObject(Units.shared) }
