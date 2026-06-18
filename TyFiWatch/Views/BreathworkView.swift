import SwiftUI

enum BreathPhase: String {
    case idle    = "Tap to begin"
    case inhale  = "INHALE"
    case hold    = "HOLD"
    case exhale  = "EXHALE"
    var seconds: Int {
        switch self { case .inhale: 4; case .hold: 7; case .exhale: 8; case .idle: 0 }
    }
    var orbScale: CGFloat {
        switch self { case .inhale, .hold: 1.0; case .exhale, .idle: 0.55 }
    }
    var orbDuration: Double {
        switch self { case .inhale: 4; case .hold: 7; case .exhale: 8; case .idle: 5 }
    }
}

@MainActor
final class BreathModel: ObservableObject {
    @Published var phase: BreathPhase = .idle
    @Published var remaining  = 0
    @Published var cycle      = 0
    @Published var running    = false
    @Published var error: String?

    let targetCycles = 4
    private var sessionId: String?
    private var startedAt: Date?
    private var timer: Timer?

    func start() async {
        cycle = 0; startedAt = Date()
        await HealthKitManager.shared.requestAuth()
        await HealthKitManager.shared.startBreathworkSession()
        HealthKitManager.shared.start()   // anchored HR stream feeds the live readout
        do {
            let res = try await API.shared.post(
                "/api/watch/breath",
                body: BreathStart(technique: "4-7-8",
                                  target_duration_seconds: targetCycles * 19,
                                  target_cycles: targetCycles,
                                  pre_hrv_deviation: nil, pre_stress_tier: nil),
                as: BreathStartResult.self)
            sessionId = res.session?.session_id
            error = nil
        } catch { self.error = "Record offline" }
        running = true
        advance(.inhale)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in self.tick() }
        }
    }

    func stop() async {
        timer?.invalidate(); running = false; phase = .idle
        Haptics.success()
        HealthKitManager.shared.stop()
        let _ = await HealthKitManager.shared.stopBreathworkSession()
        guard let sid = sessionId else { return }
        let dur = startedAt.map { Int(Date().timeIntervalSince($0)) }
        _ = try? await API.shared.post(
            "/api/watch/breath",
            body: BreathEnd(session_id: sid, actual_duration_seconds: dur,
                            post_hrv_deviation: nil, post_stress_tier: nil,
                            effectiveness_score: nil),
            as: BreathStartResult.self)
        sessionId = nil
    }

    private func tick() {
        remaining -= 1
        if remaining > 0 { return }
        switch phase {
        case .inhale: advance(.hold)
        case .hold:   advance(.exhale)
        case .exhale:
            cycle += 1
            if cycle >= targetCycles { Task { await stop() } } else { advance(.inhale) }
        case .idle: break
        }
    }
    private func advance(_ p: BreathPhase) { Haptics.click(); phase = p; remaining = p.seconds }
}

/// Screen 22 — Breathwork.
/// Layout: title → animated breathing orb (scale inhale↔exhale) → phase label →
///         live HR readout → cycle counter → pause/resume pill.
/// Color: cool (#7aa9cf) throughout — this is a downregulation screen.
struct BreathworkView: View {
    @StateObject private var model = BreathModel()
    @ObservedObject private var hk = HealthKitManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("4·7·8 BREATH")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(2.0)
                    .foregroundStyle(Tokens.C.ink3)
                Spacer()
                if model.running {
                    Text("\(model.cycle + 1)/\(model.targetCycles)")
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(Tokens.C.ink3)
                }
            }
            .padding(.horizontal, Tokens.S.hPad)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Spacer()

            // Breathing orb — cool blue (downregulation, not accent orange)
            ZStack {
                Circle()
                    .fill(Tokens.C.cool.opacity(0.18))
                    .frame(width: WatchScreen.ringXs, height: WatchScreen.ringXs)
                    .scaleEffect(model.running ? model.phase.orbScale : 0.66)
                    .animation(
                        model.running
                            ? .easeInOut(duration: model.phase.orbDuration)
                            : .easeInOut(duration: 5.0).repeatForever(autoreverses: true),
                        value: model.phase)
                    .overlay(
                        Circle()
                            .stroke(Tokens.C.cool.opacity(0.35), lineWidth: 1.5)
                            .scaleEffect(model.running ? model.phase.orbScale : 0.66)
                            .animation(
                                model.running
                                    ? .easeInOut(duration: model.phase.orbDuration)
                                    : .easeInOut(duration: 5.0).repeatForever(autoreverses: true),
                                value: model.phase)
                    )

                VStack(spacing: 4) {
                    if model.running {
                        Text(model.phase.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Tokens.C.ink2)
                        Text("\(model.remaining)")
                            .font(.system(size: WatchScreen.heroXxs, weight: .semibold).monospacedDigit())
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(Tokens.C.cool)
                    } else {
                        Text(model.phase.rawValue)
                            .font(.system(size: 15))
                            .foregroundStyle(Tokens.C.ink2)
                    }
                }
            }
            .frame(height: WatchScreen.ringXs + 20)

            Spacer()

            VStack(spacing: 14) {
                // Live HR
                if model.running {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Tokens.C.bad)
                        if let hr = hk.heartRate {
                            Text("\(Int(hr)) bpm")
                                .font(.system(size: 15).monospacedDigit())
                                .foregroundStyle(Tokens.C.bad)
                        } else {
                            Text("— bpm")
                                .font(.system(size: 15).monospacedDigit())
                                .foregroundStyle(Tokens.C.ink3)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Tokens.C.card, in: Capsule())
                }

                // Begin / Pause pill — cool blue (not orange/green)
                Button {
                    Task { model.running ? await model.stop() : await model.start() }
                } label: {
                    Text(model.running ? "Pause" : "Begin")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(model.running ? Tokens.C.bad : Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: Tokens.S.tapH)
                        .background(
                            model.running ? Tokens.C.bad.opacity(0.16) : Tokens.C.cool,
                            in: RoundedRectangle(cornerRadius: Tokens.S.pillRadius))
                }
                .buttonStyle(.plain)
                .pressScale()

                if let e = model.error {
                    Text(e).font(Type.caption).foregroundStyle(Tokens.C.ink3)
                }
            }
            .padding(.horizontal, Tokens.S.hPad)
            .padding(.bottom, 20)
        }
        .frame(maxHeight: .infinity)
        .background(Tokens.C.bg)
        .task { await HealthKitManager.shared.requestAuth() }
    }
}

#Preview { BreathworkView().environmentObject(Units.shared) }

