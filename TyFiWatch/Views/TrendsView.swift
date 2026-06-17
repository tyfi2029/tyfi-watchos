import SwiftUI
import Charts

@MainActor
final class TrendsModel: ObservableObject {
    @Published var trends: Trends?
    @Published var error: String?
    @Published var loading = false
    @Published var selectedMetric = 0

    let metricOptions: [(key: String, label: String, color: Color, unit: String)] = [
        ("hrv",       "HRV",      Tokens.C.good,  "ms"),
        ("recovery",  "Recovery", Tokens.C.good,  ""),
        ("glucose_avg","Glucose", Tokens.C.warn,  "mg/dL"),
        ("sleep_hours","Sleep",   Tokens.C.sleep, "h"),
    ]

    func load() async {
        loading = true; defer { loading = false }
        do { trends = try await API.shared.get("/api/watch/trends", as: Trends.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }
}

/// Screen 19 — Trends.
/// Layout: header → 4-option segmented metric picker → 7-day bar chart → delta + avg row.
struct TrendsView: View {
    @StateObject private var model = TrendsModel()

    private var current: (key: String, label: String, color: Color, unit: String) {
        model.metricOptions[model.selectedMetric]
    }

    private var points: [Trends.Point] {
        model.trends?.series?[current.key] ?? []
    }

    private var summary: Trends.MetricSummary? {
        model.trends?.summary?[current.key] ?? nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("TRENDS")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(2.0)
                        .foregroundStyle(Tokens.C.ink3)
                    Spacer()
                    Text("\(model.trends?.window_days ?? 7)d")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Tokens.C.ink3)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 16)
                .padding(.bottom, 14)

                VStack(spacing: 14) {
                    // Segmented metric picker — pill style
                    metricPicker

                    if model.loading {
                        ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    } else if !points.isEmpty {
                        // Bar chart
                        barChart
                            .padding(.horizontal, Tokens.S.hPad)

                        // Delta + average row
                        deltaRow
                            .padding(.horizontal, Tokens.S.hPad)
                    } else {
                        Text(model.error ?? "No trend data")
                            .font(Type.caption).foregroundStyle(Tokens.C.ink3)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    // MARK: — Metric picker
    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.metricOptions.indices, id: \.self) { i in
                    let m = model.metricOptions[i]
                    Button {
                        withAnimation(Motion.press) { model.selectedMetric = i }
                    } label: {
                        Text(m.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(model.selectedMetric == i ? Color.black : Tokens.C.ink2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(model.selectedMetric == i ? m.color : Tokens.C.card,
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: model.selectedMetric)
                }
            }
            .padding(.horizontal, Tokens.S.hPad)
        }
    }

    // MARK: — Bar chart
    private var barChart: some View {
        let vals = points.enumerated().map { (i, p) in (i, p.value ?? 0) }
        let latestIdx = vals.indices.last ?? 0
        let yVals = vals.map(\.1)
        let yMin = max(0, (yVals.min() ?? 0) * 0.9)
        let yMax = (yVals.max() ?? 1) * 1.08

        return Chart {
            ForEach(Array(vals.enumerated()), id: \.offset) { offset, pair in
                BarMark(
                    x: .value("Day", pair.0),
                    y: .value(current.label, pair.1),
                    width: .ratio(0.5)
                )
                .foregroundStyle(pair.0 == latestIdx ? current.color : Tokens.C.card)
                .cornerRadius(5)
            }
        }
        .chartYScale(domain: yMin...yMax)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                AxisValueLabel {
                    if let d = v.as(Double.self) {
                        Text(fmt(d))
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(Tokens.C.ink3)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                    .foregroundStyle(Tokens.C.hairline)
            }
        }
        .frame(height: 110)
    }

    // MARK: — Delta + average row
    private var deltaRow: some View {
        HStack(spacing: Tokens.S.gap) {
            statChip("Latest",
                     value: summary?.last != nil ? fmt(summary!.last!) : "—",
                     unit: current.unit,
                     color: current.color)
            if let d = summary?.delta {
                statChip("vs last wk",
                         value: (d > 0 ? "+" : "") + fmt(d),
                         unit: "",
                         color: d > 0 ? Tokens.C.good : Tokens.C.bad)
            }
            statChip("7d avg",
                     value: summary?.avg != nil ? fmt(summary!.avg!) : "—",
                     unit: current.unit,
                     color: Tokens.C.ink2)
        }
    }

    @ViewBuilder
    private func statChip(_ label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.C.ink3)
                }
            }
            KickerLabel(text: label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

#Preview { TrendsView().environmentObject(Units.shared) }
