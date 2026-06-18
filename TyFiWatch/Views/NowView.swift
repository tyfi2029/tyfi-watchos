import SwiftUI

@MainActor
final class NowModel: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var error: String?
    @Published var loading = false
    @Published var waterBump = 0
    /// Non-nil when `snapshot` is served from cache after a failed refresh.
    @Published var staleSince: String?

    func load() async {
        loading = true; defer { loading = false }
        do {
            let fresh = try await API.shared.get("/api/watch/snapshot", as: Snapshot.self)
            snapshot = fresh
            SnapshotCache.save(fresh)
            staleSince = nil
            error = nil
        } catch APIError.notAuthed {
            // 401 already cleared the token + posted re-pair; don't show stale cache.
            error = "Pair watch to sync"
        } catch {
            // Offline/transient: fall back to last-good snapshot with a timestamp.
            if let cached = SnapshotCache.load() {
                snapshot = cached.snapshot
                staleSince = SnapshotCache.staleLabel(for: cached.storedAt)
                self.error = nil
            } else {
                self.error = "Offline"
            }
        }
    }

    func logWater(ml: Double) async {
        let body = HydrationLog(amount_ml: ml, brand: snapshot?.water_today?.brand,
                                logged_at: ISO8601DateFormatter().string(from: Date()))
        _ = try? await API.shared.post("/api/watch/hydration/log", body: body, as: WaterToday.self)
        waterBump += 1
        await load()
    }
}

