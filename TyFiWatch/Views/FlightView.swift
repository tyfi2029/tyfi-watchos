import SwiftUI

struct FlightView: View {
    struct Flight: Decodable {
        let flight_number: String?
        let origin: String?
        let destination: String?
        let elapsed_min: Int?
        let remaining_min: Int?
        let progress_pct: Int?
        let in_air: Bool?
    }
    struct FlightData: Decodable { let active_flight: Flight? }

    @State private var data: FlightData?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: Tokens.S.gutter) {
            HStack {
                Image(systemName: "airplane").foregroundStyle(Tokens.C.cool)
                Text("Flight").font(Type.label).foregroundStyle(Tokens.C.ink)
                Spacer()
            }
            if isLoading {
                ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
            } else if let f = data?.active_flight {
                ZStack {
                    Ring(progress: Double(f.progress_pct ?? 0) / 100,
                         color: Tokens.C.cool,
                         lineWidth: 10)
                        .frame(width: 100, height: 100)
                    VStack(spacing: 1) {
                        Text(f.in_air == true ? "In Air" : "Scheduled")
                            .font(Type.caption).foregroundStyle(Tokens.C.ink2)
                        if let rem = f.remaining_min {
                            Text("\(rem / 60)h \(rem % 60)m")
                                .font(Type.metric(16)).foregroundStyle(Tokens.C.ink)
                            Text("remaining").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                        }
                    }
                }
                if let orig = f.origin, let dest = f.destination {
                    HStack {
                        Text(orig).font(Type.title).foregroundStyle(Tokens.C.ink)
                        Image(systemName: "arrow.right").foregroundStyle(Tokens.C.ink3)
                        Text(dest).font(Type.title).foregroundStyle(Tokens.C.ink)
                    }
                }
                if let fnum = f.flight_number {
                    Text(fnum).font(Type.caption).foregroundStyle(Tokens.C.ink2)
                }
            } else {
                Card {
                    Text("No active flight").font(Type.caption).foregroundStyle(Tokens.C.ink2)
                }
            }
        }
        .padding(Tokens.S.gutter)
        .frame(maxHeight: .infinity)
        .background(Tokens.C.bg)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        data = try? await API.shared.get("/api/watch/flight", as: FlightData.self)
        isLoading = false
    }
}

#Preview { FlightView() }
