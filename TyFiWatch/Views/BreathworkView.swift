import SwiftUI

/// Breathwork — 4-7-8 cadence engine (watch-side) that records the session via
/// /api/watch/breath (start → breathing_sessions row; end → completes it with
/// pre/post HRV deltas). Live HealthKit HR/HRV coupling is a follow-up requiring
/// the HealthKit capability (flagged) — the cadence + record path ships here.
enum BreathPhase: String {
    case idle = "Tap to begin"
    case inhale = "Inhale"
    case hold = "Hold"
    case exhale = "Exhale"
    var seconds: Int { switch self { case .inhale: 4; case .hold: 7; case .exhale: 8; case .idle: 0 } }
    var scale: CGFloat { switch self { case .inhale, .hold: 1.0; case .exhale, .idle: 0.55 } }
}

@MainActor
final class BreathModel: ObservableObject {
    @Published var phase: BreathPhase = .idle
    @Published var remaining = 0
    @Published var cycle = 0
    @Published var running = false
    @Published var error: String?

    let targetCycles = 4
    private var sessionId: String?
    private var startedAt: Date?
    private var timer: Timer?

    func start() async {
        cycle = 0
        startedAt = Date()
        do {
            let res = try await API.shared.post(
                "/api/watch/breath",
                body: BreathStart(technique: "4-7-8",
                                  target_duration_seconds: targetCycles * 19,
                                  target_cycles: targetCycles,
                                  pre_hrv_deviation: nil, pre_stress_tier: nil),
                as: BreathStartResult.self)
            sessionId = res.session?.session_id
            self.error = nil
        } catch { self.error = "Record offline" } // still run the cadence locally
        running = true
        advance(.inhale)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in self.tick() }
        }
    }

    func stop() async {
        timer?.invalidate(); running = false; phase = .idle
        guard let sid = sessionId else { return }
        let dur = startedAt.map { Int(Date().timeIntervalSince($0)) }
        do {
            _ = try await API.shared.post(
                "/api/watch/breath",
                body: BreathEnd(session_id: sid, actual_duration_seconds: dur,
                                post_hrv_deviation: nil, post_stress_tier: nil,
                                effectiveness_score: nil),
                as: BreathStartResult.self)
        } catch { self.error = "End failed" }
        sessionId = nil
    }

    private func tick() {
        remaining -= 1
        if remaining > 0 { return }
        switch phase {
        case .inhale: advance(.hold)
        case .hold: advance(.exhale)
        case .exhale:
            cycle += 1
            if cycle >= targetCycles { Task { await stop() } } else { advance(.inhale) }
        case .idle: break
        }
    }

    private func advance(_ p: BreathPhase) { phase = p; remaining = p.seconds }
}

struct BreathworkView: View {
    @StateObject private var model = BreathModel()

    var body: some View {
        VStack(spacing: Tokens.S.gutter) {
            Text("4-7-8 BREATH").font(Type.label).foregroundStyle(Tokens.C.ink3)
            ZStack {
                Circle().fill(Tokens.C.accent.opacity(0.18))
                    .frame(width: 130, height: 130)
                    .scaleEffect(model.phase.scale)
                    .animation(.easeInOut(duration: Double(max(1, model.phase.seconds))), value: model.phase)
                VStack(spacing: 2) {
                    Text(model.phase.rawValue).font(Type.title).foregroundStyle(Tokens.C.ink)
                    if model.running {
                        Text("\(model.remaining)").font(Type.metric(28)).foregroundStyle(Tokens.C.accent)
                        Text("cycle \(model.cycle + 1)/\(model.targetCycles)")
                            .font(Type.caption).foregroundStyle(Tokens.C.ink3)
                    }
                }
            }
            .frame(height: 150)

            Button(model.running ? "Stop" : "Begin") {
                Task { model.running ? await model.stop() : await model.start() }
            }
            .font(Type.label)
            .tint(model.running ? Tokens.C.bad : Tokens.C.good)

            if let e = model.error { Text(e).font(Type.caption).foregroundStyle(Tokens.C.ink3) }
        }
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity)
        .background(Tokens.C.bg)
    }
}

#Preview { BreathworkView().environmentObject(Units.shared) }
