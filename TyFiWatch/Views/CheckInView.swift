import SwiftUI

/// Check In — /api/watch/venue/nearby (GET) + /venue/checkin (POST) + /venue/rate (POST).
/// Uses VenueList, VenueCheckinBody, VenueCheckinResult, VenueRatingBody, VenueRatingResult
/// from Models.swift — verified frozen contract 2026-06-14.
@MainActor
final class CheckInModel: ObservableObject {
    @Published var venues: [Venue] = []
    @Published var error: String?
    @Published var loading = false
    @Published var checkedIn: Int? = nil
    @Published var checkinName: String = ""
    @Published var showRating = false
    @Published var rating = 0

    func load() async {
        loading = true; defer { loading = false }
        do {
            let data = try await API.shared.get("/api/watch/venue/nearby", as: VenueList.self)
            venues = data.venues ?? []
            error = nil
        } catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func checkIn(_ v: Venue) async {
        let body = VenueCheckinBody(
            venue_id: v.id ?? 0,
            checked_in_at: ISO8601DateFormatter().string(from: Date()),
            lat: nil, lng: nil)
        _ = try? await API.shared.post("/api/watch/venue/checkin", body: body, as: VenueCheckinResult.self)
        checkedIn = v.id
        checkinName = v.name ?? ""
        showRating = true
    }

    func submitRating() async {
        guard let id = checkedIn, rating > 0 else { showRating = false; return }
        let body = VenueRatingBody(
            venue_id: id, stars: rating,
            rated_at: ISO8601DateFormatter().string(from: Date()))
        _ = try? await API.shared.post("/api/watch/venue/rate", body: body, as: VenueRatingResult.self)
        showRating = false
    }
}

struct CheckInView: View {
    @StateObject private var model = CheckInModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                HStack {
                    Image(systemName: "mappin.circle").foregroundStyle(Tokens.C.accent)
                    Text("Check In").font(Type.label).foregroundStyle(Tokens.C.ink)
                    Spacer()
                }
                if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else if model.venues.isEmpty {
                    Card {
                        Text(model.error ?? "No venues nearby").font(Type.caption).foregroundStyle(Tokens.C.ink2)
                    }
                } else {
                    ForEach(model.venues.prefix(8)) { v in
                        Button {
                            Task { await model.checkIn(v) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(v.name ?? "").font(Type.body)
                                        .foregroundStyle(model.checkedIn == v.id ? Tokens.C.good : Tokens.C.ink)
                                    if let d = v.distance_mi {
                                        Text(String(format: "%.1f mi", d))
                                            .font(Type.caption).foregroundStyle(Tokens.C.ink3)
                                    }
                                }
                                Spacer()
                                if model.checkedIn == v.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.C.good)
                                }
                            }
                            .padding(8)
                            .background(Tokens.C.card)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                        }
                        .buttonStyle(.plain)
                    }
                    if model.showRating {
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Rate: \(model.checkinName)").font(Type.caption).foregroundStyle(Tokens.C.ink2)
                                HStack {
                                    ForEach(1...5, id: \.self) { i in
                                        Button {
                                            model.rating = i
                                        } label: {
                                            Image(systemName: i <= model.rating ? "star.fill" : "star")
                                                .foregroundStyle(i <= model.rating ? Tokens.C.warn : Tokens.C.ink3)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                Button("Submit") {
                                    Task { await model.submitRating() }
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
        .task { await model.load() }
    }
}

#Preview { CheckInView() }
