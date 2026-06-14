import SwiftUI

struct CaptureView: View {
    @State private var loggedCategory: String? = nil
    @State private var showVoice = false
    @State private var isLogging = false

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
                            Task { await quickLog(item.1, text: item.0) }
                        } label: {
                            VStack(spacing: 4) {
                                Text(item.0)
                                    .font(Type.body)
                                    .foregroundStyle(item.2)
                                    .multilineTextAlignment(.center)
                                if loggedCategory == item.1 {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Tokens.C.good)
                                        .font(.caption)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(loggedCategory == item.1
                                ? Tokens.C.good.opacity(0.15)
                                : Tokens.C.card)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                        }
                        .buttonStyle(.plain)
                        .disabled(isLogging)
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

    private func quickLog(_ category: String, text: String) async {
        isLogging = true
        struct Body: Encodable { let category: String; let text: String; let logged_at: String }
        struct Result: Decodable { let id: String? }
        let body = Body(category: category, text: text,
                        logged_at: ISO8601DateFormatter().string(from: Date()))
        _ = try? await API.shared.post("/api/watch/quick-log", body: body, as: Result.self)
        loggedCategory = category
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            loggedCategory = nil
            isLogging = false
        }
    }
}

#Preview { CaptureView() }
