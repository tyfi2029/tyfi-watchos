import SwiftUI

/// Fasting — /api/watch/fasting (watch-auth; health_fasting_logs). Live elapsed
/// ring vs a 16h default target, streak, eating window. start/end via POST.
@MainActor
final class FastingModel: ObservableObject {
    @Published var state: FastingState?
    @Published var error: String?
    @Published var busy = false

    func load() async {
        do { state = try await API.shared.get("/api/watch/fasting", as: FastingState.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func toggle() async {
        busy = true; defer { busy = false }
        let action = state?.active != nil ? "end" : "start"
        do {
            _ = try await API.shared.post("/api/watch/fasting", body: FastingAction(action: action), as: FastingPostResult.self)
            await load()
        } catch { self.error = "Action failed" }
    }
}

struct FastingView: View {
    @StateObject private var model = FastingModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                Text("FASTING").font(Type.label).foregroundStyle(Tokens.C.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let a = model.state?.active
                ZStack {
                    Ring(progress: (a?.progress_pct ?? 0) / 100, color: ringColor, lineWidth: 11)
                        .frame(width: 120, height: 120)
                    VStack(spacing: 0) {
                        Text(a != nil ? String(format: "%.1f", a!.elapsed_hrs ?? 0) : "—")
                            .font(Type.metric(34)).foregroundStyle(Tokens.C.ink)
                        Text(a != nil ? "of \(Int(a!.target_hrs ?? 16))h" : "not fasting")
                            .font(Type.caption).foregroundStyle(Tokens.C.ink2)
                    }
                }.padding(.top, 4)

                HStack(spacing: Tokens.S.gutter) {
                    StatTile(label: "Streak", value: "\(model.state?.streak ?? 0)", unit: "d", color: Tokens.C.accent)
                    StatTile(label: a != nil ? "Remaining" : "Window",
                             value: a != nil ? String(format: "%.1fh", a!.remaining_hrs ?? 0)
                                             : (model.state?.eating_window?.open == true ? "Open" : "—"),
                             color: Tokens.C.cool)
                }

                Button(model.state?.active != nil ? "End Fast" : "Start Fast") {
                    Task { await model.toggle() }
                }
                .font(Type.label)
                .tint(model.state?.active != nil ? Tokens.C.bad : Tokens.C.good)
                .disabled(model.busy)

                if let e = model.error { Text(e).font(Type.caption).foregroundStyle(Tokens.C.warn) }
            }
            .padding(.horizontal, 6)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    private var ringColor: Color {
        let p = model.state?.active?.progress_pct ?? 0
        if p >= 100 { return Tokens.C.good }
        if p >= 50 { return Tokens.C.accent }
        return Tokens.C.cool
    }
}

#Preview { FastingView().environmentObject(Units.shared) }
