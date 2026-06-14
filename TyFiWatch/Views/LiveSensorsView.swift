import SwiftUI

/// Live sensors / Environment — /api/watch/environment (watch-auth read side:
/// AQI, UV, pollen, noise dosimetry advisory, daylight, steps).
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.S.gutter) {
                Text("ENVIRONMENT").font(Type.label).foregroundStyle(Tokens.C.ink3)
                if let e = model.env {
                    let cols = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: cols, spacing: Tokens.S.gutter) {
                        StatTile(label: "AQI", value: e.air_quality?.aqi != nil ? "\(Int(e.air_quality!.aqi!))" : "—",
                                 color: aqiColor(e.air_quality?.aqi))
                        StatTile(label: "UV", value: e.uv?.index != nil ? "\(Int(e.uv!.index!))" : "—",
                                 color: uvColor(e.uv?.index))
                        StatTile(label: "Noise", value: e.noise?.env_db != nil ? "\(Int(e.noise!.env_db!))" : "—",
                                 unit: "dB", color: Tokens.C.cool)
                        StatTile(label: "Steps", value: e.steps != nil ? "\(Int(e.steps!))" : "—", color: Tokens.C.accent)
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
        .task { await model.load() }
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
