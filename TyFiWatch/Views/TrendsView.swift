import SwiftUI

/// Trends — /api/watch/trends (watch-auth; 7-day per-metric series + summary).
@MainActor
final class TrendsModel: ObservableObject {
    @Published var trends: Trends?
    @Published var error: String?
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        do { trends = try await API.shared.get("/api/watch/trends", as: Trends.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }
}

struct TrendsView: View {
    @StateObject private var model = TrendsModel()

    // Display order + labels + accent for the metrics we surface.
    private let metrics: [(key: String, label: String, color: Color, unit: String)] = [
        ("recovery", "Recovery", Tokens.C.good, ""),
        ("hrv", "HRV", Tokens.C.good, "ms"),
        ("rhr", "RHR", Tokens.C.cool, "bpm"),
        ("sleep_hours", "Sleep", Tokens.C.sleep, "h"),
        ("steps", "Steps", Tokens.C.accent, ""),
        ("glucose_avg", "Glucose", Tokens.C.warn, ""),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.S.gutter) {
                HStack {
                    Text("TRENDS").font(Type.label).foregroundStyle(Tokens.C.ink3)
                    Spacer()
                    Text("\(model.trends?.window_days ?? 7)d").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                }
                if let t = model.trends {
                    ForEach(metrics, id: \.key) { m in
                        if let pts = t.series?[m.key], pts.contains(where: { $0.value != nil }) {
                            trendRow(m, pts, t.summary?[m.key] ?? nil)
                        }
                    }
                } else if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else {
                    Text(model.error ?? "No trend data").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                }
            }
            .padding(.horizontal, 6)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    @ViewBuilder
    private func trendRow(_ m: (key: String, label: String, color: Color, unit: String),
                          _ pts: [Trends.Point], _ summary: Trends.MetricSummary?) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(m.label.uppercased()).font(Type.caption).foregroundStyle(Tokens.C.ink3)
                    Spacer()
                    if let last = summary?.last {
                        Text(fmt(last) + (m.unit.isEmpty ? "" : " \(m.unit)"))
                            .font(Type.title).foregroundStyle(m.color)
                    }
                    if let d = summary?.delta, d != 0 {
                        Text((d > 0 ? "▲" : "▼") + fmt(abs(d)))
                            .font(Type.caption).foregroundStyle(d > 0 ? Tokens.C.good : Tokens.C.bad)
                    }
                }
                Sparkline(points: pts.map { $0.value }, color: m.color).frame(height: 22)
            }
        }
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

/// Minimal sparkline over an array of optional values (nil = gap).
struct Sparkline: View {
    let points: [Double?]
    var color: Color = Tokens.C.accent

    var body: some View {
        GeometryReader { geo in
            let vals = points.compactMap { $0 }
            let lo = vals.min() ?? 0
            let hi = vals.max() ?? 1
            let span = max(0.0001, hi - lo)
            let n = max(1, points.count - 1)
            Path { p in
                var started = false
                for (i, v) in points.enumerated() {
                    guard let v else { continue }
                    let x = geo.size.width * Double(i) / Double(n)
                    let y = geo.size.height * (1 - (v - lo) / span)
                    let pt = CGPoint(x: x, y: y)
                    if started { p.addLine(to: pt) } else { p.move(to: pt); started = true }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

#Preview { TrendsView().environmentObject(Units.shared) }
