import SwiftUI

@MainActor
final class CheckInModel: ObservableObject {
    @Published var venues: [Venue] = []
    @Published var error: String?
    @Published var loading = false
    @Published var checkedInId: Int? = nil
    @Published var checkedInName = ""
    @Published var showRating = false
    @Published var rating = 0
    @Published var checkinTime = ""

    func load() async {
        loading = true; defer { loading = false }
        do {
            venues = try await API.shared.get("/api/watch/venue/nearby", as: VenueList.self).venues ?? []
            error = nil
        }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func checkIn(_ v: Venue) async {
        let now = Date()
        let fmt = DateFormatter(); fmt.dateFormat = "h:mm"
        checkinTime = fmt.string(from: now)
        let body = VenueCheckinBody(venue_id: v.id ?? 0,
            checked_in_at: ISO8601DateFormatter().string(from: now), lat: nil, lng: nil)
        _ = try? await API.shared.post("/api/watch/venue/checkin", body: body, as: VenueCheckinResult.self)
        checkedInId = v.id
        checkedInName = v.name ?? ""
        Haptics.success()
        withAnimation { showRating = true }
    }

    func submitRating() async {
        guard let id = checkedInId, rating > 0 else { showRating = false; return }
        let body = VenueRatingBody(venue_id: id, stars: rating,
            rated_at: ISO8601DateFormatter().string(from: Date()))
        _ = try? await API.shared.post("/api/watch/venue/rate", body: body, as: VenueRatingResult.self)
        showRating = false
    }
}

/// Screen 13 — Check In.
/// Layout: location header → banner (current status) → venue list rows → rating inline.
struct CheckInView: View {
    @StateObject private var model = CheckInModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .lastTextBaseline) {
                    Text("Check in")
                        .font(.system(size: 21, weight: .semibold))
                    Spacer()
                    Text("9:41")
                        .font(.system(size: 18, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.accent)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 16)
                .padding(.bottom, 4)

                // Location sub-line
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.C.accent)
                    Text("Phoenix, AZ · PHX")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Tokens.C.ink2)
                    Text("· GPS active")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.C.ink3)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.bottom, 13)

                // Current status banner
                currentBanner
                    .padding(.horizontal, Tokens.S.hPad)
                    .padding(.bottom, 13)

                if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                } else if model.venues.isEmpty {
                    Text(model.error ?? "No venues nearby")
                        .font(Type.caption).foregroundStyle(Tokens.C.ink2)
                        .padding(.horizontal, Tokens.S.hPad)
                } else {
                    VStack(spacing: 9) {
                        ForEach(model.venues.prefix(8)) { v in
                            venueRow(v)
                        }
                        // Inline rating
                        if model.showRating {
                            ratingCard
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, Tokens.S.hPad)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    private var currentBanner: some View {
        HStack(spacing: 11) {
            Image(systemName: model.checkedInId != nil ? "checkmark.circle.fill" : "mappin")
                .font(.system(size: 16))
                .foregroundStyle(model.checkedInId != nil ? Tokens.C.good : Tokens.C.ink3)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.checkedInId != nil
                     ? "\(model.checkedInName)"
                     : "Not checked in")
                    .font(.system(size: 13.5))
                    .foregroundStyle(model.checkedInId != nil ? Tokens.C.ink : Tokens.C.ink2)
                if model.checkedInId != nil {
                    Text("checked in \(model.checkinTime)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Tokens.C.good)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func venueRow(_ v: Venue) -> some View {
        Button { Task { await model.checkIn(v) } } label: {
            HStack(spacing: 13) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(model.checkedInId == v.id ? Tokens.C.good : Tokens.C.cool)
                VStack(alignment: .leading, spacing: 2) {
                    Text(v.name ?? "")
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundStyle(model.checkedInId == v.id ? Tokens.C.good : Tokens.C.ink)
                    HStack(spacing: 6) {
                        if let d = v.distance_mi {
                            Text(String(format: "%.1f mi", d))
                                .font(.system(size: 11.5).monospacedDigit())
                                .foregroundStyle(Tokens.C.ink3)
                        }
                        if let status = v.open_status, !status.isEmpty {
                            Text("· \(status)")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Tokens.C.ink3)
                        }
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(model.checkedInId == v.id ? Tokens.C.good : Color.white.opacity(0.22),
                                      lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if model.checkedInId == v.id {
                        Circle().fill(Tokens.C.good).frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.black)
                    }
                }
            }
            .padding(14)
            .background(model.checkedInId == v.id ? Tokens.C.good.opacity(0.10) : Tokens.C.card,
                        in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rate \(model.checkedInName)")
                .font(.system(size: 13))
                .foregroundStyle(Tokens.C.ink2)
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Button { model.rating = i } label: {
                        Image(systemName: i <= model.rating ? "star.fill" : "star")
                            .font(.system(size: 20))
                            .foregroundStyle(i <= model.rating ? Tokens.C.warn : Tokens.C.ink3)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button { Task { await model.submitRating() } } label: {
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(model.rating > 0 ? Tokens.C.accent : Tokens.C.ink3)
                }
                .buttonStyle(.plain)
                .disabled(model.rating == 0)
            }
        }
        .padding(14)
        .background(Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
    }
}

#Preview { CheckInView() }
