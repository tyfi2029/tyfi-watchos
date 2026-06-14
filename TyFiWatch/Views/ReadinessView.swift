import SwiftUI

/// Screen 5 — Readiness. Sourced from /watch/snapshot.readiness (NOT /health/recovery,
/// which is webhook-auth and not watch-callable — see gap re-audit 2026-06-14).
@MainActor
final class ReadinessModel: ObservableObject {
    @Published var r: Snapshot.Readiness?
    @Published var error: String?

    func load() async {
        do { r = try await API.shared.get("/api/watch/snapshot", as: Snapshot.self).readiness; error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { error = "Offline" }
    }
}

struct ReadinessView: View {
    @StateObject private var model = ReadinessModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                ZStack {
                    Ring(progress: Double(model.r?.recovery ?? 0) / 100, color: ringColor, lineWidth: 11)
                        .frame(width: 120, height: 120)
                    VStack(spacing: 0) {
                        Text("\(model.r?.recovery ?? 0)").font(Type.metric(40)).foregroundStyle(Tokens.C.ink)
                        Text(model.r?.focus ?? "—").font(Type.label).foregroundStyle(Tokens.C.ink2)
                    }
                }.padding(.top, 6)

                HStack(spacing: Tokens.S.gutter) {
                    StatTile(label: "HRV", value: "\(model.r?.hrv ?? 0)", unit: "ms", color: Tokens.C.good)
                    StatTile(label: "RHR", value: "\(model.r?.rhr ?? 0)", unit: "bpm", color: Tokens.C.cool)
                }
                StatTile(label: "Sleep", value: "\(model.r?.sleep ?? 0)", color: Tokens.C.sleep)

                if let e = model.error {
                    Text(e).font(Type.caption).foregroundStyle(Tokens.C.warn)
                }
            }
            .padding(.horizontal, 6)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    private var ringColor: Color {
        let v = model.r?.recovery ?? 0
        if v >= 66 { return Tokens.C.good }
        if v >= 34 { return Tokens.C.warn }
        return Tokens.C.bad
    }
}

#Preview { ReadinessView().environmentObject(Units.shared) }
