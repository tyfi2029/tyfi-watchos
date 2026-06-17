import SwiftUI
import HealthKit

enum SessionMode: String, CaseIterable {
    case cold  = "Cold plunge"
    case sauna = "Sauna"
    var color: Color    { self == .cold ? Tokens.C.cool : Tokens.C.warn }
    var target: Int     { self == .cold ? 180 : 1200 }   // seconds
    var tempRange: ClosedRange<Double> { self == .cold ? 38...60 : 150...220 }
    var defaultTemp: Double { self == .cold ? 50 : 180 }
}

@MainActor
final class SessionModel: ObservableObject {
    @Published var list: SessionList?
    @Published var error: String?
    @Published var loading = false

    // Live session state
    @Published var mode: SessionMode = .cold
    @Published var tempF: Double = 50
    @Published var running = false
    @Published var elapsed = 0
    @Published var sessionDone = false
    @Published var serverSessionId: Int?
    @Published var hrPeak: Double?

    private var ticker: Timer?

    func load() async {
        loading = true; defer { loading = false }
        do { list = try await API.shared.get("/api/watch/session", as: SessionList.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func start() async {
        elapsed = 0; running = true; sessionDone = false; hrPeak = nil
        await HealthKitManager.shared.requestAuth()
        HealthKitManager.shared.start()   // begin live HR/HRV stream for the overlay
        await HealthKitManager.shared.startWorkout(activityType: .other)  // foreground + accurate HR
        let body = SessionStartBody(mode: mode.rawValue.lowercased(),
            temp_f: tempF, target_sec: mode.target,
            started_at: ISO8601DateFormatter().string(from: Date()),
            backfill_sec: nil, detection_source: nil, detection_score: nil)
        let res = try? await API.shared.post("/api/watch/session/start",
            body: body, as: SessionStartResult.self)
        serverSessionId = res?.session_id
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                self.elapsed += 1
                if let hr = HealthKitManager.shared.heartRate {
                    self.hrPeak = max(self.hrPeak ?? 0, hr)
                }
                if self.mode == .cold && self.elapsed >= self.mode.target {
                    await self.finish()
                }
            }
        }
    }

    func finish() async {
        ticker?.invalidate(); running = false; sessionDone = true
        if let sid = serverSessionId {
            let body = SessionEndBody(session_id: sid, elapsed_sec: elapsed,
                ended_at: ISO8601DateFormatter().string(from: Date()),
                hr_avg: HealthKitManager.shared.heartRate,
                hr_peak: hrPeak, completion_status: "completed")
            _ = try? await API.shared.post("/api/watch/session/end", body: body, as: SessionEndResult.self)
        }
        HealthKitManager.shared.stop()
        await HealthKitManager.shared.stopWorkout()
        await load()
    }

    func reset() {
        ticker?.invalidate(); running = false; elapsed = 0; sessionDone = false
        HealthKitManager.shared.stop()
        Task { await HealthKitManager.shared.stopWorkout() }
    }
}

/// Screen 7 — Session Timer.
/// Layout: auto-detect banner → mode switch → ring timer → temp slider / HR → start/reset.
struct SessionTimerView: View {
    @StateObject private var model = SessionModel()
    @ObservedObject private var hk = HealthKitManager.shared
    @EnvironmentObject var units: Units
    @State private var heartPulse = false

    private var displayTime: String {
        if model.mode == .cold {
            let rem = max(0, model.mode.target - model.elapsed)
            return String(format: "%d:%02d", rem / 60, rem % 60)
        }
        return String(format: "%d:%02d", model.elapsed / 60, model.elapsed % 60)
    }

    private var ringPct: Double {
        model.mode == .cold
            ? Double(max(0, model.mode.target - model.elapsed)) / Double(model.mode.target)
            : min(1, Double(model.elapsed) / Double(model.mode.target))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(model.mode.color)
                        Text("Session")
                            .font(.system(size: 19, weight: .semibold))
                    }
                    Spacer()
                    Text("9:41")
                        .font(.system(size: 21, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.accent)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 10)
                .padding(.bottom, 10)

