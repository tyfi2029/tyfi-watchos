import SwiftUI

/// Home scenes — /api/watch/home (GET list) + POST to trigger a routine.
/// Uses HomeData and HomeScene from Models.swift — verified frozen contract 2026-06-14.
@MainActor
final class HomeModel: ObservableObject {
    @Published var scenes: [HomeScene] = []
    @Published var error: String?
    @Published var loading = false
    @Published var triggered: Int? = nil

    func load() async {
        loading = true; defer { loading = false }
        do {
            let data = try await API.shared.get("/api/watch/home", as: HomeData.self)
            scenes = data.scenes ?? []
            error = nil
        } catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func trigger(_ s: HomeScene) async {
        _ = try? await API.shared.post(
            "/api/watch/home",
            body: HomeTriggerBody(routine_id: s.id ?? 0),
            as: HomeTriggerResult.self)
        triggered = s.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.triggered = nil
        }
    }
}

struct HomeView: View {
    @StateObject private var model = HomeModel()

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
                if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else if model.scenes.isEmpty {
                    Card {
                        Text(model.error ?? "No scenes configured").font(Type.caption).foregroundStyle(Tokens.C.ink2)
                    }
                } else {
                    let cols = [GridItem(.flexible(), spacing: Tokens.S.gutter),
                                GridItem(.flexible(), spacing: Tokens.S.gutter)]
                    LazyVGrid(columns: cols, spacing: Tokens.S.gutter) {
                        ForEach(model.scenes) { s in
                            Button {
                                Task { await model.trigger(s) }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: iconMap[s.icon ?? ""] ?? "circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(model.triggered == s.id ? Tokens.C.good : Tokens.C.warn)
                                    Text(s.label ?? "")
                                        .font(Type.caption)
                                        .foregroundStyle(Tokens.C.ink)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(model.triggered == s.id
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
        .task { await model.load() }
    }
}

#Preview { HomeView() }
