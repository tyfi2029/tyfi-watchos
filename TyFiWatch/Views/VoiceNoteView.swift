import SwiftUI

struct VoiceNoteView: View {
    @State private var transcript = ""
    @State private var tags: [String] = []
    @State private var isSaving = false
    @State private var saved = false
    @State private var errorMsg: String?
    @FocusState private var inputFocused: Bool

    private let suggestedTags = ["health", "food", "mood", "idea", "work", "reminder"]

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                HStack {
                    Image(systemName: "mic.circle.fill").foregroundStyle(Tokens.C.accent)
                    Text("Voice Note").font(Type.label).foregroundStyle(Tokens.C.ink)
                    Spacer()
                }
                TextField("Dictate or type...", text: $transcript, axis: .vertical)
                    .font(Type.body)
                    .foregroundStyle(Tokens.C.ink)
                    .focused($inputFocused)
                    .lineLimit(4...8)
                    .padding(8)
                    .background(Tokens.C.card)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                    .onAppear { inputFocused = true }

                if !transcript.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(suggestedTags, id: \.self) { tag in
                                Button(tag) {
                                    if tags.contains(tag) {
                                        tags.removeAll { $0 == tag }
                                    } else {
                                        tags.append(tag)
                                    }
                                }
                                .font(Type.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tags.contains(tag) ? Tokens.C.accent : Tokens.C.card)
                                .clipShape(Capsule())
                                .foregroundStyle(tags.contains(tag) ? Color.black : Tokens.C.ink2)
                            }
                        }
                    }

                    if saved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(Type.caption)
                            .foregroundStyle(Tokens.C.good)
                    } else {
                        Button(isSaving ? "Saving…" : "Save Note") {
                            Task { await save() }
                        }
                        .font(Type.label)
                        .tint(Tokens.C.accent)
                        .disabled(isSaving || transcript.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if let e = errorMsg {
                        Text(e).font(Type.caption).foregroundStyle(Tokens.C.bad)
                    }
                }
            }
            .padding(Tokens.S.gutter)
        }
        .background(Tokens.C.bg)
    }

    private func save() async {
        isSaving = true
        errorMsg = nil
        struct Body: Encodable {
            let transcript: String
            let tags: [String]
            let idempotency_key: String
            let captured_at: String
        }
        struct Result: Decodable { let capture_id: String? }
        let key = UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())
        do {
            _ = try await API.shared.post(
                "/api/watch/capture/voice",
                body: Body(transcript: transcript, tags: tags, idempotency_key: key, captured_at: now),
                as: Result.self)
            saved = true
        } catch {
            errorMsg = "Save failed"
        }
        isSaving = false
    }
}

#Preview { VoiceNoteView() }