                VStack(spacing: 10) {
                    // Auto-detect banner
                    if !model.running {
                        autoDetectBanner
                    }

                    // Mode switch
                    if !model.running {
                        modePicker
                    }

                    // Ring timer
                    ZStack {
                        Ring(progress: ringPct, color: model.mode.color, lineWidth: 12)
                            .frame(width: 162, height: 162)
                        VStack(spacing: 2) {
                            Text(displayTime)
                                .font(.system(size: 46, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Tokens.C.ink)
                            Text(model.running
                                 ? "\(units.temp(model.tempF))"
                                 : "target \(String(format: "%d:%02d", model.mode.target / 60, model.mode.target % 60)) · \(units.temp(model.tempF))")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Tokens.C.ink3)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }

                    // Temp slider (pre-start) or live HR (running)
                    if model.running {
                        liveHR
                    } else {
                        tempSlider
                    }

                    // Completion card
                    if model.sessionDone {
                        completionCard
                    }

                    // Start / reset row
                    if !model.sessionDone {
                        HStack(spacing: 10) {
                            Button { model.reset() } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Tokens.C.ink2)
                                    .frame(width: Tokens.S.tapH, height: Tokens.S.tapH)
                                    .background(Tokens.C.card,
                                                in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                            .pressScale()

                            Button {
                                Task { model.running ? await model.finish() : await model.start() }
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: model.running ? "stop.fill" : "play.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text(model.running ? "Finish" : "Start")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: Tokens.S.tapH)
                                .background(model.mode.color,
                                            in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                            .pressScale()
                        }
                    }
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.bottom, 16)
            }
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
        .onDisappear { model.reset() }
    }

    private var autoDetectBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "thermometer.snowflake")
                .font(.system(size: 18))
                .foregroundStyle(Tokens.C.cool)
                .frame(width: 50)
            VStack(alignment: .leading, spacing: 1) {
                Text("❄ COLD DETECTED")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.0)
                    .foregroundStyle(Tokens.C.cool)
                Text("skin −16°F · began 0:24 ago")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Tokens.C.ink2)
            }
            Spacer()
            Text("Track")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Tokens.C.cool, in: Capsule())
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(Tokens.C.cool.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Tokens.C.cool.opacity(0.3), lineWidth: 1)
        )
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(SessionMode.allCases, id: \.rawValue) { m in
                Button {
                    withAnimation(Motion.press) {
                        model.mode = m
                        model.tempF = m.defaultTemp
                    }
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(model.mode == m ? Color.white : Tokens.C.ink3)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(model.mode == m ? m.color.opacity(0.18) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Tokens.C.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var tempSlider: some View {
        VStack(spacing: 8) {
            HStack {
                KickerLabel(text: "Temperature")
                Spacer()
                Text(units.temp(model.tempF))
                    .font(.system(size: 16, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink)
            }
            Slider(value: $model.tempF, in: model.mode.tempRange, step: 1)
                .tint(model.mode.color)
        }
    }

    @ViewBuilder
    private var liveHR: some View {
        HStack(spacing: 11) {
            Image(systemName: "heart.fill")
                .font(.system(size: 22))
                .foregroundStyle(Tokens.C.bad)
                .scaleEffect(heartPulse ? 1.14 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: heartPulse)
                .onAppear { heartPulse = true }
                .onDisappear { heartPulse = false }
            if let hr = hk.heartRate {
                Text("\(Int(hr))")
                    .font(.system(size: 34, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink)
            } else {
                Text("—")
                    .font(.system(size: 34, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink3)
            }
            Text("bpm")
                .font(.system(size: 13))
                .foregroundStyle(Tokens.C.ink3)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if let peak = model.hrPeak {
                    Text("peak \(Int(peak))")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Tokens.C.ink3)
                }
                Text(units.temp(model.tempF))
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(model.mode.color)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var completionCard: some View {
        HStack(spacing: 11) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Tokens.C.good)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.mode.rawValue) complete")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.C.ink)
                Text("\(String(format: "%d:%02d", model.elapsed / 60, model.elapsed % 60)) @ \(units.temp(model.tempF)) · logged")
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.C.ink2)
            }
            Spacer()
        }
        .padding(14)
        .background(Tokens.C.good.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
    }
}

#Preview { SessionTimerView().environmentObject(Units.shared) }
