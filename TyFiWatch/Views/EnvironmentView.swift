import SwiftUI

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

/// Screen 24 — Environment.
/// Layout: 2×2 tile grid (AQI / UV / Pollen / Noise) → ambient row → advisory card.
struct EnvironmentView: View {
    @StateObject private var model = EnvironmentModel()
    @EnvironmentObject var units: Units

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Tokens.C.good)
                        Text("Environment")
                            .font(.system(size: 19, weight: .semibold))
                    }
                    Spacer()
                    Text("9:41")
                        .font(.system(size: 21, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.accent)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 10)
                .padding(.bottom, 12)

                if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let d = model.report {
                    VStack(spacing: Tokens.S.gap) {
                        // 2×2 primary tile grid
                        let cols = [GridItem(.flexible(), spacing: Tokens.S.gap),
                                    GridItem(.flexible(), spacing: Tokens.S.gap)]
                        LazyVGrid(columns: cols, spacing: Tokens.S.gap) {
                            envTile(kicker: "AQI",
                                    value: d.air_quality?.aqi != nil ? "\(Int(d.air_quality!.aqi!))" : "—",
                                    statusLabel: d.air_quality?.category ?? "—",
                                    color: aqiColor(d.air_quality?.aqi))

                            envTile(kicker: "UV Index",
                                    value: d.uv?.index != nil ? "\(Int(d.uv!.index!))" : "—",
                                    statusLabel: d.uv?.category ?? "—",
                                    color: uvColor(d.uv?.index))

                            envTile(kicker: "Pollen",
                                    value: d.pollen?.dominant ?? "—",
                                    statusLabel: d.pollen?.level?.capitalized ?? "—",
                                    color: pollenColor(d.pollen?.level))

                            envTile(kicker: "Noise dB",
                                    value: d.noise?.env_db != nil ? "\(Int(d.noise!.env_db!))" : "—",
                                    statusLabel: noiseLabel(d.noise?.env_db),
                                    color: noiseColor(d.noise?.env_db))
                        }
                        .padding(.horizontal, Tokens.S.hPad)

                        // Ambient row (temp / humidity / wind / pressure)
                        ambientRow(d)
                            .padding(.horizontal, Tokens.S.hPad)

                        // Advisory
                        if let adv = d.advisory {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Tokens.C.warn)
                                Text(adv)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Tokens.C.ink2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Tokens.C.warn.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                            .padding(.horizontal, Tokens.S.hPad)
                        }
                    }
                    .padding(.bottom, 16)
                } else {
                    Text(model.error ?? "No environment data")
                        .font(Type.caption).foregroundStyle(Tokens.C.ink3)
                        .padding()
                }
            }
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    // MARK: — Tile builder
    @ViewBuilder
    private func envTile(kicker: String, value: String, statusLabel: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            KickerLabel(text: kicker)
            Text(value)
                .font(.system(size: 28, weight: .semibold).monospacedDigit())
                .foregroundStyle(Tokens.C.ink)
            Text(statusLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.16), in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
    }

    // MARK: — Ambient row
    @ViewBuilder
    private func ambientRow(_ d: EnvironmentReport) -> some View {
        HStack(spacing: 0) {
            ambientCell(icon: "thermometer", label: "Temp",
                        value: units.celsius ? "72°C" : "72°F")
            hairlineDiv
            ambientCell(icon: "humidity.fill", label: "Humidity", value: "34%")
            hairlineDiv
            ambientCell(icon: "wind", label: "Wind", value: "8 mph")
            hairlineDiv
            ambientCell(icon: "barometer", label: "Pressure", value: "29.9")
        }
        .padding(.vertical, 12)
        .background(Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
    }

    @ViewBuilder
    private func ambientCell(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Tokens.C.ink3)
            Text(value)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(Tokens.C.ink)
            KickerLabel(text: label, size: 9)
        }
        .frame(maxWidth: .infinity)
    }

    private var hairlineDiv: some View {
        Rectangle().fill(Tokens.C.hairline).frame(width: 1, height: 32)
    }

    // MARK: — Color helpers
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
        switch level { case "very_high","high": return Tokens.C.bad; case "moderate": return Tokens.C.warn; default: return Tokens.C.good }
    }
    private func noiseLabel(_ db: Double?) -> String {
        guard let db else { return "—" }
        if db > 85 { return "Loud" }
        if db > 70 { return "Moderate" }
        return "Quiet"
    }
    private func noiseColor(_ db: Double?) -> Color {
        guard let db else { return Tokens.C.ink }
        if db > 85 { return Tokens.C.bad }
        if db > 70 { return Tokens.C.warn }
        return Tokens.C.good
    }
}

#Preview { EnvironmentView().environmentObject(Units.shared) }
