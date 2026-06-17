import SwiftUI

@MainActor
final class ProtocolModel: ObservableObject {
    @Published var segments: [ProtocolSegment] = []
    @Published var error: String?
    @Published var page = 0

    func load() async {
        do {
            segments = try await API.shared.get("/api/watch/protocol/today",
                                                as: ProtocolToday.self).segments
            error = nil
        }
        catch APIError.notAuthed { self.error = "Pair watch" }
        catch { self.error = "Offline" }
    }

    func toggle(_ item: ProtocolItem) async {
        let body = ProtocolToggle(done: !item.done,
                                  toggled_at: ISO8601DateFormatter().string(from: Date()))
        do {
            segments = try await API.shared.post(
                "/api/watch/protocol/item/\(item.id)/toggle",
                body: body, as: ProtocolToday.self).segments
            Haptics.click()
        } catch { /* keep current state */ }
    }
}

/// Screen 4 — Protocol.
/// Layout: title + clock → segment pager (chevrons + dots) → page: progress bar + checklist.
struct ProtocolView: View {
    @StateObject private var model = ProtocolModel()
    @EnvironmentObject var units: Units

    private var visibleSegments: [ProtocolSegment] {
        model.segments.isEmpty ? placeholderSegments : model.segments
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: title + clock
            HStack(alignment: .lastTextBaseline) {
                Text("Protocol")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Tokens.C.ink)
                Spacer()
                Text("9:41")
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Tokens.C.accent)
            }
            .padding(.horizontal, Tokens.S.hPad)
            .padding(.top, 16)
            .padding(.bottom, 11)

            // Segment pager header
            HStack(spacing: 0) {
                Button {
                    withAnimation(Motion.slide) {
                        model.page = max(0, model.page - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.C.ink3)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 99))
                }
                .buttonStyle(.plain)
                .opacity(model.page > 0 ? 1 : 0.3)

                Spacer()

                VStack(spacing: 6) {
                    let seg = visibleSegments.indices.contains(model.page)
                        ? visibleSegments[model.page] : nil
                    Text((seg?.name ?? "Morning") +
                         (seg?.rangeStart != nil ? " · \(seg!.rangeStart!)" : ""))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Tokens.C.ink)

                    HStack(spacing: 6) {
                        ForEach(visibleSegments.indices, id: \.self) { i in
                            Circle()
                                .fill(i == model.page ? Color.white : Color.white.opacity(0.26))
                                .frame(width: 7, height: 7)
                                .animation(.easeInOut(duration: 0.2), value: model.page)
                        }
                    }
                }

                Spacer()

                Button {
                    withAnimation(Motion.slide) {
                        model.page = min(visibleSegments.count - 1, model.page + 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.C.ink3)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 99))
                }
                .buttonStyle(.plain)
                .opacity(model.page < visibleSegments.count - 1 ? 1 : 0.3)
            }
            .padding(.horizontal, Tokens.S.hPad)
            .padding(.bottom, 10)

            // Page content
            TabView(selection: $model.page) {
                ForEach(visibleSegments.indices, id: \.self) { i in
                    segmentPage(visibleSegments[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(Motion.slide, value: model.page)
        }
        .background(Tokens.C.bg)
        .task { await model.load() }
    }

    @ViewBuilder
    private func segmentPage(_ seg: ProtocolSegment) -> some View {
        let done  = seg.items.filter({ $0.done }).count
        let total = seg.items.count
        let pct   = total > 0 ? Double(done) / Double(total) : 0.0

        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                // Done/total + progress bar
                HStack {
                    Text("\(done)")
                        .font(.system(size: 16, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.ink)
                    + Text("/\(total) done")
                        .font(.system(size: 13))
                        .foregroundStyle(Tokens.C.ink2)
                    Spacer()
                    Text("\(total - done) ahead")
                        .font(.system(size: 11.5).monospacedDigit())
                        .foregroundStyle(Tokens.C.ink3)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10)).frame(height: 5)
                        Capsule().fill(Tokens.C.warn)
                            .frame(width: geo.size.width * pct, height: 5)
                            .animation(.easeInOut(duration: 0.4), value: pct)
                    }
                }
                .frame(height: 5)

                // Checklist rows
                VStack(spacing: 9) {
                    ForEach(seg.items) { item in
                        Button { Task { await model.toggle(item) } } label: {
                            protoRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Tokens.S.hPad)
            .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private func protoRow(_ item: ProtocolItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(item.done ? Tokens.C.good : Color.white.opacity(0.22),
                                  lineWidth: 2)
                    .frame(width: 30, height: 30)
                if item.done {
                    Circle().fill(Tokens.C.good).frame(width: 30, height: 30)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(itemLabel(item))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(item.done ? Tokens.C.ink3 : Tokens.C.ink)
                    .strikethrough(item.done, color: Tokens.C.ink3.opacity(0.3))
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.time)
                    .font(.system(size: 12.5).monospacedDigit())
                    .foregroundStyle(Tokens.C.ink3)
                    .tracking(0.4)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 15)
        .background(item.done ? Color.white.opacity(0.04) : Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: 22))
    }

    private func itemLabel(_ item: ProtocolItem) -> String {
        if let f = item.tempF {
            let tempStr = Units.shared.celsius
                ? String(format: "%.0f°C", (f - 32) * 5 / 9)
                : String(format: "%.0f°F", f)
            return item.label + tempStr
        }
        return item.label
    }

    // Fallback when offline
    private var placeholderSegments: [ProtocolSegment] {
        [ProtocolSegment(name: "Morning", rangeStart: "06–12", rangeEnd: nil, items: [])]
    }
}

#Preview { ProtocolView().environmentObject(Units.shared) }
