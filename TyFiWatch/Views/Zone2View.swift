import SwiftUI

struct Zone2View: View {
    struct TodayData: Decodable { let total_min: Int; let session_count: Int }
    struct WeeklyData: Decodable {
        let total_min: Int; let session_count: Int
        let target_min: Int; let pct: Int
        let last_session: String?
    }
    struct Session: Decodable {
        let activity_type: String
        let zone2_minutes: Int
        let duration_minutes: Int
        let avg_hr: Int?
        let started_at: String
        let source_name: String
    }
    struct Zone2Data: Decodable {
        let today: TodayData
        let weekly: WeeklyData
        let recent_sessions: [Session]
    }

    @State private var data: Zone2Data?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "heart.circle")
                        .foregroundStyle(Tokens.C.good)
                    Text("Zone 2")
                        .font(Type.label)
                        .foregroundStyle(Tokens.C.ink)
                    Spacer()
                }

                if isLoading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else if let d = data {
                    // Weekly ring
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Tokens.C.card, lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: CGFloat(d.weekly.pct) / 100)
                                .stroke(Tokens.C.good, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 0) {
                                Text("\(d.weekly.total_min)")
                                    .font(Type.metric(22))
                                    .foregroundStyle(Tokens.C.ink)
                                Text("/ \(d.weekly.target_min) min")
                                    .font(Type.caption)
                                    .foregroundStyle(Tokens.C.ink2)
                            }
                        }
                        .frame(width: 80, height: 80)

                        Text("7-day Zone 2")
                            .font(Type.caption)
                            .foregroundStyle(Tokens.C.ink2)

                        if d.today.total_min > 0 {
                            Text("Today: \(d.today.total_min) min")
                                .font(Type.caption)
                                .foregroundStyle(Tokens.C.good)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Recent sessions
                    if !d.recent_sessions.isEmpty {
                        Text("Recent")
                            .font(Type.caption)
                            .foregroundStyle(Tokens.C.ink2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(Array(d.recent_sessions.prefix(3).enumerated()), id: \.offset) { _, s in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.activity_type.capitalized)
                                        .font(Type.caption)
                                        .foregroundStyle(Tokens.C.ink)
                                    Text("\(s.zone2_minutes) min Z2 · \(s.duration_minutes) min total")
                                        .font(Type.caption)
                                        .foregroundStyle(Tokens.C.ink2)
                                }
                                Spacer()
                                if let hr = s.avg_hr {
                                    Text("\(hr) bpm")
                                        .font(Type.caption)
                                        .foregroundStyle(Tokens.C.bad)
                                }
                            }
                            .padding(6)
                            .background(Tokens.C.card)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                        }
                    }
                } else if let e = error {
                    Text(e).font(Type.caption).foregroundStyle(Tokens.C.bad)
                }
            }
            .padding(Tokens.S.gutter)
        }
        .background(Tokens.C.bg)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            data = try await API.shared.get("/api/watch/zone2", as: Zone2Data.self)
        } catch {
            self.error = "Could not load Zone 2 data"
        }
        isLoading = false
    }
}

#Preview { Zone2View() }
