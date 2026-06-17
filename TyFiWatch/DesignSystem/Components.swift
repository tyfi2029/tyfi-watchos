import SwiftUI

// MARK: — Ring (progress arc)

/// Animated progress ring using the handoff 500 ms cubic-bezier fill.
struct Ring: View {
    var progress: Double        // 0…1
    var color: Color
    var lineWidth: CGFloat = 8
    var track: Color = Color.white.opacity(0.12)

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.ring, value: progress)
        }
    }
}

// MARK: — Card surface

/// Standard OLED card: white-0.07 fill, 22 pt radius.
struct Card<Content: View>: View {
    var radius: CGFloat = Tokens.S.cardRadius
    var fill: Color = Tokens.C.card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: — Kicker label (uppercase, tracked)

struct KickerLabel: View {
    let text: String
    var size: CGFloat = 10.5
    var color: Color = Tokens.C.ink3

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .medium).monospacedDigit())
            .tracking(2.0)
            .foregroundStyle(color)
    }
}

// MARK: — Stat / WMP tile

/// 2×2 grid tile: kicker label + large mono value + optional unit label.
struct WMPTile: View {
    let kicker: String
    let value: String
    var unit: String?       = nil
    var ringPct: Double?    = nil
    var ringColor: Color    = Tokens.C.accent
    var tint: Color         = Tokens.C.card
    var icon: String?       = nil          // SF Symbol name

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let sym = icon {
                    Image(systemName: sym)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(ringColor)
                }
                Spacer()
                if let pct = ringPct {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12),
                                    style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
                        Circle()
                            .trim(from: 0, to: max(0, min(1, pct)))
                            .stroke(ringColor, style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(Motion.ring, value: pct)
                    }
                    .frame(width: 30, height: 30)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 28, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Tokens.C.ink)
                    if let u = unit {
                        Text(u)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Tokens.C.ink3)
                    }
                }
                KickerLabel(text: kicker)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint, in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius, style: .continuous))
    }
}

// MARK: — StatTile (legacy compat — smaller pill style)

struct StatTile: View {
    let label: String
    let value: String
    var unit: String? = nil
    var color: Color = Tokens.C.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            KickerLabel(text: label)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(Type.metric(22))
                    .foregroundStyle(color)
                if let u = unit {
                    Text(u)
                        .font(Type.caption)
                        .foregroundStyle(Tokens.C.ink2)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.C.card,
                    in: RoundedRectangle(cornerRadius: Tokens.S.cardRadius, style: .continuous))
    }
}

// MARK: — Pill button

struct PillButton: View {
    let label: String
    var icon: String?       = nil
    var color: Color        = Tokens.C.accent
    var height: CGFloat     = Tokens.S.tapH
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.click(); action() }) {
            HStack(spacing: 7) {
                if let sym = icon {
                    Image(systemName: sym)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 16, weight: .semibold).monospacedDigit())
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(color.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: Tokens.S.pillRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .pressScale()
    }
}
