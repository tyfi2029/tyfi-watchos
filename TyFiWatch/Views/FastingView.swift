import SwiftUI

/// Fasting — E2 enhancement: protocol picker on start, stage label, dynamic target ring.
/// GET /api/watch/fasting returns active.stage, active.target_hrs, active.protocol.
@MainActor
final class FastingModel: ObservableObject {
    @Published var state: FastingState?
    @Published var error: String?
    @Published var busy = false

    func load() async {
        do { state = try await API.shared.get("/api/watch/fasting", as: FastingState.self); error = nil }
        catch APIError.notAuthed { error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func start(protocol proto: String, targetHours: Double) async {
        busy = true; defer { busy = false }
        struct StartBody: Encodable { let action: String; let protocol: String; let target_hours: Double }
        struct R: Decodable { let started: Bool? }
        _ = try? await API.shared.post("/api/watch/fasting",
            body: StartBody(action: "start", protocol: proto, target_hours: targetHours), as: R.self)
        await load()
    }

    func end() async {
        busy = true; defer { busy = false }
        struct EndBody: Encodable { let action: String }
        struct R: Decodable { let ended: Bool? }
        _ = try? await API.shared.post("/api/watch/fasting", body: EndBody(action: "end"), as: R.self)
        await load()
    }
}

private let protocols: [(label: String, hours: Double)] = [
    ("13:11", 13), ("16:8", 16), ("18:6", 18), ("20:4", 20), ("OMAD", 23), ("36h", 36),
]

struct FastingView: View {
    @StateObject private var model = FastingModel()
    @State private var showProtocolPicker = false
    @State private var selectedProtocol = "16:8"
    @State private var selectedHours: Double = 16

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.S.gutter) {
                Text("FASTING").font(Type.label).foregroundStyle(Tokens.C.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let a = model.state?.active
                ZStack {
                    Ring(progress: Double(a?.progress_pct ?? 0) / 100, color: ringColor, lineWidth: 11)
                        .frame(width: 120, height: 120)
                    VStack(spacing: 0) {
                        Text(a != nil ? String(format: "%.1f", a!.elapsed_hrs ?? 0) : "—")
                            .font(Type.metric(34)).foregroundStyle(Tokens.C.ink)
                        Text(a != nil ? "of \(Int(a!.target_hrs ?? 16))h" : "not fasting")
                            .font(Type.caption).foregroundStyle(Tokens.C.ink2)
                    }
                }.padding(.top, 4)

                // Stage label
                if let stage = a?.stage {
                    Text(stage)
                        .font(Type.caption)
                        .foregroundStyle(stageColor(stage))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(stageColor(stage).opacity(0.15))
                        .clipShape(Capsule())
                }

                HStack(spacing: Tokens.S.gutter) {
                    StatTile(label: "Streak", value: "\(model.state?.streak ?? 0)", unit: "d",
                             color: Tokens.C.accent)
                    if let a {
                        StatTile(label: "Remaining",
                                 value: String(format: "%.1fh", a.remaining_hrs ?? 0),
                                 color: Tokens.C.cool)
                    } else {
                        StatTile(label: "Window",
                                 value: model.state?.eating_window?.open == true ? "Open" : "—",
                                 color: Tokens.C.cool)
                    }
                }

                // Protocol display when fasting
                if let proto = a?.protocol {
                    Text(proto).font(Type.caption).foregroundStyle(Tokens.C.ink3)
                }

                if a != nil {
                    Button("End Fast") { Task { await model.end() } }
                        .font(Type.label).tint(Tokens.C.bad).disabled(model.busy)
                } else {
                    Button("Start Fast") { showProtocolPicker = true }
                        .font(Type.label).tint(Tokens.C.good).disabled(model.busy)
                }

                if let e = model.error {
                    Text(e).font(Type.caption).foregroundStyle(Tokens.C.warn)
                }
            }
            .padding(.horizontal, 6)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
        .sheet(isPresented: $showProtocolPicker) {
            ProtocolPickerView(selected: $selectedProtocol, hours: $selectedHours) {
                showProtocolPicker = false
                Task { await model.start(protocol: selectedProtocol, targetHours: selectedHours) }
            }
        }
    }

    private var ringColor: Color {
        let p = model.state?.active?.progress_pct ?? 0
        if p >= 100 { return Tokens.C.good }
        if p >= 50  { return Tokens.C.accent }
        return Tokens.C.cool
    }

    private func stageColor(_ stage: String) -> Color {
        switch stage {
        case "Autophagy":    return Tokens.C.good
        case "Deep Ketosis": return Tokens.C.accent
        case "Ketosis":      return Tokens.C.cool
        case "Fat Burning":  return Tokens.C.cool
        default:             return Tokens.C.ink2
        }
    }
}

struct ProtocolPickerView: View {
    @Binding var selected: String
    @Binding var hours: Double
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: Tokens.S.gutter) {
            Text("Choose Protocol").font(Type.label).foregroundStyle(Tokens.C.ink)
            ForEach(protocols, id: \.label) { p in
                Button {
                    selected = p.label
                    hours = p.hours
                    onConfirm()
                } label: {
                    HStack {
                        Text(p.label).font(Type.body).foregroundStyle(Tokens.C.ink)
                        Spacer()
                        Text("\(Int(p.hours))h").font(Type.caption).foregroundStyle(Tokens.C.ink3)
                        if selected == p.label {
                            Image(systemName: "checkmark").foregroundStyle(Tokens.C.good)
                        }
                    }
                    .padding(8)
                    .background(Tokens.C.card)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.S.cardRadius))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Tokens.S.gutter)
        .background(Tokens.C.bg)
    }
}

#Preview { FastingView().environmentObject(Units.shared) }