/// Screen 3 — Now (app home).
/// Layout: insight line → 2×2 WMP tile grid → action row (+water / mic / thermal).
struct NowView: View {
    @StateObject private var model = NowModel()
    @EnvironmentObject var units: Units
    @State private var showWaterSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Status bar row
                HStack {
                    Text("tyfi")
                        .font(.system(size: 19, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.accent)
                    Spacer()
                    Text("9:41")
                        .font(.system(size: 21, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.accent)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 10)
                .padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 13) {
                    // Stale-data banner when serving last-good snapshot offline
                    if let since = model.staleSince {
                        staleBanner(since)
                    }

                    // Insight line
                    if let s = model.snapshot {
                        insightLine(s)
                    }

                    // 2×2 WMP grid
                    if let s = model.snapshot {
                        wmGrid(s)
                    } else if model.loading {
                        ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        placeholderCard
                    }

                    // Action row
                    actionRow
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.bottom, 16)
            }
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
        .sheet(isPresented: $showWaterSheet) { waterAmountSheet }
    }

    // MARK: — Insight line
    @ViewBuilder private func insightLine(_ s: Snapshot) -> some View {
        let text = s.readiness?.focus ?? "HRV below band — Z2 30m & protein 160g today."
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Tokens.C.warn)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Tokens.C.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: — 2×2 WMP grid
    @ViewBuilder private func wmGrid(_ s: Snapshot) -> some View {
        let cols = [GridItem(.flexible(), spacing: Tokens.S.gap),
                    GridItem(.flexible(), spacing: Tokens.S.gap)]
        LazyVGrid(columns: cols, spacing: Tokens.S.gap) {
            // Water tile
            let waterMl   = s.water_today?.ml ?? 0
            let waterGoal = s.water_today?.goal_ml ?? 2500
            let waterPct  = waterGoal > 0 ? waterMl / waterGoal : 0
            WMPTile(
                kicker: "Water",
                value: units.fmtLNum(waterMl),
                unit: units.fmtLUnit(),
                ringPct: waterPct,
                ringColor: Tokens.C.cool,
                tint: Tokens.C.cool.opacity(0.14),
                icon: "drop.fill"
            )
            .valueBump(on: model.waterBump)

            // Thermal tile
            let thermalDelta = s.last_thermal_session?.temp_f.map { units.tempDelta($0, base: 37.0) } ?? "+0.2°"
            WMPTile(
                kicker: "Thermal",
                value: thermalDelta,
                ringPct: 0.7,
                ringColor: Tokens.C.good,
                tint: Tokens.C.good.opacity(0.12),
                icon: "thermometer"
            )

            // Protocol tile
            let done  = s.protocol_progress?.done  ?? 0
            let total = s.protocol_progress?.total ?? 9
            let protoPct = total > 0 ? Double(done) / Double(total) : 0
            WMPTile(
                kicker: s.protocol_progress?.current_segment ?? "Protocol",
                value: "\(done)/\(total)",
                ringPct: protoPct,
                ringColor: Tokens.C.warn,
                tint: Tokens.C.warn.opacity(0.14),
                icon: "pills.fill"
            )

            // Venue tile
            WMPTile(
                kicker: "Venue",
                value: "PHX",
                ringPct: 1.0,
                ringColor: Tokens.C.cool,
                tint: Tokens.C.cool.opacity(0.14),
                icon: "mappin.circle.fill"
            )
        }
    }

    // MARK: — Action row
    private var actionRow: some View {
        HStack(spacing: 10) {
            // +250 water — tap logs, long-press shows sheet
            Button {
                Task { await model.logWater(ml: 250) }
            } label: {
                VStack(spacing: 1) {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("+250")
                            .font(.system(size: 16, weight: .semibold).monospacedDigit())
                    }
                    .foregroundStyle(Tokens.C.accent)
                    Text("HOLD TO SET")
                        .font(.system(size: 8.5, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Tokens.C.accent.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .frame(height: Tokens.S.tapH)
                .background(Tokens.C.accent.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: Tokens.S.pillRadius))
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.36).onEnded { _ in showWaterSheet = true }
            )

            // Mic — orange circle
            Button { } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.black)
                    .frame(width: Tokens.S.tapH, height: Tokens.S.tapH)
                    .background(Tokens.C.accent, in: RoundedRectangle(cornerRadius: Tokens.S.pillRadius))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voice capture")

            // Thermal quick-log
            Button { } label: {
                Image(systemName: "thermometer")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Tokens.C.ink2)
                    .frame(width: Tokens.S.tapH, height: Tokens.S.tapH)
                    .background(Tokens.C.card,
                                in: RoundedRectangle(cornerRadius: Tokens.S.pillRadius))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log thermal session")
        }
    }

    // MARK: — Water amount sheet
    private var waterAmountSheet: some View {
        VStack(spacing: 12) {
            KickerLabel(text: "Water Amount")
                .padding(.top, 4)
            let cols = [GridItem(.flexible(), spacing: Tokens.S.gap),
                        GridItem(.flexible(), spacing: Tokens.S.gap)]
            LazyVGrid(columns: cols, spacing: Tokens.S.gap) {
                ForEach([250.0, 500.0, 750.0, 1000.0], id: \.self) { ml in
                    Button {
                        showWaterSheet = false
                        Task { await model.logWater(ml: ml) }
                    } label: {
                        VStack(spacing: 2) {
                            Text("+\(units.fmtMlNum(ml))")
                                .font(.system(size: 20, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Tokens.C.cool)
                            Text(units.volUnit())
                                .font(.system(size: 11))
                                .foregroundStyle(Tokens.C.ink3)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: WatchScreen.tapH)
                        .background(Tokens.C.cool.opacity(0.16),
                                    in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Tokens.S.hPad)
        .background(Tokens.C.bg)
    }

    // MARK: — Stale banner
    @ViewBuilder private func staleBanner(_ since: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.C.warn)
            Text("Offline · showing data from \(since)")
                .font(.system(size: 11.5))
                .foregroundStyle(Tokens.C.ink2)
            Spacer()
            Button { Task { await model.load() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.C.warn)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Tokens.C.warn.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var placeholderCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.error ?? "No snapshot yet")
                    .font(Type.body_).foregroundStyle(Tokens.C.ink2)
                Text(model.error == "Offline"
                     ? "Couldn’t reach TyFi. Pull to retry."
                     : "Pair this watch in TyFi to start syncing.")
                    .font(Type.caption).foregroundStyle(Tokens.C.ink3)
                Button { Task { await model.load() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .semibold))
                        Text("Retry").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Tokens.C.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }
}

// MARK: — Units extension helpers
extension Units {
    func fmtLNum(_ ml: Double) -> String {
        metricVolume ? String(format: "%.1f", ml / 1000) : String(format: "%.0f", ml / 29.5735)
    }
    func fmtLUnit() -> String { metricVolume ? "L" : "oz" }
    func fmtMlNum(_ ml: Double) -> String {
        metricVolume ? "\(Int(ml.rounded()))" : String(format: "%.0f", ml / 29.5735)
    }
    func volUnit() -> String { metricVolume ? "ml" : "oz" }
    func tempDelta(_ f: Double, base: Double) -> String {
        let delta = f - base
        if celsius {
            let c = delta * 5 / 9
            return String(format: "%+.1f°", c)
        }
        return String(format: "%+.1f°", delta)
    }
}

#Preview { NowView().environmentObject(Units.shared) }

