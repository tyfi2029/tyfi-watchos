import SwiftUI

/// Capture — quick-log tiles + Voice Note sheet.
/// Quick log uses /api/watch/quick-log (POST) with QuickLogBody from Models.swift.
/// Voice Note sheet uses VoiceNoteView (which posts /api/watch/capture/voice with CaptureBody).
@MainActor
final class CaptureModel: ObservableObject {
    @Published var loggedCategory: String? = nil
    @Published var isLogging = false

    func quickLog(_ category: String, text: String) async {
        isLogging = true
        let body = QuickLogBody(
            category: category, text: text,
            logged_at: ISO8601DateFormatter().string(from: Date()),
            metadata: nil)
        _ = try? await API.shared.post("/api/watch/quick-log", body: body, as: QuickLogResult.self)
        loggedCategory = category
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        loggedCategory = nil
        isLogging = false
    }
}

struct CaptureView: View {
    @StateObject private var model = CaptureModel()
    @State private var showVoice = false

    private let quickItems: [(String, String, Color)] = [
        ("💧 Water",      "water",         Tokens.C.cool),
        ("☕ Caffeine",   "caffeine",      Tokens.C.warn),
        ("💊 Supplement", "supplement",    Tokens.C.good),
        ("✓ Protocol",    "protocol_item", Tokens.C.accent),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Tokens.C.accent)
                    Text("Capture").font(Type.label).foregroundStyle(Tokens.C.ink)
                    Spacer()
                }
                let cols = [GridItem(.flexible(), spacing: Tokens.S.gutter),
                            GridItem(.flexible(), spacing: Tokens.S.gutter)]
                LazyVGrid(columns: cols, spacing: Tokens.S.gutter) {
                    ForEach(quickItems, id: \.0) { item in
                        Button {
                            Task { await model.quickLog(item.1, text: item.0) }
                        } label: {
                            VStack(spacing: 4) {
                                Text(item.0)
                                    .font(Type.body)
                                    .foregroundStyle(item.2)
                                    .multilineTextAlignment(.center)
                                if model.loggedCategory == item.1 {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Tokens.C.good)
                                        .font(.caption)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(model.loggedCategory == item.1
                                ? Tokens.C.good.opacity(0.15)
                                : Tokens.C.card)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isLogging)
                    }
                }
                Button {
                    showVoice = true
                } label: {
                    HStack {
                        Image(systemName: "mic.fill").foregroundStyle(Tokens.C.accent)
                        Text("Voice Note").font(Type.label).foregroundStyle(Tokens.C.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Tokens.C.card)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showVoice) { VoiceNoteView() }
            }
            .padding(Tokens.S.gutter)
        }
        .background(Tokens.C.bg)
    }
}

#Preview { CaptureView() }
