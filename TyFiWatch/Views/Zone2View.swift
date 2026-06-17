import SwiftUI
import HealthKit

@MainActor
final class Zone2Model: ObservableObject {
    @Published var data: Zone2Data?
    @Published var error: String?
    @Published var loading = false
    @Published var running = false
    @Published var elapsed = 0
    @Published var avgHR: Double?
    @Published var inZonePct: Int?
    private var ticker: Timer?
    private var hrSum = 0.0
    private var hrCount = 0
    private var inZoneCount = 0

    /// Z1–Z5 from %max-HR. Shared by the model (accumulation) and the view (display).
    static func zone(for hr: Double, maxHR: Double = 185) -> Int {
        switch hr / maxHR {
        case ..<0.60: return 1
        case 0.60..<0.70: return 2
        case 0.70..<0.80: return 3
        case 0.80..<0.90: return 4
        default: return 5
        }
    }

    func load() async {
        loading = true; defer { loading = false }
        do { data = try await API.shared.get("/api/watch/zone2", as: Zone2Data.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func toggleSession() {
        running.toggle()
        if running {
            elapsed = 0; hrSum = 0; hrCount = 0; inZoneCount = 0
            avgHR = nil; inZonePct = nil
            Task {
                await HealthKitManager.shared.requestAuth()
                HealthKitManager.shared.start()
                await HealthKitManager.shared.startWorkout(activityType: .mixedCardio)
            }
            ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in self.tick() }
            }
        } else {
            ticker?.invalidate()
            HealthKitManager.shared.stop()
            Task { await HealthKitManager.shared.stopWorkout() }
        }
    }

    private func tick() {
        elapsed += 1
        guard let hr = HealthKitManager.shared.heartRate else { return }
        hrSum += hr; hrCount += 1
        if Self.zone(for: hr) == 2 { inZoneCount += 1 }
        avgHR = hrSum / Double(hrCount)
        inZonePct = Int((Double(inZoneCount) / Double(hrCount) * 100).rounded())
    }
}

/// Screen 8 — Zone 2.
/// Layout: status bar → animated heart + bpm → zone pill → 5-bar meter →
///         stats row (elapsed / avg HR / in-zone%) → pause/resume.
struct Zone2View: View {
    @StateObject private var model = Zone2Model()
    @ObservedObject private var hk  = HealthKitManager.shared
    @State private var heartPulse = false

    /// Active zone only when a real sample exists; 0 = no live HR (nothing highlighted).
    private var zone: Int { hk.heartRate.map { Zone2Model.zone(for: $0) } ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Tokens.C.good)
                        Text("Zone 2")
                            .font(.system(size: 19, weight: .semibold))
                    }
                    Spacer()
                    Text("9:41")
                        .font(.system(size: 21, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.accent)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 10)
                .padding(.bottom, 14)

                VStack(spacing: 14) {
                    // Big animated heart + bpm
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Tokens.C.bad)
                            .scaleEffect(heartPulse ? 1.14 : 1.0)
                            .animation(
                                model.running
                                    ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                                    : .default,
                                value: heartPulse)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(hk.heartRate.map { "\(Int($0))" } ?? "—")
                                .font(.system(size: 50, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Tokens.C.ink)
                            Text("bpm")
                                .font(.system(size: 14))
                                .foregroundStyle(Tokens.C.ink3)
                        }
                    }

                    // Current zone pill
                    Text(zoneName(zone))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(zoneColor(zone))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(zoneColor(zone).opacity(0.16), in: Capsule())

                    // 5-bar Z1–Z5 meter
                    HStack(spacing: 5) {
                        ForEach(1...5, id: \.self) { z in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(z == zone ? zoneColor(z) : Tokens.C.card)
                                    .frame(height: CGFloat(z) * 7 + 18)
                                    .animation(.easeInOut(duration: 0.3), value: zone)
                                Text("Z\(z)")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(z == zone ? zoneColor(z) : Tokens.C.ink3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, Tokens.S.hPad)

                    // Stats row
                    HStack(spacing: 0) {
                        statPill("Elapsed",
                                 value: String(format: "%d:%02d", model.elapsed / 60, model.elapsed % 60))
                        divider
                        statPill("Avg HR",
                                 value: model.avgHR.map { "\(Int($0))" } ?? "—",
                                 unit: "bpm")
                        divider
                        statPill("In-zone",
                                 value: model.inZonePct.map { "\($0)" } ?? "—",
                                 unit: "%")
                    }

                    // Pause / Resume
                    Button {
                        model.toggleSession()
                    } label: {
                        Text(model.running ? "Pause" : "Start")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(model.running ? Tokens.C.warn : Tokens.C.good)
                            .frame(maxWidth: .infinity)
                            .frame(height: Tokens.S.tapH)
                            .background(
                                model.running ? Tokens.C.warn.opacity(0.16) : Tokens.C.good.opacity(0.16),
                                in: RoundedRectangle(cornerRadius: Tokens.S.pillRadius))
                    }
                    .buttonStyle(.plain)
                    .pressScale()
                    .padding(.horizontal, Tokens.S.hPad)
                }
                .padding(.bottom, 16)
            }
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
        .onAppear { heartPulse = true }
        .onDisappear { if model.running { model.toggleSession() } }
    }

    // MARK: — Helpers
    private func zoneName(_ z: Int) -> String {
        ["Awaiting HR","Z1 Recovery","Z2 Aerobic","Z3 Tempo","Z4 Threshold","Z5 Max"][z]
    }
    private func zoneColor(_ z: Int) -> Color {
        [Tokens.C.ink2, Tokens.C.ink2, Tokens.C.good, Tokens.C.accent, Tokens.C.warn, Tokens.C.bad][z]
    }

    @ViewBuilder
    private func statPill(_ label: String, value: String, unit: String = "") -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink)
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 10)).foregroundStyle(Tokens.C.ink3)
                }
            }
            KickerLabel(text: label)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Tokens.C.hairline).frame(width: 1, height: 30)
    }
}

#Preview { Zone2View() }
