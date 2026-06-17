import SwiftUI

@MainActor
final class Zone2Model: ObservableObject {
    @Published var data: Zone2Data?
    @Published var error: String?
    @Published var loading = false
    @Published var running = false
    @Published var elapsed = 0
    private var ticker: Timer?

    func load() async {
        loading = true; defer { loading = false }
        do { data = try await API.shared.get("/api/watch/zone2", as: Zone2Data.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func toggleSession() {
        running.toggle()
        if running {
            elapsed = 0
            ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in self.elapsed += 1 }
            }
        } else {
            ticker?.invalidate()
        }
    }
}

/// Screen 8 — Zone 2.
/// Layout: status bar → animated heart + bpm → zone pill → 5-bar meter →
///         stats row (elapsed / avg HR / in-zone%) → pause/resume.
struct Zone2View: View {
    @StateObject private var model = Zone2Model()
    @ObservedObject private var hk  = HealthKitManager.shared

    private var currentHR: Double { hk.heartRate ?? 138 }
    private var zone: Int { hrZone(currentHR) }

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
                            .scaleEffect(model.running ? 1.0 : 1.0)
                            .animation(
                                model.running
                                    ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                                    : .default,
                                value: model.running)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(Int(currentHR))")
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
                                 value: hk.heartRate != nil ? "\(Int(hk.heartRate!))" : "—",
                                 unit: "bpm")
                        divider
                        statPill("In-zone",
                                 value: zone == 2 ? "100" : "—",
                                 unit: "%")
                    }

                    // Pause / Resume
                    Button {
                        model.toggleSession()
                        if model.running { Task { await HealthKitManager.shared.requestAuth() } }
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
        .onDisappear { if model.running { model.toggleSession() } }
    }

    // MARK: — Helpers
    private func hrZone(_ hr: Double) -> Int {
        let maxHR: Double = 185
        let pct = hr / maxHR
        switch pct {
        case ..<0.60: return 1
        case 0.60..<0.70: return 2
        case 0.70..<0.80: return 3
        case 0.80..<0.90: return 4
        default: return 5
        }
    }
    private func zoneName(_ z: Int) -> String {
        ["","Z1 Recovery","Z2 Aerobic","Z3 Tempo","Z4 Threshold","Z5 Max"][z]
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
