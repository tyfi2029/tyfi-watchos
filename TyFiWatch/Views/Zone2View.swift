import SwiftUI

/// Zone 2 — /api/watch/zone2 (watch-auth; weekly Zone 2 progress + recent sessions).
/// Uses Zone2Data from Models.swift — verified frozen contract 2026-06-14.
@MainActor
final class Zone2Model: ObservableObject {
    @Published var data: Zone2Data?
    @Published var error: String?
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        do { data = try await API.shared.get("/api/watch/zone2", as: Zone2Data.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }
}

struct Zone2View: View {
    @StateObject private var model = Zone2Model()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "heart.circle")
                        .foregroundStyle(Tokens.C.good)
                    Text("Zone 2")
                        .font(Type.label)
                        .foregroundStyle(Tokens.C.ink)
                    Spacer()
                }

                if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else if let d = model.data {
                    // Weekly ring
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Tokens.C.card, lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: CGFloat(d.weekly?.pct ?? 0) / 100)
                                .stroke(Tokens.C.good, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 0) {
                                Text("\(d.weekly?.total_min ?? 0)")
                                    .font(Type.metric(22))
                                    .foregroundStyle(Tokens.C.ink)
                                Text("/ \(d.weekly?.target_min ?? 0) min")
                                    .font(Type.caption)
                                    .foregroundStyle(Tokens.C.ink2)
                            }
                        }
                        .frame(width: 80, height: 80)

                        Text("7-day Zone 2")
                            .font(Type.caption)
                            .foregroundStyle(Tokens.C.ink2)

                        if (d.today?.total_min ?? 0) > 0 {
                            Text("Today: \(d.today?.total_min ?? 0) min")
                                .font(Type.caption)
                                .foregroundStyle(Tokens.C.good)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if let sessions = d.recent_sessions, !sessions.isEmpty {
                        Text("Recent")
                            .font(Type.caption)
                            .foregroundStyle(Tokens.C.ink2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(Array(sessions.prefix(3).enumerated()), id: \.offset) { _, s in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text((s.activity_type ?? "").capitalized)
                                        .font(Type.caption)
                                        .foregroundStyle(Tokens.C.ink)
                                    Text("\(s.zone2_minutes ?? 0) min Z2 · \(s.duration_minutes ?? 0) min total")
                                        .font(Type.caption)
                                        .foregroundStyle(Tokens.C.ink2)
                                }
                                Spacer()
                                if let hr = s.avg_hr {
                                    Text("\(Int(hr)) bpm")
                                        .font(Type.caption)
                                        .foregroundStyle(Tokens.C.bad)
                                }
                            }
                            .padding(6)
                            .background(Tokens.C.card)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                        }
                    }
                } else if let e = model.error {
                    Text(e).font(Type.caption).foregroundStyle(Tokens.C.bad)
                }
            }
            .padding(Tokens.S.gutter)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }
}

#Preview { Zone2View() }
