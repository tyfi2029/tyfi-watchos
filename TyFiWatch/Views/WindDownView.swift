import SwiftUI

struct WindDownView: View {
    struct EightSleepStatus: Decodable {
        let bedTempF: Double?
        let targetTempF: Double?
        let isOn: Bool?
    }
    struct ChecklistItem: Decodable, Identifiable {
        let id: String
        let label: String
        var done: Bool
    }
    struct WindDownData: Decodable {
        let eight_sleep: EightSleepStatus?
        let checklist: [ChecklistItem]
    }

    @State private var data: WindDownData?
    @State private var checklist: [ChecklistItem] = []
    @State private var isLoading = true
    @State private var targetTempF: Double = 65

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                HStack {
                    Image(systemName: "moon.stars").foregroundStyle(Tokens.C.sleep)
                    Text("Wind Down").font(Type.label).foregroundStyle(Tokens.C.ink)
                    Spacer()
                }
                if isLoading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else {
                    if let es = data?.eight_sleep {
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Bed Temp").font(Type.caption).foregroundStyle(Tokens.C.ink2)
                                    Spacer()
                                    Text(es.bedTempF.map { String(format: "%.0f°F", $0) } ?? "—")
                                        .font(Type.metric(14)).foregroundStyle(Tokens.C.cool)
                                }
                                Slider(value: $targetTempF, in: 55...110, step: 1)
                                    .tint(Tokens.C.cool)
                                Button("Set \(Int(targetTempF))°F") {
                                    Task { await setTemp(targetTempF) }
                                }
                                .font(Type.caption)
                                .tint(Tokens.C.cool)
                            }
                        }
                    }
                    ForEach($checklist) { $item in
                        Button {
                            item.done.toggle()
                        } label: {
                            HStack {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.done ? Tokens.C.good : Tokens.C.ink3)
                                Text(item.label).font(Type.body).foregroundStyle(Tokens.C.ink)
                                Spacer()
                            }
                            .padding(6)
                            .background(Tokens.C.card)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                        }
                        .buttonStyle(.plain)
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
        do {
            data = try await API.shared.get("/api/watch/winddown", as: WindDownData.self)
            checklist = data?.checklist ?? []
            targetTempF = data?.eight_sleep?.targetTempF ?? 65
        } catch {}
        isLoading = false
    }

    private func setTemp(_ t: Double) async {
        struct SetTemp: Encodable { let action = "set_temp"; let temp_f: Double }
        struct SetResult: Decodable { let set: Bool? }
        _ = try? await API.shared.post("/api/watch/winddown", body: SetTemp(temp_f: t), as: SetResult.self)
    }
}

#Preview { WindDownView() }
