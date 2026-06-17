import SwiftUI

@MainActor
final class FlightModel: ObservableObject {
    @Published var data: FlightData?
    @Published var error: String?
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        do { data = try await API.shared.get("/api/watch/flight", as: FlightData.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }
}

/// Screen 15 — Flight glance.
/// Layout: flight number header → route arc with plane at progress →
///         stats caption → gate/seat/boards tiles → jet-lag card.
struct FlightView: View {
    @StateObject private var model = FlightModel()

    private var flightProgress: Double {
        // Placeholder 64% unless live data provides it
        0.64
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "airplane")
                            .font(.system(size: 16))
                            .foregroundStyle(Tokens.C.accent)
                        Text(model.data?.active_flight?.flight_number ?? "AA 1842")
                            .font(.system(size: 19, weight: .semibold))
                    }
                    Spacer()
                    Text("On time")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tokens.C.good)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 4)
                        .background(Tokens.C.good.opacity(0.16), in: Capsule())
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 10)
                .padding(.bottom, 12)

                if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    VStack(spacing: 12) {
                        // Route row with progress arc
                        routeRow

                        // Stats caption
                        Text("2h12 remaining · FL360 · 543 mph")
                            .font(.system(size: 12.5).monospacedDigit())
                            .foregroundStyle(Tokens.C.ink2)
                            .tracking(0.4)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Gate / Seat / Boards 3-tile row
                        HStack(spacing: Tokens.S.gap) {
                            infoTile(icon: "door.left.hand.open", label: "Gate",   value: "B22")
                            infoTile(icon: "chair.lounge.fill",   label: "Seat",   value: "4C")
                            infoTile(icon: "clock.fill",          label: "Boards", value: "05:45")
                        }
                        .padding(.horizontal, Tokens.S.hPad)

                        // Jet-lag card
                        HStack(spacing: 14) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 21))
                                .foregroundStyle(Tokens.C.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                KickerLabel(text: "Sleep · Eastbound +3H", color: Tokens.C.accent)
                                Text("Skip sleep — nap ≤20m, AM light on arrival")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Tokens.C.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(15)
                        .background(Tokens.C.accent.opacity(0.13),
                                    in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                        .padding(.horizontal, Tokens.S.hPad)

                        if let e = model.error {
                            Text(e).font(Type.caption).foregroundStyle(Tokens.C.warn)
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    // MARK: — Route row
    private var routeRow: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(model.data?.active_flight?.origin ?? "PHX")
                    .font(.system(size: 30, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink)
                Text("06:15")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink3)
            }

            // Progress arc
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 2)
                        .cornerRadius(2)
                    Rectangle()
                        .fill(Tokens.C.accent)
                        .frame(width: geo.size.width * flightProgress, height: 2)
                        .cornerRadius(2)
                    Image(systemName: "airplane")
                        .font(.system(size: 18))
                        .foregroundStyle(Tokens.C.accent)
                        .rotationEffect(.degrees(90))
                        .position(x: geo.size.width * flightProgress,
                                  y: geo.size.height / 2)
                }
                .frame(height: geo.size.height)
            }
            .frame(height: 34)
            .padding(.horizontal, 14)

            VStack(alignment: .trailing, spacing: 1) {
                Text(model.data?.active_flight?.destination ?? "JFK")
                    .font(.system(size: 30, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink)
                Text("14:02")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink3)
            }
        }
        .padding(.horizontal, Tokens.S.hPad)
    }

    // MARK: — Info tile
    @ViewBuilder
    private func infoTile(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Tokens.C.ink2)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 19, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink)
                KickerLabel(text: label)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview { FlightView() }
