import SwiftUI

/// Screen 10 — Voice Note.
/// Recording state: animated waveform (5 bars) + elapsed timer + stop button.
/// Review state: transcript card + tag pills + Save / Re-record.
struct VoiceNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recording = false
    @State private var reviewing = false
    @State private var transcript = ""
    @State private var elapsed = 0
    @State private var selectedTags: Set<String> = []
    @State private var saved = false
    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var ticker: Timer? = nil
    @FocusState private var inputFocused: Bool

    private let tags = ["Idea", "To-do", "Health", "GLO", "Follow-up", "Travel"]

    var body: some View {
        if saved {
            savedView
        } else if reviewing {
            reviewView
        } else {
            recordingView
        }
    }

    // MARK: — Recording state
    private var recordingView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Voice Note")
                    .font(.system(size: 19, weight: .semibold))
                Spacer()
                Text(elapsedString)
                    .font(.system(size: 16, weight: .semibold).monospacedDigit())
                    .foregroundStyle(recording ? Tokens.C.bad : Tokens.C.ink3)
            }
            .padding(.horizontal, Tokens.S.hPad)
            .padding(.top, 14)
            .padding(.bottom, 20)

            Spacer()

            // Waveform animation
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Tokens.C.bad)
                        .frame(width: 6)
                        .scaleEffect(y: recording ? 1.0 : 0.35, anchor: .center)
                        .animation(
                            recording
                                ? .easeInOut(duration: 0.9)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.15)
                                : .default,
                            value: recording)
            }
            }
            .frame(height: 50)

            Spacer()

            // Start / Stop button
            Button {
                if recording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(recording ? Tokens.C.bad : Tokens.C.accent)
                        .frame(width: 72, height: 72)
                    if recording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 26, height: 26)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.black)
                    }
                }
            }
            .buttonStyle(.plain)
            .pressScale()
            .padding(.bottom, 24)
        }
        .frame(maxHeight: .infinity)
        .background(Tokens.C.bg)
    }

    // MARK: — Review state
    private var reviewView: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("Voice Note")
                        .font(.system(size: 19, weight: .semibold))
                    Spacer()
                }
                .padding(.top, 14)

                // Transcript card
                TextField("Add note…", text: $transcript, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(Tokens.C.ink)
                    .focused($inputFocused)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(Tokens.C.card,
                                in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))

                // Tag pills
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            if selectedTags.contains(tag) { selectedTags.remove(tag) }
                            else { selectedTags.insert(tag) }
                        } label: {
                            Text(tag)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(selectedTags.contains(tag) ? Color.black : Tokens.C.ink2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(
                                    selectedTags.contains(tag) ? Tokens.C.accent : Tokens.C.card,
                                    in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Save / Re-record
                HStack(spacing: 10) {
                    Button {
                        recording = false
                        reviewing = false
                        transcript = ""
                        elapsed = 0
                        selectedTags = []
                    } label: {
                        Text("Re-record")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Tokens.C.ink2)
                            .frame(maxWidth: .infinity)
                            .frame(height: Tokens.S.tapH)
                            .background(Tokens.C.card,
                                        in: RoundedRectangle(cornerRadius: Tokens.S.pillRadius))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await saveNote() }
                    } label: {
                        Text(isSaving ? "Saving…" : "Save")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Tokens.C.good)
                            .frame(maxWidth: .infinity)
                            .frame(height: Tokens.S.tapH)
                            .background(Tokens.C.good.opacity(0.16),
                                        in: RoundedRectangle(cornerRadius: Tokens.S.pillRadius))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || transcript.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let e = errorMsg {
                    Text(e).font(Type.caption).foregroundStyle(Tokens.C.bad)
                }
            }
            .padding(.horizontal, Tokens.S.hPad)
            .padding(.bottom, 16)
        }
        .background(Tokens.C.bg)
    }

    private var savedView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Tokens.C.good)
            Text("Saved")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Tokens.C.ink)
            Spacer()
        }
        .frame(maxHeight: .infinity)
        .background(Tokens.C.bg)
        // Dismiss consistency: confirm briefly, then return to the caller.
        .task {
            try? await Task.sleep(for: .seconds(1.1))
            dismiss()
        }
    }

    // MARK: — Helpers
    private var elapsedString: String {
        String(format: "%d:%02d", elapsed / 60, elapsed % 60)
    }

    private func startRecording() {
        recording = true
        elapsed = 0
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in elapsed += 1 }
        }
    }

    private func stopRecording() {
        ticker?.invalidate()
        recording = false
        reviewing = true
    }

    private func saveNote() async {
        isSaving = true
        errorMsg = nil
        let body = CaptureBody(
            transcript: transcript,
            idempotency_key: UUID().uuidString,
            category_hint: selectedTags.first,
            captured_at: ISO8601DateFormatter().string(from: Date()),
            metadata: selectedTags.isEmpty ? nil : ["tags": selectedTags.joined(separator: ",")])
        do {
            _ = try await API.shared.post("/api/watch/capture/voice", body: body, as: CaptureResult.self)
            withAnimation { saved = true }
        } catch {
            errorMsg = "Save failed"
        }
        isSaving = false
    }
}

#Preview { VoiceNoteView() }
