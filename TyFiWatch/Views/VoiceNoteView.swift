import SwiftUI

/// Voice Note — /api/watch/capture/voice (POST).
/// Uses CaptureBody from Models.swift — verified frozen contract 2026-06-14.
/// Body: { transcript, idempotency_key, category_hint?, captured_at?, metadata? }
struct VoiceNoteView: View {
    @State private var transcript = ""
    @State private var categoryHint: String? = nil
    @State private var isSaving = false
    @State private var saved = false
    @State private var errorMsg: String?
    @FocusState private var inputFocused: Bool

    private let suggestedCategories = ["health", "food", "mood", "idea", "work", "reminder"]

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
                            ForEach(suggestedCategories, id: \.self) { cat in
                                Button(cat) {
                                    categoryHint = categoryHint == cat ? nil : cat
                                }
                                .font(Type.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(categoryHint == cat ? Tokens.C.accent : Tokens.C.card)
                                .clipShape(Capsule())
                                .foregroundStyle(categoryHint == cat ? Color.black : Tokens.C.ink2)
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
        let body = CaptureBody(
            transcript: transcript,
            idempotency_key: UUID().uuidString,
            category_hint: categoryHint,
            captured_at: ISO8601DateFormatter().string(from: Date()),
            metadata: nil)
        do {
            _ = try await API.shared.post(
                "/api/watch/capture/voice",
                body: body,
                as: CaptureResult.self)
            saved = true
        } catch {
            errorMsg = "Save failed"
        }
        isSaving = false
    }
}

#Preview { VoiceNoteView() }
