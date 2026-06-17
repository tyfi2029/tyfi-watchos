import SwiftUI

/// Flight — /api/watch/flight (watch-auth; active flight + jetlag recovery).
/// Uses FlightData from Models.swift — verified frozen contract 2026-06-14.
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

struct FlightView: View {
    @StateObject private var model = FlightModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                HStack {
                    Image(systemName: "airplane").foregroundStyle(Tokens.C.cool)
                    Text("Flight").font(Type.label).foregroundStyle(Tokens.C.ink)
                    Spacer()
                }
                if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else if let f = model.data?.active_flight {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(f.origin ?? "—").font(Type.title).foregroundStyle(Tokens.C.ink)
                                Image(systemName: "arrow.right").foregroundStyle(Tokens.C.ink3)
                                Text(f.destination ?? "—").font(Type.title).foregroundStyle(Tokens.C.ink)
                                Spacer()
                                if let status = f.status {
                                    Text(status.capitalized)
                                        .font(Type.caption)
                                        .foregroundStyle(statusColor(f.status))
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .background(statusColor(f.status).opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            if let fnum = f.flight_number {
                                Text(fnum).font(Type.caption).foregroundStyle(Tokens.C.ink2)
                            }
                            if let dep = f.departure_at {
                                HStack(spacing: 4) {
                                    Text("Dep:").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                                    Text(dep).font(Type.caption).foregroundStyle(Tokens.C.ink2).tabularDigits()
                                }
                            }
                            if let arr = f.arrival_at {
                                HStack(spacing: 4) {
                                    Text("Arr:").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                                    Text(arr).font(Type.caption).foregroundStyle(Tokens.C.ink2).tabularDigits()
                                }
                            }
                        }
                    }
                    if let j = model.data?.jetlag {
                        Card {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("JETLAG").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                                HStack(spacing: Tokens.S.gutter) {
                                    if let dir = j.direction { Text(dir.capitalized).font(Type.body).foregroundStyle(Tokens.C.ink) }
                                    if let hrs = j.hours_shifted { Text(String(format: "%.1fh shift", hrs)).font(Type.caption).foregroundStyle(Tokens.C.ink2).tabularDigits() }
                                    if let day = j.recovery_day { Text("Day \(day)").font(Type.caption).foregroundStyle(Tokens.C.warn) }
                                }
                            }
                        }
                    }
                } else {
                    Card {
                        Text("No active flight").font(Type.caption).foregroundStyle(Tokens.C.ink2)
                    }
                    if let e = model.error {
                        Text(e).font(Type.caption).foregroundStyle(Tokens.C.warn)
                    }
                }
            }
            .padding(Tokens.S.gutter)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    private func statusColor(_ s: String?) -> Color {
        switch s {
        case "in_air", "active": return Tokens.C.good
        case "delayed": return Tokens.C.warn
        case "cancelled": return Tokens.C.bad
        default: return Tokens.C.cool
        }
    }
}

#Preview { FlightView() }
