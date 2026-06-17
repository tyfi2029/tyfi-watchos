import SwiftUI

/// Environment — /api/watch/environment (watch-auth; AQI, UV, pollen, noise advisory).
/// Uses EnvironmentReport from Models.swift — verified frozen contract 2026-06-14.
@MainActor
final class EnvironmentModel: ObservableObject {
    @Published var report: EnvironmentReport?
    @Published var error: String?
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        do { report = try await API.shared.get("/api/watch/environment", as: EnvironmentReport.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }
}

struct EnvironmentView: View {
    @StateObject private var model = EnvironmentModel()
    @EnvironmentObject var units: Units

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                HStack {
                    Image(systemName: "leaf.circle").foregroundStyle(Tokens.C.good)
                    Text("Environment").font(Type.label).foregroundStyle(Tokens.C.ink)
                    Spacer()
                }
                if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else if let d = model.report {
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
                        if let steps = d.steps {
                            StatTile(label: "Steps",
                                     value: "\(Int(steps))",
                                     color: Tokens.C.accent)
                        }
                    }
                    if let adv = d.advisory {
                        Card {
                            Text(adv).font(Type.caption).foregroundStyle(Tokens.C.ink2)
                        }
                    }
                } else {
                    Text(model.error ?? "No environment data").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                }
            }
            .padding(Tokens.S.gutter)
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
        switch level {
        case "high", "very_high": return Tokens.C.bad
        case "moderate": return Tokens.C.warn
        default: return Tokens.C.good
        }
    }
}

#Preview { EnvironmentView().environmentObject(Units.shared) }
