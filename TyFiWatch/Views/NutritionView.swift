import SwiftUI

@MainActor
final class NutritionModel: ObservableObject {
    @Published var data: NutritionData?
    @Published var error: String?
    @Published var loading = false
    @Published var bump = 0

    func load() async {
        loading = true; defer { loading = false }
        do { data = try await API.shared.get("/api/watch/nutrition", as: NutritionData.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func quickAdd(category: String, protein: Int = 0, carbs: Int = 0, fat: Int = 0) async {
        // Optimistic local update
        if var t = data?.today {
            let updated = NutritionData.MacroTotals(
                calories: (t.calories ?? 0) + protein * 4 + carbs * 4 + fat * 9,
                protein:  (t.protein  ?? 0) + protein,
                carbs:    (t.carbs    ?? 0) + carbs,
                fat:      (t.fat      ?? 0) + fat,
                meal_count: t.meal_count,
                last_logged: t.last_logged)
            data = NutritionData(today: updated, glucose: data?.glucose, targets: data?.targets)
        }
        bump += 1
        let body = QuickLogBody(category: category, text: nil,
                                logged_at: ISO8601DateFormatter().string(from: Date()),
                                metadata: nil)
        _ = try? await API.shared.post("/api/watch/quick-log", body: body, as: QuickLogResult.self)
    }
}

/// Screen 20 — Nutrition.
/// Layout: status bar → 3 macro rings side-by-side → calories + protein-left row → quick-add 2×2 grid.
struct NutritionView: View {
    @StateObject private var model = NutritionModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 16))
                            .foregroundStyle(Tokens.C.accent)
                        Text("Nutrition")
                            .font(.system(size: 19, weight: .semibold))
                            .lineLimit(1)
                    }
                    Spacer()
                    if let g = model.data?.glucose?.glucose {
                        Text("\(g)")
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(glucoseColor(g))
                        + Text(" mg/dL")
                            .font(.system(size: 11))
                            .foregroundStyle(Tokens.C.ink2)
                    }
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 10)
                .padding(.bottom, 12)

                if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    VStack(spacing: 14) {
                        // 3 macro rings
                        HStack(spacing: 14) {
                            macroRing(label: "Protein",
                                      value: model.data?.today?.protein ?? 0,
                                      target: model.data?.targets?.protein ?? 160,
                                      color: Tokens.C.good)
                            macroRing(label: "Carbs",
                                      value: model.data?.today?.carbs ?? 0,
                                      target: model.data?.targets?.carbs ?? 200,
                                      color: Tokens.C.accent)
                            macroRing(label: "Fat",
                                      value: model.data?.today?.fat ?? 0,
                                      target: model.data?.targets?.fat ?? 70,
                                      color: Tokens.C.warn)
                        }
                        .padding(.horizontal, Tokens.S.hPad)
                        .valueBump(on: model.bump)

                        // Calories + protein-left
                        HStack(spacing: Tokens.S.gap) {
                            StatTile(label: "Calories",
                                     value: "\(model.data?.today?.calories ?? 0)",
                                     unit: "kcal",
                                     color: Tokens.C.accent)
                            let protLeft = max(0, (model.data?.targets?.protein ?? 160) - (model.data?.today?.protein ?? 0))
                            StatTile(label: "Protein left",
                                     value: "\(protLeft)",
                                     unit: "g",
                                     color: protLeft > 50 ? Tokens.C.warn : Tokens.C.good)
                        }
                        .padding(.horizontal, Tokens.S.hPad)

                        // Quick-add 2×2
                        let cols = [GridItem(.flexible(), spacing: Tokens.S.gap),
                                    GridItem(.flexible(), spacing: Tokens.S.gap)]
                        LazyVGrid(columns: cols, spacing: Tokens.S.gap) {
                            quickAddTile(label: "Protein shake", icon: "cup.and.saucer.fill",
                                         color: Tokens.C.good, category: "protein_shake",
                                         protein: 30)
                            quickAddTile(label: "Meal", icon: "fork.knife",
                                         color: Tokens.C.accent, category: "meal",
                                         protein: 40, carbs: 50, fat: 15)
                            quickAddTile(label: "Snack", icon: "leaf.fill",
                                         color: Tokens.C.warn, category: "snack",
                                         protein: 10, carbs: 20, fat: 5)
                            quickAddTile(label: "Scan meal", icon: "camera.fill",
                                         color: Tokens.C.cool, category: "scan")
                        }
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

    // MARK: — Macro ring tile
    @ViewBuilder
    private func macroRing(label: String, value: Int, target: Int, color: Color) -> some View {
        let pct = target > 0 ? min(1.0, Double(value) / Double(target)) : 0
        VStack(spacing: 8) {
            ZStack {
                Ring(progress: pct, color: color, lineWidth: 7)
                    .frame(width: 72, height: 72)
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(size: 20, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.ink)
                    Text("g")
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.C.ink3)
                }
            }
            VStack(spacing: 1) {
                // caption2 with lineLimit(1) so "Protein" / "Carbs" / "Fat" never clips
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Tokens.C.ink3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
                Text("/\(target)g")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink3)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: — Quick-add tile
    @ViewBuilder
    private func quickAddTile(label: String, icon: String, color: Color, category: String,
                               protein: Int = 0, carbs: Int = 0, fat: Int = 0) -> some View {
        Button {
            Task { await model.quickAdd(category: category, protein: protein, carbs: carbs, fat: fat) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Tokens.C.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 64)
            .padding(.horizontal, 12)
            .background(Tokens.C.card,
                        in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
        }
        .buttonStyle(.plain)
        .pressScale()
    }

    private func glucoseColor(_ mg: Int) -> Color {
        switch mg {
        case ..<70: return Tokens.C.bad
        case 70..<100: return Tokens.C.good
        case 100..<140: return Tokens.C.warn
        default: return Tokens.C.bad
        }
    }
}

#Preview { NutritionView() }
