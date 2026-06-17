import SwiftUI

/// Wind Down — /api/watch/winddown (watch-auth; Eight Sleep temp + checklist).
/// Uses WindDownData from Models.swift — verified frozen contract 2026-06-14.
@MainActor
final class WindDownModel: ObservableObject {
    @Published var data: WindDownData?
    @Published var checklist: [WindDownData.WindDownItem] = []
    @Published var error: String?
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        do {
            data = try await API.shared.get("/api/watch/winddown", as: WindDownData.self)
            checklist = data?.checklist ?? []
            error = nil
        } catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func setTemp(_ t: Double) async {
        _ = try? await API.shared.post("/api/watch/winddown",
            body: WindDownSetTempBody(temp_f: t), as: WindDownSetTempResult.self)
    }
}

struct WindDownView: View {
    @StateObject private var model = WindDownModel()
    @State private var targetTempF: Double = 65

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                HStack {
                    Image(systemName: "moon.stars").foregroundStyle(Tokens.C.sleep)
                    Text("Wind Down").font(Type.label).foregroundStyle(Tokens.C.ink)
                    Spacer()
                }
                if model.loading {
                    ProgressView().tint(Tokens.C.accent).frame(maxWidth: .infinity)
                } else {
                    if let es = model.data?.eight_sleep {
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
                                    Task { await model.setTemp(targetTempF) }
                                }
                                .font(Type.caption)
                                .tint(Tokens.C.cool)
                            }
                        }
                        .onAppear { targetTempF = es.targetTempF ?? 65 }
                    }
                    ForEach(model.checklist.indices, id: \.self) { i in
                        Button {
                            let cur = model.checklist[i].done ?? false
                            model.checklist[i] = WindDownData.WindDownItem(
                                id: model.checklist[i].id,
                                label: model.checklist[i].label,
                                done: !cur)
                        } label: {
                            let item = model.checklist[i]
                            HStack {
                                Image(systemName: (item.done ?? false) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle((item.done ?? false) ? Tokens.C.good : Tokens.C.ink3)
                                Text(item.label ?? "").font(Type.body).foregroundStyle(Tokens.C.ink)
                                Spacer()
                            }
                            .padding(6)
                            .background(Tokens.C.card)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                        }
                        .buttonStyle(.plain)
                    }
                    if let e = model.error {
                        Text(e).font(Type.caption).foregroundStyle(Tokens.C.warn)
                    }
                }
            }
            .padding(Tokens.S.gutter)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }
}

#Preview { WindDownView() }
