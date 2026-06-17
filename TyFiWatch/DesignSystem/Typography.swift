import SwiftUI

/// SF Pro type ramp. Every numeral uses .monospacedDigit() per the handoff spec.
enum Type {
    // Face clock: 118 pt
    static let faceClock = Font.system(size: 118, weight: .semibold, design: .default)
        .monospacedDigit()
    // Face seconds: ~40 pt ink-3
    static let faceSec   = Font.system(size: 40,  weight: .semibold, design: .default)
        .monospacedDigit()

    // Large ring value: 50–62 pt
    static func ringValue(_ size: CGFloat = 54) -> Font {
        .system(size: size, weight: .semibold, design: .default).monospacedDigit()
    }

    // Section / screen titles: 20–22 pt weight-600
    static func sectionTitle(_ size: CGFloat = 21) -> Font {
        .system(size: size, weight: .semibold)
    }

    // Tile value: 26–31 pt mono
    static func tileValue(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .semibold, design: .default).monospacedDigit()
    }

    // Body copy: 13.5–16 pt
    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular)
    }

    // Kicker / caption: 10–12.5 pt — uppercase, tracked
    static func kicker(_ size: CGFloat = 10.5) -> Font {
        .system(size: size, weight: .medium, design: .default).monospacedDigit()
    }

    // Named aliases used by Components / Views
    static let title   = Font.system(size: 17, weight: .semibold)
    static let body_   = Font.system(size: 15, weight: .regular)
    static let label   = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 11, weight: .regular)

    static func metric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }
}

/// Uppercase kicker style: small-caps equivalent with .tracking(2.0).
struct KickerStyle: ViewModifier {
    var size: CGFloat = 10.5
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .medium).monospacedDigit())
            .tracking(2.0)
            .textCase(.uppercase)
            .foregroundStyle(Tokens.C.ink3)
    }
}

extension View {
    func kicker(_ size: CGFloat = 10.5) -> some View { modifier(KickerStyle(size: size)) }
    func tabularDigits() -> some View { self.monospacedDigit() }
}
