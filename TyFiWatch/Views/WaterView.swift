import SwiftUI

@MainActor
final class WaterModel: ObservableObject {
    @Published var today: WaterToday?
    @Published var error: String?
    @Published var bump = 0
    @Published var brandIndex = 0

    private let brands = ["Mountain Valley", "Evian", "Fiji", "LMNT", "Electrolytes"]
    private let oasisScores: [Double] = [88, 82, 79, 91, 85]

    func load() async {
        do {
            today = try await API.shared.get("/api/watch/hydration/today", as: WaterToday.self)
            error = nil
        }
        catch APIError.notAuthed { self.error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func log(ml: Double) async {
        let body = HydrationLog(amount_ml: ml, brand: today?.brand,
                                logged_at: ISO8601DateFormatter().string(from: Date()))
        do {
            today = try await API.shared.post("/api/watch/hydration/log",
                                              body: body, as: WaterToday.self)
            bump += 1
        } catch {
            if let cur = today {
                today = WaterToday(ml: (cur.ml ?? 0) + ml, goal_ml: cur.goal_ml,
                                   pace_ml: cur.pace_ml, brand: cur.brand,
                                   oasis_score: cur.oasis_score)
            }
            bump += 1
        }
    }
}

/// Screen 6 — Water.
/// Layout: status bar → large cool ring (226 pt, lw 15) with pace chip →
///         three pill buttons (+250 / +500 / +750) → brand / Oasis row.
struct WaterView: View {
    @StateObject private var model = WaterModel()
    @EnvironmentObject var units: Units

    private var progress: Double {
        guard let t = model.today, let goal = t.goal_ml, goal > 0 else { return 0 }
        return (t.ml ?? 0) / goal
    }

    private var paceText: String {
        guard let t = model.today,
              let ml = t.ml, let pace = t.pace_ml, pace > 0 else { return "" }
        let pct = Int((ml / (t.goal_ml ?? 2500)) * 100)
        let delta = ml - pace
        let deltaStr = units.fmtLNum(abs(delta))
        return "\(pct)% · \(delta >= 0 ? "+" : "−")\(deltaStr)\(units.fmtLUnit()) vs pace"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Tokens.C.cool)
                        Text("Water")
                            .font(.system(size: 19, weight: .semibold))
                    }
                    Spacer()
                    Text("9:41")
                        .font(.system(size: 21, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.cool)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 10)
                .padding(.bottom, 6)

                VStack(spacing: 18) {
                    // Big ring
                    ZStack {
                        Ring(progress: progress, color: Tokens.C.cool, lineWidth: 15)
                            .frame(width: 226, height: 226)
                        VStack(spacing: 1) {
                            Text(units.fmtLNum(model.today?.ml ?? 0))
                                .font(.system(size: 62, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Tokens.C.ink)
                                .valueBump(on: model.bump)
                            Text("/ \(units.fmtLNum(model.today?.goal_ml ?? 2500)) \(units.fmtLUnit())")
                                .font(.system(size: 17))
                                .foregroundStyle(Tokens.C.ink3)
                            if !paceText.isEmpty {
                                Text(paceText)
                                    .font(.system(size: 13).monospacedDigit())
                                    .foregroundStyle(Tokens.C.cool)
                                    .padding(.top, 5)
                                    .tracking(0.8)
                            }
                        }
                    }

                    // +250 / +500 / +750 pill buttons
                    HStack(spacing: 10) {
                        ForEach([250.0, 500.0, 750.0], id: \.self) { ml in
                            Button { Task { await model.log(ml: ml) } } label: {
                                VStack(spacing: 1) {
                                    Text("+\(units.fmtMlNum(ml))")
                                        .font(.system(size: 20, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(Tokens.C.cool)
                                    Text(units.volUnit())
                                        .font(.system(size: 11))
                                        .foregroundStyle(Tokens.C.ink3)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(Tokens.C.cool.opacity(0.16),
                                            in: RoundedRectangle(cornerRadius: 22))
                            }
                            .buttonStyle(.plain)
                            .pressScale()
                        }
                    }
                    .padding(.horizontal, Tokens.S.hPad)

                    // Brand / Oasis row
                    Button { model.brandIndex = (model.brandIndex + 1) % 5 } label: {
                        HStack(spacing: 12) {
                            let score = model.today?.oasis_score ?? 88
                            Circle()
                                .fill(oasisColor(score))
                                .frame(width: 9, height: 9)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(model.today?.brand ?? "Mountain Valley")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Tokens.C.ink)
                                Text("TAP TO CHANGE BRAND")
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(1.0)
                                    .foregroundStyle(Tokens.C.ink3)
                            }
                            Spacer()
                            Text("Oasis \(Int(model.today?.oasis_score ?? 88))")
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundStyle(oasisColor(model.today?.oasis_score ?? 88))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Tokens.C.ink3.opacity(0.45))
                        }
                        .padding(14)
                        .background(Tokens.C.card,
                                    in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Tokens.S.hPad)

                    if let e = model.error {
                        Text(e).font(Type.caption).foregroundStyle(Tokens.C.warn)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    private func oasisColor(_ score: Double) -> Color {
        if score >= 80 { return Tokens.C.good }
        if score >= 60 { return Tokens.C.warn }
        return Tokens.C.bad
    }
}

#Preview { WaterView().environmentObject(Units.shared) }
