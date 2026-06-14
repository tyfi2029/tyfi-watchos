import SwiftUI

struct CheckInView: View {
    struct Venue: Decodable, Identifiable {
        let id: Int
        let name: String
        let distance_mi: Double?
        let last_visited_at: String?
    }
    struct NearbyData: Decodable { let venues: [Venue] }

    @State private var venues: [Venue] = []
    @State private var isLoading = true
    @State private var checkedIn: Int? = nil
    @State private var checkinName: String = ""
    @State private var rating: Int = 0
    @State private var showRating = false

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                HStack {
                    Image(systemName: "mappin.circle").foregroundStyle(Tokens.C.accent)
                    Text("Check In").font(Type.label).foregroundStyle(Tokens.C.ink)
                    Spacer()
                }
                if isLoading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else if venues.isEmpty {
                    Card {
                        Text("No venues nearby").font(Type.caption).foregroundStyle(Tokens.C.ink2)
                    }
                } else {
                    ForEach(venues.prefix(8)) { v in
                        Button {
                            Task { await checkIn(v) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(v.name).font(Type.body)
                                        .foregroundStyle(checkedIn == v.id ? Tokens.C.good : Tokens.C.ink)
                                    if let d = v.distance_mi {
                                        Text(String(format: "%.1f mi", d))
                                            .font(Type.caption).foregroundStyle(Tokens.C.ink3)
                                    }
                                }
                                Spacer()
                                if checkedIn == v.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.C.good)
                                }
                            }
                            .padding(8)
                            .background(Tokens.C.card)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                        }
                        .buttonStyle(.plain)
                    }
                    if showRating {
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Rate: \(checkinName)").font(Type.caption).foregroundStyle(Tokens.C.ink2)
                                HStack {
                                    ForEach(1...5, id: \.self) { i in
                                        Button {
                                            rating = i
                                        } label: {
                                            Image(systemName: i <= rating ? "star.fill" : "star")
                                                .foregroundStyle(i <= rating ? Tokens.C.warn : Tokens.C.ink3)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                Button("Submit") {
                                    Task { await submitRating() }
                                }
                                .font(Type.caption).tint(Tokens.C.accent)
                            }
                        }
                    }
                }
            }
            .padding(Tokens.S.gutter)
        }
        .background(Tokens.C.bg)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        let data = try? await API.shared.get("/api/watch/venue/nearby", as: NearbyData.self)
        venues = data?.venues ?? []
        isLoading = false
    }

    private func checkIn(_ v: Venue) async {
        struct Body: Encodable { let venue_id: Int; let checked_in_at: String }
        struct Result: Decodable { let checkin_id: String? }
        let body = Body(venue_id: v.id, checked_in_at: ISO8601DateFormatter().string(from: Date()))
        _ = try? await API.shared.post("/api/watch/venue/checkin", body: body, as: Result.self)
        checkedIn = v.id
        checkinName = v.name
        showRating = true
    }

    private func submitRating() async {
        guard let id = checkedIn, rating > 0 else { showRating = false; return }
        struct Body: Encodable { let venue_id: Int; let rating: Int }
        struct Result: Decodable { let ok: Bool? }
        _ = try? await API.shared.post("/api/watch/venue/rate", body: Body(venue_id: id, rating: rating), as: Result.self)
        showRating = false
    }
}

#Preview { CheckInView() }
