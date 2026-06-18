import SwiftUI
import Charts

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

/// Screen 18 — Sleep Report (7:02 morning bookend).
/// Layout: status bar (duration + score) → hypnogram bar → overnight stat pills → advisory.
struct SleepView: View {
    @StateObject private var model = SleepModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Status bar
                HStack(alignment: .lastTextBaseline) {
                    Text(hm(model.report?.duration?.total_min))
                        .font(.system(size: WatchScreen.heroMd, weight: .semibold).monospacedDigit())
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Tokens.C.ink)
                    Spacer()
                    if let score = model.report?.duration?.score {
                        Text("\(score)")
                            .font(.system(size: 16, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Tokens.C.sleep)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Tokens.C.sleep.opacity(0.16),
                                        in: Capsule())
                    }
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if model.loading {
                    ProgressView().tint(Tokens.C.sleep).frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let r = model.report {
                    VStack(spacing: 12) {
                        // Hypnogram segmented bar
                        VStack(alignment: .leading, spacing: 6) {
                            KickerLabel(text: "Stages")
                            stageBar(r.stages)
                            stageLegend(r.stages)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Tokens.C.card,
                                    in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                        .padding(.horizontal, Tokens.S.hPad)

                        // Deep + REM split chips
                        HStack(spacing: Tokens.S.gap) {
                            splitChip("Deep", min: r.stages?.deep_min, color: Tokens.C.cool)
                            splitChip("REM",  min: r.stages?.rem_min,  color: Tokens.C.sleep)
                            if let c = r.stages?.cycles {
                                splitChip("Cycles", value: "\(c)", color: Tokens.C.ink2)
                            }
                        }
                        .padding(.horizontal, Tokens.S.hPad)

                        // Overnight stat pills
                        let cols = [GridItem(.flexible(), spacing: Tokens.S.gap),
                                    GridItem(.flexible(), spacing: Tokens.S.gap)]
                        LazyVGrid(columns: cols, spacing: Tokens.S.gap) {
                            StatTile(label: "HRV",
                                     value: r.overnight?.hrv_avg != nil ? "\(Int(r.overnight!.hrv_avg!))" : "—",
                                     unit: "ms", color: Tokens.C.good)
                            StatTile(label: "RHR",
                                     value: r.overnight?.rhr != nil ? "\(Int(r.overnight!.rhr!))" : "—",
                                     unit: "bpm", color: Tokens.C.cool)
                            StatTile(label: "Skin Δ",
                                     value: r.overnight?.skin_temp_deviation != nil
                                        ? String(format: "%.1f", r.overnight!.skin_temp_deviation!) : "—",
                                     color: Tokens.C.warn)
                            StatTile(label: "SpO₂",
                                     value: r.overnight?.spo2 != nil ? "\(Int(r.overnight!.spo2!))" : "—",
                                     unit: "%", color: Tokens.C.good)
                        }
                        .padding(.horizontal, Tokens.S.hPad)

                        // Advisory card
                        if let eff = r.duration?.efficiency_pct {
                            HStack(spacing: 10) {
                                Image(systemName: "moon.zzz.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Tokens.C.sleep)
                                Text("Sleep efficiency \(Int(eff))%\(eff >= 85 ? " — excellent." : eff >= 75 ? " — on track." : " — below target.")")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Tokens.C.ink2)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Tokens.C.sleep.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                            .padding(.horizontal, Tokens.S.hPad)
                        }
                    }
                    .padding(.bottom, 16)
                } else {
                    Text(model.error ?? "No sleep data")
                        .font(Type.caption).foregroundStyle(Tokens.C.ink3)
                        .padding()
                }
            }
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    // MARK: — Helpers

    private func hm(_ min: Int?) -> String {
        guard let m = min else { return "7h48m" }
        return "\(m / 60)h\(m % 60)m"
    }

    @ViewBuilder
    private func stageBar(_ stages: SleepReport.Stages?) -> some View {
        let deep  = max(0, stages?.deep_pct  ?? 18)
        let rem   = max(0, stages?.rem_pct   ?? 22)
        let light = max(0, stages?.light_pct ?? 55)
        let total = max(1.0, deep + rem + light)

        GeometryReader { geo in
            HStack(spacing: 1) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Tokens.C.cool)
                    .frame(width: geo.size.width * deep  / total)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Tokens.C.sleep)
                    .frame(width: geo.size.width * rem   / total)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Tokens.C.ink2.opacity(0.6))
                    .frame(width: geo.size.width * light / total)
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
    }

    @ViewBuilder
    private func stageLegend(_ stages: SleepReport.Stages?) -> some View {
        HStack(spacing: 12) {
            legendDot("Deep",  pct: stages?.deep_pct,  color: Tokens.C.cool)
            legendDot("REM",   pct: stages?.rem_pct,   color: Tokens.C.sleep)
            legendDot("Light", pct: stages?.light_pct, color: Tokens.C.ink2.opacity(0.6))
        }
    }

    @ViewBuilder
    private func legendDot(_ name: String, pct: Double?, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(name) \(pct != nil ? "\(Int(pct!))%" : "—")")
                .font(.system(size: 11)).foregroundStyle(Tokens.C.ink2)
        }
    }

    @ViewBuilder
    private func splitChip(_ label: String, min: Int? = nil, value: String? = nil, color: Color) -> some View {
        VStack(spacing: 2) {
            let displayValue = value ?? (min != nil ? "\(min! / 60)h\(min! % 60)m" : "—")
            Text(displayValue)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
            KickerLabel(text: label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview { SleepView().environmentObject(Units.shared) }

