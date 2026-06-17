import SwiftUI

@MainActor
final class CaptureModel: ObservableObject {
    @Published var loggedCategory: String? = nil
    @Published var isLogging = false

    func quickLog(_ category: String) async {
        isLogging = true
        let body = QuickLogBody(category: category, text: nil,
            logged_at: ISO8601DateFormatter().string(from: Date()), metadata: nil)
        _ = try? await API.shared.post("/api/watch/quick-log", body: body, as: QuickLogResult.self)
        loggedCategory = category
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        loggedCategory = nil
        isLogging = false
    }
}

/// Screen 9 — Capture.
/// Layout: large orange hold-to-record mic (center) → 2×2 quick-capture tiles.
struct CaptureView: View {
    @StateObject private var model = CaptureModel()
    @State private var showVoice = false
    @State private var micPressed = false

    private let tiles: [(icon: String, label: String, category: String, color: Color)] = [
        ("camera.fill",   "Meal",    "meal",      Tokens.C.good),
        ("wave.3.right",  "RFID",    "rfid",      Tokens.C.cool),
        ("thermometer",   "Thermal", "thermal",   Tokens.C.warn),
        ("bolt.fill",     "Paste",   "paste",     Tokens.C.accent),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    Text("Capture")
                        .font(.system(size: 19, weight: .semibold))
                    Spacer()
                    Text("9:41")
                        .font(.system(size: 21, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.accent)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 10)
                .padding(.bottom, 16)

                VStack(spacing: 18) {
                    // Big hold-to-record mic
                    VStack(spacing: 8) {
                        Button {
                            showVoice = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Tokens.C.accent.opacity(0.16))
                                    .frame(width: 120 + 16, height: 120 + 16)
                                Circle()
                                    .fill(Tokens.C.accent)
                                    .frame(width: 120, height: 120)
                                VStack(spacing: 4) {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 36, weight: .medium))
                                        .foregroundStyle(Color.black)
                                    Text("HOLD")
                                        .font(.system(size: 12, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundStyle(Color.black.opacity(0.7))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(micPressed ? 0.93 : 1.0)
                        .animation(Motion.press, value: micPressed)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in micPressed = true }
                                .onEnded { _ in micPressed = false }
                        )
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.36).onEnded { _ in showVoice = true }
                        )

                        Text("or press the Action button")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Tokens.C.ink3)
                            .tracking(0.4)
                    }

                    // 2×2 quick-capture tiles
                    let cols = [GridItem(.flexible(), spacing: Tokens.S.gap),
                                GridItem(.flexible(), spacing: Tokens.S.gap)]
                    LazyVGrid(columns: cols, spacing: Tokens.S.gap) {
                        ForEach(tiles, id: \.category) { tile in
                            Button {
                                Task { await model.quickLog(tile.category) }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: tile.icon)
                                        .font(.system(size: 22))
                                        .foregroundStyle(tile.color)
                                    Text(tile.label)
                                        .font(.system(size: 14))
                                        .foregroundStyle(model.loggedCategory == tile.category
                                                         ? Tokens.C.good : Tokens.C.ink2)
                                    Spacer()
                                    if model.loggedCategory == tile.category {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Tokens.C.good)
                                    }
                                }
                                .frame(height: 64)
                                .padding(.horizontal, 14)
                                .background(
                                    model.loggedCategory == tile.category
                                        ? Tokens.C.good.opacity(0.12) : Tokens.C.card,
                                    in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                            }
                            .buttonStyle(.plain)
                            .pressScale()
                            .disabled(model.isLogging)
                        }
                    }
                    .padding(.horizontal, Tokens.S.hPad)
                }
                .padding(.bottom, 16)
            }
        }
        .background(Tokens.C.bg)
        .sheet(isPresented: $showVoice) { VoiceNoteView() }
    }
}

#Preview { CaptureView() }
