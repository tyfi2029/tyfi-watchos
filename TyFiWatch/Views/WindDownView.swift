import SwiftUI

@MainActor
final class WindDownModel: ObservableObject {
    @Published var data: WindDownData?
    @Published var checklist: [WindDownData.WindDownItem] = []
    @Published var error: String?
    @Published var loading = false
    @Published var active = false
    @Published var targetTempF: Double = 64

    func load() async {
        loading = true; defer { loading = false }
        do {
            data = try await API.shared.get("/api/watch/winddown", as: WindDownData.self)
            checklist = data?.checklist ?? defaultChecklist
            if let t = data?.eight_sleep?.targetTempF { targetTempF = t }
            error = nil
        }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func setTemp(_ t: Double) async {
        targetTempF = t
        _ = try? await API.shared.post("/api/watch/winddown",
            body: WindDownSetTempBody(temp_f: t), as: WindDownSetTempResult.self)
    }

    func beginWindDown() {
        withAnimation(.easeInOut(duration: 0.3)) {
            active = true
            for i in checklist.indices { checklist[i] = WindDownData.WindDownItem(
                id: checklist[i].id, label: checklist[i].label, done: true) }
        }
    }

    var defaultChecklist: [WindDownData.WindDownItem] {
        [
            WindDownData.WindDownItem(id: "scene",    label: "Red Sleep scene",   done: false),
            WindDownData.WindDownItem(id: "blockers", label: "Blue-blockers",     done: false),
            WindDownData.WindDownItem(id: "mg",       label: "Mg glycinate 200mg", done: false),
        ]
    }
}

/// Screen 5 — Wind Down (purple accent throughout).
/// Layout: status bar → 8Sleep temp card (−/+ steppers) → checklist rows → Begin button.
struct WindDownView: View {
    @StateObject private var model = WindDownModel()
    @EnvironmentObject var units: Units

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Status bar — purple accent
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Tokens.C.sleep)
                        Text("Wind-down")
                            .font(.system(size: 21, weight: .semibold))
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("21:28")
                        .font(.system(size: 18, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.sleep)
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.top, 16)
                .padding(.bottom, 13)

                VStack(spacing: 11) {
                    // 8Sleep card with −/+ steppers
                    eightSleepCard

                    // Checklist rows
                    ForEach(model.checklist.indices, id: \.self) { i in
                        checklistRow(i)
                    }

                    // Begin wind-down button
                    beginButton

                    if let e = model.error {
                        Text(e).font(Type.caption).foregroundStyle(Tokens.C.warn)
                    }
                }
                .padding(.horizontal, Tokens.S.hPad)
                .padding(.bottom, 16)
            }
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    // MARK: — 8Sleep card
    private var eightSleepCard: some View {
        HStack(spacing: 0) {
            Image(systemName: "thermometer.medium")
                .font(.system(size: 22))
                .foregroundStyle(Tokens.C.cool)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 1) {
                KickerLabel(text: "8Sleep Tonight")
                Text(units.celsius
                     ? String(format: "%.0f°C", (model.targetTempF - 32) * 5 / 9)
                     : String(format: "%.0f°F", model.targetTempF))
                    .font(.system(size: 23, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink)
            }
            .padding(.leading, 13)

            Spacer()

            // − button
            Button {
                Task { await model.setTemp(max(55, model.targetTempF - 1)) }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.C.ink2)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)

            // + button
            Button {
                Task { await model.setTemp(min(80, model.targetTempF + 1)) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.C.ink2)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(14)
        .background(Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
    }

    // MARK: — Checklist row
    @ViewBuilder
    private func checklistRow(_ i: Int) -> some View {
        let item = model.checklist[i]
        let done = item.done ?? false
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                model.checklist[i] = WindDownData.WindDownItem(
                    id: item.id, label: item.label, done: !done)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(done ? Tokens.C.sleep : Color.white.opacity(0.22), lineWidth: 2)
                        .frame(width: 25, height: 25)
                    if done {
                        Circle().fill(Tokens.C.sleep).frame(width: 25, height: 25)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.black)
                    }
                }
                Text(item.label ?? "")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(done ? Tokens.C.ink3 : Tokens.C.ink)
                    .strikethrough(done, color: Tokens.C.ink3.opacity(0.4))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Tokens.C.card,
                        in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    // MARK: — Begin button (solid purple fill from the start; not ghost)
    private var beginButton: some View {
        Button {
            model.beginWindDown()
        } label: {
            HStack(spacing: 8) {
                if model.active {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white)
                    Text("Wind-down active")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                } else {
                    Text("Begin wind-down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Tokens.S.tapH)
            // Always solid purple — not ghost — even before active
            .background(
                Tokens.C.sleep,
                in: RoundedRectangle(cornerRadius: Tokens.S.pillRadius))
        }
        .buttonStyle(.plain)
        .pressScale()
        .padding(.top, 4)
    }
}

#Preview { WindDownView().environmentObject(Units.shared) }
