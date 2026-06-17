import SwiftUI

@MainActor
final class ReadinessModel: ObservableObject {
    @Published var r: Snapshot.Readiness?
    @Published var error: String?

    func load() async {
        do {
            r = try await API.shared.get("/api/watch/snapshot", as: Snapshot.self).readiness
            error = nil
        }
        catch APIError.notAuthed { self.error = "Pair watch" }
        catch { self.error = "Offline" }
    }
}

/// Screen 2 — Readiness (6:42 wake glance).
/// Layout: status bar → big recovery ring (172 pt, lineWidth 14) →
///         3-stat pill row → "TODAY'S FOCUS" accent-tinted card.
struct ReadinessView: View {
    @StateObject private var model = ReadinessModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    HStack(spacing: 7) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Tokens.C.accent)
                        Text("Readiness")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Tokens.C.ink)
                    }
                    Spacer()
                    Text("6:42")
                        .font(.system(size: 21, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.accent)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 10)
                .padding(.bottom, 14)

                VStack(spacing: 14) {
                    // Big recovery ring — 172 pt diameter, 14 pt lineWidth
                    ZStack {
                        Ring(progress: Double(model.r?.recovery ?? 0) / 100,
                             color: ringColor, lineWidth: 14)
                            .frame(width: 172, height: 172)
                        VStack(spacing: 1) {
                            Text("\(model.r?.recovery ?? 0)")
                                .font(.system(size: 54, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Tokens.C.ink)
                            Text("RECOVERED")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(2.0)
                                .foregroundStyle(ringColor)
                        }
                    }

                    // 3-stat row: HRV / Sleep / RHR separated by hairlines
                    HStack(spacing: 0) {
                        statPill("HRV", value: "\(model.r?.hrv ?? 0)", unit: "ms",
                                 color: Tokens.C.warn)
                        divider
                        statPill("SLEEP", value: "\(model.r?.sleep ?? 0)", unit: "",
                                 color: Tokens.C.good)
                        divider
                        statPill("RHR", value: "\(model.r?.rhr ?? 0)", unit: "bpm",
                                 color: Tokens.C.good)
                    }
                    .padding(.horizontal, Tokens.S.hPad)

                    // TODAY'S FOCUS card
                    if let focus = model.r?.focus {
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Tokens.C.accent)
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 3) {
                                KickerLabel(text: "Today's Focus", color: Tokens.C.accent)
                                Text(focus)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Tokens.C.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Tokens.C.accent.opacity(0.13),
                                    in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                        .padding(.horizontal, Tokens.S.hPad)
                    }

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

    private var ringColor: Color {
        let v = model.r?.recovery ?? 0
        if v >= 66 { return Tokens.C.good }
        if v >= 34 { return Tokens.C.warn }
        return Tokens.C.bad
    }

    @ViewBuilder
    private func statPill(_ label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 23, weight: .semibold).monospacedDigit())
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.C.ink3)
                }
            }
            KickerLabel(text: label, size: 9.5)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Tokens.C.hairline)
            .frame(width: 1, height: 30)
    }
}

#Preview { ReadinessView().environmentObject(Units.shared) }
