import SwiftUI

@MainActor
final class LiveSensorsModel: ObservableObject {
    @Published var collectingSeconds = 0
    @Published var active = true
    private var ticker: Timer?

    func start() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if self.active { self.collectingSeconds += 1 }
            }
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
                               value: hk.heartRate.map { "\(Int($0))" } ?? "62",
                               unit: "bpm",
                               icon: "heart.fill",
                               color: Tokens.C.bad)
                    sensorTile(kicker: "HRV",
                               value: hk.hrv.map { "\(Int($0))" } ?? "47",
                               unit: "ms",
                               icon: "waveform.path.ecg",
                               color: Tokens.C.warn)
                    sensorTile(kicker: "Skin Temp",
                               value: skinTempDisplay,
                               unit: units.celsius ? "°C" : "°F",
                               icon: "thermometer.medium",
                               color: Tokens.C.good)
                    sensorTile(kicker: "Glucose",
                               value: "88",
                               unit: "mg/dL",
                               icon: "waveform",
                               color: Tokens.C.good)
                    sensorTile(kicker: "SpO₂",
                               value: hk.spo2.map { "\(Int($0 * 100))" } ?? "98",
                               unit: "%",
                               icon: "lungs.fill",
                               color: Tokens.C.cool)
                    sensorTile(kicker: "Motion",
                               value: hk.steps.map { "\($0)" } ?? "6.4k",
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
        }
    }

    private var skinTempDisplay: String {
        if let c = hk.skinTempC {
            return units.celsius
                ? String(format: "%.1f", c)
                : String(format: "%.1f", c * 9 / 5 + 32)
        }
        return "+0.2"
    }

    @ViewBuilder
    private func sensorTile(kicker: String, value: String, unit: String,
                             icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                KickerLabel(text: kicker)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink)
                Text(unit)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Tokens.C.ink3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview { LiveSensorsView().environmentObject(Units.shared) }
