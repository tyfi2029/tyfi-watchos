import SwiftUI

/// Sleep report — /api/watch/sleep (watch-auth; health_daily_facts derived,
/// best-effort hypnogram). Stage split, overnight HRV/RHR/skin-temp.
@MainActor
final class SleepModel: ObservableObject {
    @Published var report: SleepReport?
    @Published var error: String?
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        do { report = try await API.shared.get("/api/watch/sleep", as: SleepReport.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }
}

struct SleepView: View {
    @StateObject private var model = SleepModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.S.gutter) {
                HStack {
                    Text("SLEEP").font(Type.label).foregroundStyle(Tokens.C.ink3)
                    Spacer()
                    if let s = model.report?.duration?.score {
                        Text("\(s)").font(Type.title).foregroundStyle(Tokens.C.sleep)
                    }
                }
                if let r = model.report {
                    durationCard(r)
                    stagesCard(r)
                    overnightCard(r)
                } else if model.loading {
                    ProgressView().tint(Tokens.C.sleep).frame(maxWidth: .infinity)
                } else {
                    Text(model.error ?? "No sleep data").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                }
            }
            .padding(.horizontal, 6)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    private func hm(_ min: Int?) -> String {
        guard let m = min else { return "—" }
        return "\(m / 60)h \(m % 60)m"
    }

    @ViewBuilder private func durationCard(_ r: SleepReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text("DURATION").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                Text(hm(r.duration?.total_min)).font(Type.metric(26)).foregroundStyle(Tokens.C.ink)
                if let e = r.duration?.efficiency_pct {
                    Text("Efficiency \(Int(e))%").font(Type.caption).foregroundStyle(Tokens.C.ink2)
                }
            }
        }
    }

    @ViewBuilder private func stagesCard(_ r: SleepReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("STAGES").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                stageBar
                HStack(spacing: Tokens.S.gutter) {
                    legend("Deep", r.stages?.deep_pct, Tokens.C.cool)
                    legend("REM", r.stages?.rem_pct, Tokens.C.sleep)
                    legend("Light", r.stages?.light_pct, Tokens.C.ink2)
                }
                if let c = r.stages?.cycles { Text("\(c) cycles").font(Type.caption).foregroundStyle(Tokens.C.ink3) }
            }
        }
    }

    private var stageBar: some View {
        let s = model.report?.stages
        let deep = max(0, s?.deep_pct ?? 0)
        let rem = max(0, s?.rem_pct ?? 0)
        let light = max(0, s?.light_pct ?? 0)
        let total = max(1, deep + rem + light)
        return GeometryReader { geo in
            HStack(spacing: 1) {
                Rectangle().fill(Tokens.C.cool).frame(width: geo.size.width * deep / total)
                Rectangle().fill(Tokens.C.sleep).frame(width: geo.size.width * rem / total)
                Rectangle().fill(Tokens.C.ink2).frame(width: geo.size.width * light / total)
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
    }

    @ViewBuilder private func legend(_ name: String, _ pct: Double?, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(name) \(pct != nil ? "\(Int(pct!))%" : "—")")
                .font(Type.caption).foregroundStyle(Tokens.C.ink2)
        }
    }

    @ViewBuilder private func overnightCard(_ r: SleepReport) -> some View {
        let o = r.overnight
        let cols = [GridItem(.flexible()), GridItem(.flexible())]
        LazyVGrid(columns: cols, spacing: Tokens.S.gutter) {
            StatTile(label: "HRV", value: o?.hrv_avg != nil ? "\(Int(o!.hrv_avg!))" : "—", unit: "ms", color: Tokens.C.good)
            StatTile(label: "RHR", value: o?.rhr != nil ? "\(Int(o!.rhr!))" : "—", unit: "bpm", color: Tokens.C.cool)
            StatTile(label: "Skin Δ", value: o?.skin_temp_deviation != nil ? String(format: "%.1f", o!.skin_temp_deviation!) : "—", color: Tokens.C.warn)
            StatTile(label: "SpO₂", value: o?.spo2 != nil ? "\(Int(o!.spo2!))" : "—", unit: "%", color: Tokens.C.good)
        }
    }
}

#Preview { SleepView().environmentObject(Units.shared) }
