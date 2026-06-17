import SwiftUI

@MainActor
final class HomeModel: ObservableObject {
    @Published var scenes: [HomeScene] = []
    @Published var selectedScene: Int? = nil
    @Published var thermoF: Double = 72
    @Published var error: String?
    @Published var loading = false
    @Published var triggered: Int? = nil

    // Room device states
    @Published var lightsOn = true
    @Published var lockedOn = true
    @Published var blindsOn = false
    @Published var cameraOn = false

    func load() async {
        loading = true; defer { loading = false }
        do {
            let data = try await API.shared.get("/api/watch/home", as: HomeData.self)
            scenes = data.scenes ?? []
            error = nil
        }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func trigger(_ s: HomeScene) async {
        selectedScene = s.id
        _ = try? await API.shared.post("/api/watch/home",
            body: HomeTriggerBody(routine_id: s.id ?? 0), as: HomeTriggerResult.self)
        triggered = s.id
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        triggered = nil
    }
}

/// Screen 12 — Home.
/// Layout: scene chips (horizontal scroll) → thermostat card (−/+ steppers) → room toggle grid.
struct HomeView: View {
    @StateObject private var model = HomeModel()
    @EnvironmentObject var units: Units

    private let defaultScenes = ["Morning", "Away", "Evening", "Sleep", "Movie", "Workout"]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Tokens.C.warn)
                        Text("Home")
                            .font(.system(size: 19, weight: .semibold))
                    }
                    Spacer()
                    Text("9:41")
                        .font(.system(size: 21, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.accent)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 10)
                .padding(.bottom, 12)

                VStack(spacing: 14) {
                    // Scene chips scrollable row
                    sceneChips

                    // Thermostat card
                    thermostatCard

                    // Room toggle 2×2 grid
                    roomToggles
                }
                .padding(.bottom, 16)
            }
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    // MARK: — Scene chips
    private var sceneChips: some View {
        let displayScenes = model.scenes.isEmpty
            ? defaultScenes.map { HomeScene(id: Int($0.hashValue), name: $0, label: $0, icon: nil) }
            : model.scenes
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(displayScenes) { s in
                    Button {
                        let wasSelected = model.selectedScene == s.id
                        model.selectedScene = wasSelected ? nil : s.id
                        if !wasSelected { Task { await model.trigger(s) } }
                    } label: {
                        Text(s.label ?? s.name ?? "")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(model.selectedScene == s.id ? Color.black : Tokens.C.ink2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                model.selectedScene == s.id ? Tokens.C.accent : Tokens.C.card,
                                in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .pressScale()
                }
            }
            .padding(.horizontal, Tokens.S.hPad)
        }
    }

    // MARK: — Thermostat card
    private var thermostatCard: some View {
        HStack(spacing: 0) {
            // − button
            Button {
                withAnimation(Motion.press) { model.thermoF = max(60, model.thermoF - 1) }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Tokens.C.ink2)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 3) {
                Text(units.celsius
                     ? String(format: "%.0f°C", (model.thermoF - 32) * 5 / 9)
                     : String(format: "%.0f°F", model.thermoF))
                    .font(.system(size: 40, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink)
                KickerLabel(text: "Thermostat")
            }

            Spacer()

            // + button
            Button {
                withAnimation(Motion.press) { model.thermoF = min(85, model.thermoF + 1) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Tokens.C.ink2)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.S.hPad)
        .padding(.vertical, 16)
        .background(Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
        .padding(.horizontal, Tokens.S.hPad)
    }

    // MARK: — Room toggle grid
    private var roomToggles: some View {
        let cols = [GridItem(.flexible(), spacing: Tokens.S.gap),
                    GridItem(.flexible(), spacing: Tokens.S.gap)]
        return LazyVGrid(columns: cols, spacing: Tokens.S.gap) {
            toggleTile(icon: "lightbulb.fill", label: "Lights",  isOn: $model.lightsOn)
            toggleTile(icon: "lock.fill",      label: "Lock",    isOn: $model.lockedOn)
            toggleTile(icon: "blinds.horizontal.closed", label: "Blinds", isOn: $model.blindsOn)
            toggleTile(icon: "video.fill",     label: "Camera",  isOn: $model.cameraOn)
        }
        .padding(.horizontal, Tokens.S.hPad)
    }

    @ViewBuilder
    private func toggleTile(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        Button { withAnimation(Motion.press) { isOn.wrappedValue.toggle() } } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(isOn.wrappedValue ? Tokens.C.accent : Tokens.C.ink3)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue ? Tokens.C.ink : Tokens.C.ink3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isOn.wrappedValue ? Tokens.C.accent.opacity(0.14) : Tokens.C.card,
                        in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
        }
        .buttonStyle(.plain)
        .pressScale()
    }
}

#Preview { HomeView().environmentObject(Units.shared) }
