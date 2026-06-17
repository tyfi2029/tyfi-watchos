import SwiftUI

/// Nutrition — /api/watch/nutrition (watch-auth; daily macros + CGM overlay).
/// Uses NutritionData from Models.swift — verified frozen contract 2026-06-14.
@MainActor
final class NutritionModel: ObservableObject {
    @Published var data: NutritionData?
    @Published var error: String?
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        do { data = try await API.shared.get("/api/watch/nutrition", as: NutritionData.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }
}

struct NutritionView: View {
    @StateObject private var model = NutritionModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Tokens.C.accent)
                    Text("Nutrition")
                        .font(Type.label)
                        .foregroundStyle(Tokens.C.ink)
                    Spacer()
                    if let cgm = model.data?.glucose {
                        Text("\(cgm.glucose ?? 0)")
                            .font(Type.metric(13))
                            .foregroundStyle(glucoseColor(cgm.glucose ?? 0))
                        + Text(" mg/dL")
                            .font(Type.caption)
                            .foregroundStyle(Tokens.C.ink2)
                    }
                }

                if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else if let d = model.data {
                    MacroRow(label: "Calories",
                             value: d.today?.calories ?? 0,
                             target: d.targets?.calories ?? 0,
                             unit: "kcal",
                             color: Tokens.C.accent)
                    MacroRow(label: "Protein",
                             value: d.today?.protein ?? 0,
                             target: d.targets?.protein ?? 0,
                             unit: "g",
                             color: Tokens.C.good)
                    MacroRow(label: "Carbs",
                             value: d.today?.carbs ?? 0,
                             target: d.targets?.carbs ?? 0,
                             unit: "g",
                             color: Tokens.C.warn)
                    MacroRow(label: "Fat",
                             value: d.today?.fat ?? 0,
                             target: d.targets?.fat ?? 0,
                             unit: "g",
                             color: Tokens.C.cool)

                    let meals = d.today?.meal_count ?? 0
                    if meals > 0 {
                        Text("\(meals) meal\(meals == 1 ? "" : "s") today")
                            .font(Type.caption)
                            .foregroundStyle(Tokens.C.ink3)
                    } else {
                        Text("No meals logged today")
                            .font(Type.caption)
                            .foregroundStyle(Tokens.C.ink3)
                    }
                } else if let e = model.error {
                    Text(e).font(Type.caption).foregroundStyle(Tokens.C.bad)
                }
            }
            .padding(Tokens.S.gutter)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
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

private struct MacroRow: View {
    let label: String
    let value: Int
    let target: Int
    let unit: String
    let color: Color

    var pct: Double { target > 0 ? min(1.0, Double(value) / Double(target)) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(Type.caption)
                    .foregroundStyle(Tokens.C.ink2)
                Spacer()
                Text("\(value)/\(target) \(unit)")
                    .font(Type.caption)
                    .foregroundStyle(Tokens.C.ink)
                    .tabularDigits()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Tokens.C.card)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * pct, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

#Preview { NutritionView() }
