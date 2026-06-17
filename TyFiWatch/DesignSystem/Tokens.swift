import SwiftUI

/// TyFi design tokens — canonical values from the watchOS handoff README.
/// OLED-first: true-black background on every screen.
enum Tokens {
    // MARK: — Color
    enum C {
        static let bg      = Color.black                        // OLED #000000
        static let accent  = Color(hex: "#e0813e")              // TyFi orange
        static let warn    = Color(hex: "#e0a14d")
        static let good    = Color(hex: "#5fb88f")
        static let cool    = Color(hex: "#7aa9cf")
        static let bad     = Color(hex: "#e07171")
        static let sleep   = Color(hex: "#b98ce0")              // wind-down / sleep

        static let ink     = Color.white                        // primary text
        static let ink2    = Color(red: 235/255, green: 235/255, blue: 245/255).opacity(0.60)
        static let ink3    = Color(red: 235/255, green: 235/255, blue: 245/255).opacity(0.34)
        static let hairline = Color.white.opacity(0.10)
        static let card    = Color.white.opacity(0.07)

        // Tinted card fills — accent × 0.14, cool × 0.16, etc.
        static func tint(_ base: Color, _ opacity: Double = 0.14) -> Color { base.opacity(opacity) }
    }

    // MARK: — Spacing / radius
    enum S {
        static let hPad: CGFloat     = 24          // horizontal screen padding
        static let cardRadius: CGFloat = 22         // standard card corner radius
        static let pillRadius: CGFloat = 99         // fully-rounded pill / button
        static let gap: CGFloat       = 11          // standard inter-card gap
        static let gutter: CGFloat    = 11          // alias
        static let tapH: CGFloat      = 54          // minimum tap-target height
    }
}

// MARK: — Color(hex:) initialiser
extension Color {
    /// Accepts "#rrggbb" or "#rrggbbaa" strings.
    init(hex: String) {
        var s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if s.count == 6 { s += "ff" }
        let v = UInt64(s, radix: 16) ?? 0
        let r = Double((v >> 24) & 0xff) / 255
        let g = Double((v >> 16) & 0xff) / 255
        let b = Double((v >>  8) & 0xff) / 255
        let a = Double( v        & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    /// 0xRRGGBB UInt32 initialiser (kept for back-compat).
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >>  8) & 0xff) / 255.0
        let b = Double( hex        & 0xff) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
