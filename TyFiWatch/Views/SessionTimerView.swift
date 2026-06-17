import SwiftUI

/// Session timer — recent thermal/recovery sessions from /api/watch/session
/// (watch-auth read of health_thermal_sessions) plus a local stopwatch.
/// Live HR badge shown while stopwatch is running.
@MainActor
final class SessionModel: ObservableObject {
    @Published var list: SessionList?
    @Published var error: String?
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        do { list = try await API.shared.get("/api/watch/session", as: SessionList.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }
}

struct SessionTimerView: View {
    @StateObject private var model = SessionModel()
    @ObservedObject private var hk = HealthKitManager.shared
    @EnvironmentObject var units: Units
    @State private var running = false
    @State private var elapsed = 0
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.S.gutter) {
                Text("SESSION").font(Type.label).foregroundStyle(Tokens.C.ink3)
                stopwatch
                if let r = model.list?.rolling_7d {
                    HStack(spacing: Tokens.S.gutter) {
                        StatTile(label: "Heat 7d", value: "\(r.heat_min ?? 0)", unit: "min", color: Tokens.C.warn)
                        StatTile(label: "Cold 7d", value: "\(r.cold_min ?? 0)", unit: "min", color: Tokens.C.cool)
                    }
                }
                Text("RECENT").font(Type.caption).foregroundStyle(Tokens.C.ink3).padding(.top, 2)
                if let sessions = model.list?.sessions {
                    ForEach(sessions.prefix(8)) { s in sessionRow(s) }
                } else if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else {
                    Text(model.error ?? "No sessions").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                }
            }
            .padding(.horizontal, 6)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
        .onDisappear { timer?.invalidate() }
    }

    private var stopwatch: some View {
        Card {
            VStack(spacing: 4) {
                HStack {
                    Text(clock(elapsed))
                        .font(Type.metric(30))
                        .monospacedDigit()
                        .foregroundStyle(running ? Tokens.C.good : Tokens.C.ink)
                    Spacer()
                    Button(running ? "Stop" : "Start") { toggle() }
                        .font(Type.label)
                        .tint(running ? Tokens.C.bad : Tokens.C.good)
                }
                // Live HR badge — visible only while session is running
                if running {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(hrBadgeColor)
                        if let hr = hk.heartRate {
                            Text("\(Int(hr)) bpm")
                                .font(Type.caption)
                                .monospacedDigit()
                                .foregroundStyle(hrBadgeColor)
                        } else {
                            Text("— bpm")
                                .font(Type.caption)
                                .monospacedDigit()
                                .foregroundStyle(Tokens.C.ink3)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var hrBadgeColor: Color {
        guard let hr = hk.heartRate else { return Tokens.C.ink3 }
        if hr > 170 { return Tokens.C.bad }
        if hr > 150 { return Tokens.C.warn }
        return Color(red: 0.878, green: 0.631, blue: 0.302) // #e0a14d
    }

    private func toggle() {
        running.toggle()
        if running {
            elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in elapsed += 1 }
            }
        } else {
            timer?.invalidate()
        }
    }

    private func clock(_ s: Int) -> String { String(format: "%02d:%02d", s / 60, s % 60) }

    @ViewBuilder private func sessionRow(_ s: SessionList.WatchSession) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text((s.mode ?? "session").capitalized).font(Type.body).foregroundStyle(Tokens.C.ink)
                    Text(s.date ?? "").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(s.duration_min ?? 0) min").font(Type.body).foregroundStyle(Tokens.C.ink2).tabularDigits()
                    if let f = s.temp_f { Text(units.temp(f)).font(Type.caption).foregroundStyle(Tokens.C.ink3) }
                }
            }
        }
    }
}

#Preview { SessionTimerView().environmentObject(Units.shared) }
