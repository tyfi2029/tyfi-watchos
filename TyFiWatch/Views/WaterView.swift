import SwiftUI

@MainActor
final class WaterModel: ObservableObject {
    @Published var today: WaterToday?
    @Published var error: String?
    @Published var bump = 0

    func load() async {
        do { today = try await API.shared.get("/api/watch/hydration/today", as: WaterToday.self); error = nil }
        catch APIError.notAuthed { self.error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func log(ml: Double) async {
        let body = HydrationLog(amount_ml: ml, brand: today?.brand,
                                logged_at: ISO8601DateFormatter().string(from: Date()))
        do {
            today = try await API.shared.post("/api/watch/hydration/log", body: body, as: WaterToday.self)
            bump += 1
        } catch {
            // optimistic local nudge if the write is queued/offline
            if let cur = today { today = WaterToday(ml: (cur.ml ?? 0) + ml, goal_ml: cur.goal_ml,
                                                    pace_ml: cur.pace_ml, brand: cur.brand,
                                                    oasis_score: cur.oasis_score) }
            bump += 1
        }
    }
}

/// Screen 3 — Water. Ring shows progress to goal; quick-add buttons POST to /hydration/log.
struct WaterView: View {
    @StateObject private var model = WaterModel()
    @EnvironmentObject var units: Units

    private var progress: Double {
        guard let t = model.today, let goal = t.goal_ml, goal > 0 else { return 0 }
        return (t.ml ?? 0) / goal
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                ZStack {
                    Ring(progress: progress, color: Tokens.C.cool, lineWidth: 10)
                        .frame(width: 110, height: 110)
                    VStack(spacing: 0) {
                        Text(units.volumeValue(model.today?.ml ?? 0))
                            .font(Type.metric(34)).foregroundStyle(Tokens.C.ink)
                            .valueBump(on: model.bump)
                        Text("of \(units.volume(model.today?.goal_ml ?? 0))")
                            .font(Type.caption).foregroundStyle(Tokens.C.ink3)
                    }
                }
                .padding(.top, 6)

                if let o = model.today?.oasis_score {
                    Text("Oasis \(Int(o))").font(Type.label).foregroundStyle(Tokens.C.good)
                }

                HStack(spacing: Tokens.S.gutter) {
                    addButton(ml: 250, label: "+250")
                    addButton(ml: 500, label: "+500")
                }
                if let b = model.today?.brand {
                    Text(b).font(Type.caption).foregroundStyle(Tokens.C.ink2)
                }
                if let e = model.error {
                    Text(e).font(Type.caption).foregroundStyle(Tokens.C.warn)
                }
            }
            .padding(.horizontal, 6)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    private func addButton(ml: Double, label: String) -> some View {
        Button { Task { await model.log(ml: ml) } } label: {
            Text(units.metricVolume ? label : String(format: "+%.0f", ml / 29.5735))
                .font(Type.metric(16)).frame(maxWidth: .infinity)
        }
        .tint(Tokens.C.cool)
    }
}

#Preview { WaterView().environmentObject(Units.shared) }
