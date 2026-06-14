import SwiftUI

@MainActor
final class NowModel: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var error: String?
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        do {
            snapshot = try await API.shared.get("/api/watch/snapshot", as: Snapshot.self)
            error = nil
        } catch APIError.notAuthed {
            error = "Pair watch to sync"
        } catch {
            self.error = "Offline"
        }
    }
}

/// Screen 1 — Now. Opens here. Summary tiles sourced entirely from /watch/snapshot.
struct NowView: View {
    @StateObject private var model = NowModel()
    @EnvironmentObject var units: Units

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.S.gutter) {
                header
                if let s = model.snapshot {
                    readinessRow(s)
                    grid(s)
                } else if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else {
                    placeholder
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    private var header: some View {
        HStack {
            Text("NOW").font(Type.label).foregroundStyle(Tokens.C.ink3)
            Spacer()
            if let e = model.error {
                Text(e).font(Type.caption).foregroundStyle(Tokens.C.warn)
            }
        }
    }

    @ViewBuilder private func readinessRow(_ s: Snapshot) -> some View {
        let r = s.readiness
        HStack(spacing: Tokens.S.gutter) {
            ZStack {
                Ring(progress: Double(r?.recovery ?? 0) / 100, color: Tokens.C.good, lineWidth: 7)
                    .frame(width: 58, height: 58)
                VStack(spacing: 0) {
                    Text("\(r?.recovery ?? 0)").font(Type.metric(22)).foregroundStyle(Tokens.C.ink)
                    Text("RECOV").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(r?.focus ?? "—").font(Type.title).foregroundStyle(Tokens.C.ink)
                Text("HRV \(r?.hrv ?? 0) · RHR \(r?.rhr ?? 0)")
                    .font(Type.caption).foregroundStyle(Tokens.C.ink2).tabularDigits()
                Text("Sleep \(r?.sleep ?? 0)")
                    .font(Type.caption).foregroundStyle(Tokens.C.ink2).tabularDigits()
            }
            Spacer()
        }
    }

    @ViewBuilder private func grid(_ s: Snapshot) -> some View {
        let cols = [GridItem(.flexible(), spacing: Tokens.S.gutter),
                    GridItem(.flexible(), spacing: Tokens.S.gutter)]
        LazyVGrid(columns: cols, spacing: Tokens.S.gutter) {
            if let g = s.cgm {
                StatTile(label: "Glucose", value: "\(g.glucose_mg_dl ?? 0)", unit: "mg/dL",
                         color: glucoseColor(g.glucose_mg_dl))
            }
            if let w = s.water_today {
                StatTile(label: "Water", value: units.volumeValue(w.ml ?? 0),
                         unit: units.volumeUnit(), color: Tokens.C.cool)
            }
            if let p = s.protocol_progress {
                StatTile(label: p.current_segment ?? "Protocol",
                         value: "\(p.done ?? 0)/\(p.total ?? 0)", color: Tokens.C.accent)
            }
            if let t = s.last_thermal_session, let f = t.temp_f {
                StatTile(label: t.mode ?? "Thermal", value: units.temp(f), color: Tokens.C.warn)
            }
        }
    }

    private var placeholder: some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text("No snapshot yet").font(Type.body).foregroundStyle(Tokens.C.ink2)
                Text("Pair this watch in the TyFi app to start syncing.")
                    .font(Type.caption).foregroundStyle(Tokens.C.ink3)
            }
        }
    }

    private func glucoseColor(_ v: Int?) -> Color {
        guard let v else { return Tokens.C.ink }
        if v < 70 || v > 180 { return Tokens.C.bad }
        if v > 140 { return Tokens.C.warn }
        return Tokens.C.good
    }
}

#Preview { NowView().environmentObject(Units.shared) }
