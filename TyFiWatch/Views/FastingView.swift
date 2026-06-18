import SwiftUI

@MainActor
final class FastingModel: ObservableObject {
    @Published var state: FastingState?
    @Published var error: String?
    @Published var busy = false
    @Published var showProtocolPicker = false
    @Published var selectedProtocol = "16:8"
    @Published var selectedHours: Double = 16
    @Published var tickCount = 0          // drives 1-second live display
    private var ticker: Timer?

    func load() async {
        do { state = try await API.shared.get("/api/watch/fasting", as: FastingState.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in self.tickCount += 1 }
        }
    }

    func start(protocol proto: String, targetHours: Double) async {
        busy = true; defer { busy = false }
        struct StartBody: Encodable { let action: String; let `protocol`: String; let target_hours: Double }
        struct R: Decodable { let started: Bool? }
        _ = try? await API.shared.post("/api/watch/fasting",
            body: StartBody(action: "start", `protocol`: proto, target_hours: targetHours), as: R.self)
        await load()
    }

    func end() async {
        busy = true; defer { busy = false }
        struct EndBody: Encodable { let action: String }
        struct R: Decodable { let ended: Bool? }
        _ = try? await API.shared.post("/api/watch/fasting", body: EndBody(action: "end"), as: R.self)
        await load()
    }
}

private let protocolOptions: [(label: String, hours: Double)] = [
    ("13:11", 13), ("16:8", 16), ("18:6", 18), ("20:4", 20), ("OMAD", 23), ("36h", 36),
]

/// Screen 21 — Fasting (16:8 window).
/// Layout: status bar → fasting ring (accent stroke) → streak chip → end/start toggle.
struct FastingView: View {
    @StateObject private var model = FastingModel()

    private var displayElapsed: String {
        let hrs = model.state?.active?.elapsed_hrs ?? 0
        let totalMin = Int(hrs * 60) + model.tickCount  // live tick
        let h = totalMin / 60, m = totalMin % 60
        return String(format: "%d:%02d", h, m)
    }

    private var ringPct: Double {
        Double(model.state?.active?.progress_pct ?? 0) / 100
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("FASTING")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(2.0)
                        .foregroundStyle(Tokens.C.ink3)
                    Spacer()
                    Text("9:41")
                        .font(.system(size: 21, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.accent)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 16)
                .padding(.bottom, 14)

                VStack(spacing: 14) {
                    // Main ring — 188pt per spec
                    ZStack {
                        Ring(progress: ringPct, color: ringColor, lineWidth: WatchScreen.strokeMd)
                            .frame(width: WatchScreen.ringMd, height: WatchScreen.ringMd)
                        VStack(spacing: 1) {
                            // Show elapsed time when fasting, "--:--" when not
                            Text(model.state?.active != nil ? displayElapsed : "--:--")
                                .font(.system(size: WatchScreen.heroSm, weight: .semibold).monospacedDigit())
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(Tokens.C.ink)
                            Text(model.state?.active != nil
                                 ? "/\(Int(model.state!.active!.target_hrs ?? 16)):00"
                                 : "not fasting")
                                .font(.system(size: 16))
                                .foregroundStyle(Tokens.C.ink2)
                        }
                    }

                    // Stage + streak row
                    HStack(spacing: 10) {
                        if let streak = model.state?.streak, streak > 0 {
                            HStack(spacing: 5) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Tokens.C.good)
                                Text("\(streak)d streak")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Tokens.C.good)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Tokens.C.good.opacity(0.14), in: Capsule())
                        }

                        if let stage = model.state?.active?.stage {
                            Text(stage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(stageColor(stage))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(stageColor(stage).opacity(0.15), in: Capsule())
                        }
                    }

                    // Stats row
                    if let a = model.state?.active {
                        HStack(spacing: Tokens.S.gap) {
                            StatTile(label: "Elapsed",
                                     value: displayElapsed,
                                     color: Tokens.C.accent)
                            StatTile(label: "Remaining",
                                     value: String(format: "%.1fh", a.remaining_hrs ?? 0),
                                     color: Tokens.C.cool)
                        }
                    }

                    // CTA button
                    if model.state?.active != nil {
                        // Actively fasting → "End fast · start eating" with fork.knife
                        Button {
                            Task { await model.end() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("End fast · start eating")
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(Tokens.C.bad)
                            .frame(maxWidth: .infinity)
                            .frame(height: Tokens.S.tapH)
                            .background(Tokens.C.bad.opacity(0.16),
                                        in: RoundedRectangle(cornerRadius: Tokens.S.pillRadius))
                        }
                        .buttonStyle(.plain)
                        .disabled(model.busy)
                    } else {
                        // Not fasting → "Start fast" (not "Start Eating")
                        Button("Start fast") {
                            model.showProtocolPicker = true
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Tokens.C.good)
                        .frame(maxWidth: .infinity)
                        .frame(height: Tokens.S.tapH)
                        .background(Tokens.C.good.opacity(0.16),
                                    in: RoundedRectangle(cornerRadius: Tokens.S.pillRadius))
                        .buttonStyle(.plain)
                        .disabled(model.busy)
                    }

                    if let e = model.error {
                        Text(e).font(Type.caption).foregroundStyle(Tokens.C.warn)
                    }
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.bottom, 16)
            }
        }
        .background(Tokens.C.bg)
        .task {
            await model.load()
            model.startTicker()
        }
        .sheet(isPresented: $model.showProtocolPicker) {
            protocolSheet
        }
    }

    private var ringColor: Color {
        let p = model.state?.active?.progress_pct ?? 0
        if p >= 100 { return Tokens.C.good }
        if p >= 50  { return Tokens.C.accent }
        return Tokens.C.cool
    }

    private func stageColor(_ stage: String) -> Color {
        switch stage {
        case "Autophagy":    return Tokens.C.good
        case "Deep Ketosis": return Tokens.C.accent
        case "Ketosis", "Fat Burning": return Tokens.C.cool
        default: return Tokens.C.ink2
        }
    }

    private var protocolSheet: some View {
        VStack(spacing: Tokens.S.gap) {
            KickerLabel(text: "Choose Protocol").padding(.top, 4)
            ForEach(protocolOptions, id: \.label) { p in
                Button {
                    model.selectedProtocol = p.label
                    model.selectedHours    = p.hours
                    model.showProtocolPicker = false
                    Task { await model.start(protocol: p.label, targetHours: p.hours) }
                } label: {
                    HStack {
                        Text(p.label)
                            .font(.system(size: 16))
                            .foregroundStyle(Tokens.C.ink)
                        Spacer()
                        Text("\(Int(p.hours))h")
                            .font(.system(size: 13).monospacedDigit())
                            .foregroundStyle(Tokens.C.ink3)
                        if model.selectedProtocol == p.label {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Tokens.C.good)
                        }
                    }
                    .padding(10)
                    .background(Tokens.C.card,
                                in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Tokens.S.hPad)
        .background(Tokens.C.bg)
    }
}

#Preview { FastingView().environmentObject(Units.shared) }

