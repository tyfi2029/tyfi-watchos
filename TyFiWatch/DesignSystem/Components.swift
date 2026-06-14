import SwiftUI

/// Progress ring with the handoff's 500ms cubic-bezier fill animation.
struct Ring: View {
    var progress: Double            // 0...1
    var color: Color
    var lineWidth: CGFloat = 8
    var track: Color = Tokens.C.card

    var body: some View {
        ZStack {
            Circle().stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.ring, value: progress)
        }
    }
}

/// OLED card surface — 0.07 white fill, rounded.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.C.card, in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius, style: .continuous))
    }
}

/// Small labeled metric tile used on the Now grid.
struct StatTile: View {
    let label: String
    let value: String
    var unit: String? = nil
    var color: Color = Tokens.C.ink
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(Type.caption).foregroundStyle(Tokens.C.ink3)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value).font(Type.metric(20)).foregroundStyle(color)
                    if let unit { Text(unit).font(Type.caption).foregroundStyle(Tokens.C.ink2) }
                }
            }
        }
    }
}
