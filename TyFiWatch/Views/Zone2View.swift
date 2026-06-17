import SwiftUI

/// Zone 2 -- /api/watch/zone2 (watch-auth; weekly Zone 2 progress + recent sessions).
/// Uses Zone2Data from Models.swift -- verified frozen contract 2026-06-14.
/// Live HR banner shown at top when the stopwatch session is active (hk.heartRate != nil).
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
    @ObservedObject private var hk = HealthKitManager.shared

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

                // Live HR + zone banner (shown when a reading is available)
                if let hr = hk.heartRate {
                    liveHRBanner(hr: hr)
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
                                        .monospacedDigit()
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

    // MARK: - Live HR banner

    @ViewBuilder
    private func liveHRBanner(hr: Double) -> some View {
        let zone = hrZone(hr)
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 11))
                .foregroundStyle(zoneColor(zone))
            Text("\(Int(hr)) bpm")
                .font(Type.body)
                .monospacedDigit()
                .foregroundStyle(zoneColor(zone))
            Spacer()
            Text(zone.label)
                .font(Type.caption)
                .foregroundStyle(zoneColor(zone))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(zoneColor(zone).opacity(0.18))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Tokens.C.card)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
    }

    // MARK: - Zone calculation (5-zone model, max HR = 180)

    private enum HRZone {
        case z1, z2, z3, z4, z5
        var label: String {
            switch self {
            case .z1: return "Z1 Recovery"
            case .z2: return "Z2 Aerobic"
            case .z3: return "Z3 Tempo"
            case .z4: return "Z4 Threshold"
            case .z5: return "Z5 Max"
            }
        }
    }

    private func hrZone(_ hr: Double) -> HRZone {
        let max: Double = 180
        let pct = hr / max
        switch pct {
        case ..<0.60: return .z1
        case 0.60..<0.70: return .z2
        case 0.70..<0.80: return .z3
        case 0.80..<0.90: return .z4
        default: return .z5
        }
    }

    private func zoneColor(_ z: HRZone) -> Color {
        switch z {
        case .z1: return Tokens.C.ink2
        case .z2: return Tokens.C.good
        case .z3: return Tokens.C.accent
        case .z4: return Tokens.C.warn
        case .z5: return Tokens.C.bad
        }
    }
}

#Preview { Zone2View() }
