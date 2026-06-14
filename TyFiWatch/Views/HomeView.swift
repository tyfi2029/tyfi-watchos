import SwiftUI

struct HomeView: View {
    struct Scene: Decodable, Identifiable {
        let id: Int
        let name: String
        let label: String
        let icon: String
    }
    struct HomeData: Decodable { let scenes: [Scene] }

    @State private var scenes: [Scene] = []
    @State private var isLoading = true
    @State private var triggered: Int? = nil

    private let iconMap: [String: String] = [
        "house":     "house.fill",
        "bed":       "bed.double.fill",
        "lightbulb": "lightbulb.fill",
        "moon":      "moon.fill",
        "sun":       "sun.max.fill",
        "film":      "film",
        "dumbbell":  "dumbbell.fill",
        "tv":        "tv.fill",
        "music":     "music.note",
        "star":      "star.fill",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                HStack {
                    Image(systemName: "house.fill").foregroundStyle(Tokens.C.warn)
                    Text("Home").font(Type.label).foregroundStyle(Tokens.C.ink)
                    Spacer()
                }
                if isLoading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else if scenes.isEmpty {
                    Card {
                        Text("No scenes configured").font(Type.caption).foregroundStyle(Tokens.C.ink2)
                    }
                } else {
                    let cols = [GridItem(.flexible(), spacing: Tokens.S.gutter),
                                GridItem(.flexible(), spacing: Tokens.S.gutter)]
                    LazyVGrid(columns: cols, spacing: Tokens.S.gutter) {
                        ForEach(scenes) { s in
                            Button {
                                Task { await trigger(s) }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: iconMap[s.icon] ?? "circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(triggered == s.id ? Tokens.C.good : Tokens.C.warn)
                                    Text(s.label)
                                        .font(Type.caption)
                                        .foregroundStyle(Tokens.C.ink)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(triggered == s.id
                                    ? Tokens.C.good.opacity(0.15)
                                    : Tokens.C.card)
                                .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                            }
                            .buttonStyle(.plain)
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
        let d = try? await API.shared.get("/api/watch/home", as: HomeData.self)
        scenes = d?.scenes ?? []
        isLoading = false
    }

    private func trigger(_ s: Scene) async {
        struct Body: Encodable { let routine_id: Int }
        struct Result: Decodable { let triggered: Bool? }
        _ = try? await API.shared.post("/api/watch/home", body: Body(routine_id: s.id), as: Result.self)
        triggered = s.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { triggered = nil }
    }
}

#Preview { HomeView() }
