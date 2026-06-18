import SwiftUI

@MainActor
final class LiveSensorsModel: ObservableObject {
    @Published var collectingSeconds = 0
    @Published var active = true
    /// Glucose is the only network-sourced tile (CGM via /snapshot); HK tiles stream
    /// directly off `HealthKitManager`. LoadState drives just the glucose tile.
    @Published var glucose: LoadState<Int> = .loading
    private var ticker: Timer?

    func start() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if self.active { self.collectingSeconds += 1 }
            }
        }
    }

    func loadGlucose() async {
        glucose = .loading
        do {
            let snap = try await API.shared.get("/api/watch/snapshot", as: Snapshot.self)
            if let mgdl = snap.cgm?.glucose_mg_dl {
                glucose = .loaded(mgdl)
            } else {
                glucose = .empty
            }
        } catch APIError.notAuthed {
            glucose = .failed("Pair watch to sync")
        } catch {
            glucose = .failed("Offline")
        }
    }

    func toggle() { active.toggle() }

    var collectingDisplay: String {
        let h = collectingSeconds / 3600
        let m = (collectingSeconds % 3600) / 60
        let s = collectingSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

/// Screen 14 — Live Sensors.
/// Layout: collecting header (pulsing red dot + timer) → 2×3 tile grid → pause/resume.
struct LiveSensorsView: View {
    @StateObject private var model = LiveSensorsModel()
    @ObservedObject private var hk = HealthKitManager.shared
    @EnvironmentObject var units: Units

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with collecting indicator
                HStack {
                    HStack(spacing: 9) {
                        Circle()
                            .fill(model.active ? Tokens.C.bad : Tokens.C.ink3)
                            .frame(width: 9, height: 9)
                            .opacity(model.active ? 1 : 1)
                            .animation(
                                model.active
                                    ? .easeInOut(duration: 1.3).repeatForever(autoreverses: true)
                                    : .default,
                                value: model.active)
                        Text(model.active
                             ? "Collecting · \(model.collectingDisplay)"
                             : "Paused")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Tokens.C.ink2)
                        + Text(model.active ? "" : "")
                    }
                    Spacer()
                    Button {
                        model.toggle()
                    } label: {
                        Text(model.active ? "Pause" : "Resume")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Tokens.C.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Tokens.C.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // 2×3 tile grid
                let cols = [GridItem(.flexible(), spacing: Tokens.S.gap),
                            GridItem(.flexible(), spacing: Tokens.S.gap)]
                LazyVGrid(columns: cols, spacing: Tokens.S.gap) {
                    sensorTile(kicker: "Heart Rate",
                               value: hk.heartRate.map { "\(Int($0))" } ?? "—",
                               unit: "bpm",
                               icon: "heart.fill",
                               color: Tokens.C.bad)
                    sensorTile(kicker: "HRV",
                               value: hk.hrv.map { "\(Int($0))" } ?? "—",
                               unit: "ms",
                               icon: "waveform.path.ecg",
                               color: Tokens.C.warn)
                    sensorTile(kicker: "Skin Temp",
                               value: skinTempDisplay,
                               unit: units.celsius ? "°C" : "°F",
                               icon: "thermometer.medium",
                               color: Tokens.C.good)
                    sensorTile(kicker: "Glucose",
                               value: glucoseDisplay,
                               unit: "mg/dL",
                               icon: "waveform",
                               color: Tokens.C.good)
                    sensorTile(kicker: "SpO₂",
                               value: hk.spo2.map { "\(Int($0 * 100))" } ?? "—",
                               unit: "%",
                               icon: "lungs.fill",
                               color: Tokens.C.cool)
                    sensorTile(kicker: "Motion",
                               value: hk.steps.map { "\($0)" } ?? "—",
                               unit: "steps",
                               icon: "figure.walk",
                               color: Tokens.C.ink2)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.bottom, 10)

                // Footer caption
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.C.good)
                    Text("On-device · streaming to TyFi · 18 signals")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.C.ink3)
                }
                .padding(.bottom, 16)
            }
        }
        .background(Tokens.C.bg)
        .task {
            await HealthKitManager.shared.requestAuth()
            HealthKitManager.shared.start()
            model.start()
            await model.loadGlucose()
        }
    }

    private var glucoseDisplay: String {
        switch model.glucose {
        case .loaded(let mgdl): return "\(mgdl)"
        case .loading:          return "…"
        case .empty, .failed:   return "—"
        }
    }

    private var skinTempDisplay: String {
        guard let c = hk.skinTempC else { return "—" }
        return units.celsius
            ? String(format: "%.1f", c)
            : String(format: "%.1f", c * 9 / 5 + 32)
    }

    @ViewBuilder
    private func sensorTile(kicker: String, value: String, unit: String,
                             icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Kicker label: single line, scales down to 9pt minimum
                Text(kicker)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Tokens.C.ink3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: max(22, WatchScreen.width * 0.068), weight: .bold).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Tokens.C.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .truncationMode(.tail)
                Text(unit)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Tokens.C.ink3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kicker), \(value) \(unit)")
    }
}

#Preview { LiveSensorsView().environmentObject(Units.shared) }

