import SwiftUI

struct EnvironmentView: View {
    struct AirQuality: Decodable { let aqi: Double?; let category: String? }
    struct UV: Decodable { let index: Double?; let category: String? }
    struct Pollen: Decodable { let dominant: String?; let level: String? }
    struct Noise: Decodable { let env_db: Double?; let advisory: String? }
    struct Weather: Decodable { let temp_c: Double?; let humidity_pct: Double? }
    struct EnvData: Decodable {
        let air_quality: AirQuality?
        let uv: UV?
        let pollen: Pollen?
        let noise: Noise?
        let weather: Weather?
        let advisory: String?
    }

    @State private var data: EnvData?
    @State private var isLoading = true
    @EnvironmentObject var units: Units

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                HStack {
                    Image(systemName: "leaf.circle").foregroundStyle(Tokens.C.good)
                    Text("Environment").font(Type.label).foregroundStyle(Tokens.C.ink)
                    Spacer()
                }
                if isLoading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else if let d = data {
                    let cols = [GridItem(.flexible(), spacing: Tokens.S.gutter),
                                GridItem(.flexible(), spacing: Tokens.S.gutter)]
                    LazyVGrid(columns: cols, spacing: Tokens.S.gutter) {
                        if let aq = d.air_quality {
                            StatTile(label: "AQI",
                                     value: aq.aqi.map { "\(Int($0))" } ?? "—",
                                     unit: aq.category,
                                     color: aqiColor(aq.aqi))
                        }
                        if let uv = d.uv {
                            StatTile(label: "UV",
                                     value: uv.index.map { "\(Int($0))" } ?? "—",
                                     unit: uv.category,
                                     color: uvColor(uv.index))
                        }
                        if let p = d.pollen {
                            StatTile(label: "Pollen",
                                     value: p.dominant ?? "—",
                                     unit: p.level,
                                     color: pollenColor(p.level))
                        }
                        if let n = d.noise, let db = n.env_db {
                            StatTile(label: "Noise",
                                     value: "\(Int(db))",
                                     unit: "dB",
                                     color: db > 85 ? Tokens.C.bad : db > 70 ? Tokens.C.warn : Tokens.C.good)
                        }
                        if let w = d.weather {
                            if let t = w.temp_c {
                                StatTile(label: "Temp",
                                         value: units.temp(t * 9 / 5 + 32),
                                         color: Tokens.C.cool)
                            }
                            if let h = w.humidity_pct {
                                StatTile(label: "Humidity",
                                         value: "\(Int(h))",
                                         unit: "%",
                                         color: Tokens.C.cool)
                            }
                        }
                    }
                    if let adv = d.advisory {
                        Card {
                            Text(adv).font(Type.caption).foregroundStyle(Tokens.C.ink2)
                        }
                    }
                }
            }
            .padding(Tokens.S.gutter)
        }
        .background(Tokens.C.bg)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        data = try? await API.shared.get("/api/watch/environment", as: EnvData.self)
        isLoading = false
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
        switch level {
        case "high", "very_high": return Tokens.C.bad
        case "moderate": return Tokens.C.warn
        default: return Tokens.C.good
        }
    }
}

#Preview { EnvironmentView().environmentObject(Units.shared) }
