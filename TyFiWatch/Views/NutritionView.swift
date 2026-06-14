import SwiftUI

struct NutritionView: View {
    struct Macros: Decodable {
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
        let meal_count: Int
        let last_logged: String?
    }
    struct CGM: Decodable {
        let glucose: Int
        let trend: String
        let seconds_ago: Int
    }
    struct Targets: Decodable {
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }
    struct NutritionData: Decodable {
        let today: Macros
        let glucose: CGM?
        let targets: Targets
    }

    @State private var data: NutritionData?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Tokens.C.accent)
                    Text("Nutrition")
                        .font(Type.label)
                        .foregroundStyle(Tokens.C.ink)
                    Spacer()
                    if let cgm = data?.glucose {
                        Text("\(cgm.glucose)")
                            .font(Type.metric(13))
                            .foregroundStyle(glucoseColor(cgm.glucose))
                        + Text(" mg/dL")
                            .font(Type.caption)
                            .foregroundStyle(Tokens.C.ink2)
                    }
                }

                if isLoading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else if let d = data {
                    // Calories
                    MacroRow(label: "Calories",
                             value: d.today.calories,
                             target: d.targets.calories,
                             unit: "kcal",
                             color: Tokens.C.accent)

                    // Protein
                    MacroRow(label: "Protein",
                             value: d.today.protein,
                             target: d.targets.protein,
                             unit: "g",
                             color: Tokens.C.good)

                    // Carbs
                    MacroRow(label: "Carbs",
                             value: d.today.carbs,
                             target: d.targets.carbs,
                             unit: "g",
                             color: Tokens.C.warn)

                    // Fat
                    MacroRow(label: "Fat",
                             value: d.today.fat,
                             target: d.targets.fat,
                             unit: "g",
                             color: Tokens.C.cool)

                    if d.today.meal_count > 0 {
                        Text("\(d.today.meal_count) meal\(d.today.meal_count == 1 ? "" : "s") today")
                            .font(Type.caption)
                            .foregroundStyle(Tokens.C.ink3)
                    } else {
                        Text("No meals logged today")
                            .font(Type.caption)
                            .foregroundStyle(Tokens.C.ink3)
                    }
                } else if let e = error {
                    Text(e).font(Type.caption).foregroundStyle(Tokens.C.bad)
                }
            }
            .padding(Tokens.S.gutter)
        }
        .background(Tokens.C.bg)
        .task { await load() }
    }

    private func glucoseColor(_ mg: Int) -> Color {
        switch mg {
        case ..<70: return Tokens.C.bad
        case 70..<100: return Tokens.C.good
        case 100..<140: return Tokens.C.warn
        default: return Tokens.C.bad
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            data = try await API.shared.get("/api/watch/nutrition", as: NutritionData.self)
        } catch {
            self.error = "Could not load nutrition"
        }
        isLoading = false
    }
}

private struct MacroRow: View {
    let label: String
    let value: Int
    let target: Int
    let unit: String
    let color: Color

    var pct: Double { min(1.0, Double(value) / Double(target)) }

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
