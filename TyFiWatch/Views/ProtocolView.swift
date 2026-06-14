import SwiftUI

@MainActor
final class ProtocolModel: ObservableObject {
    @Published var segments: [ProtocolSegment] = []
    @Published var error: String?

    func load() async {
        do { segments = try await API.shared.get("/api/watch/protocol/today", as: ProtocolToday.self).segments; error = nil }
        catch APIError.notAuthed { self.error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func toggle(_ item: ProtocolItem) async {
        let body = ProtocolToggle(done: !item.done,
                                  toggled_at: ISO8601DateFormatter().string(from: Date()))
        do {
            segments = try await API.shared.post("/api/watch/protocol/item/\(item.id)/toggle",
                                                 body: body, as: ProtocolToday.self).segments
        } catch { /* keep current state; surfaced on next load */ }
    }
}

/// Screen 4 — Protocol. Today's todos grouped by time segment; tap to toggle done.
struct ProtocolView: View {
    @StateObject private var model = ProtocolModel()

    var body: some View {
        List {
            ForEach(model.segments.filter { !$0.items.isEmpty }) { seg in
                Section {
                    ForEach(seg.items) { item in
                        Button { Task { await model.toggle(item) } } label: { row(item) }
                            .listRowBackground(Tokens.C.card)
                    }
                } header: {
                    Text(seg.name.uppercased()).font(Type.caption).foregroundStyle(Tokens.C.accent)
                }
            }
            if model.segments.allSatisfy({ $0.items.isEmpty }) {
                Text(model.error ?? "Nothing scheduled today")
                    .font(Type.caption).foregroundStyle(Tokens.C.ink3)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.carousel)
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    private func row(_ item: ProtocolItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.done ? Tokens.C.good : Tokens.C.ink3)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.label).font(Type.body)
                    .foregroundStyle(item.done ? Tokens.C.ink3 : Tokens.C.ink)
                    .strikethrough(item.done, color: Tokens.C.ink3)
                if !item.time.isEmpty {
                    Text(item.time).font(Type.caption).foregroundStyle(Tokens.C.ink3).tabularDigits()
                }
            }
            Spacer()
        }
    }
}

#Preview { ProtocolView().environmentObject(Units.shared) }
