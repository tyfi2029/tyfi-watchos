import SwiftUI

/// TyFi design tokens — load-bearing values from the handoff README (CLAUDE.md).
/// OLED-first: pure-black background, never elevate with gray.
enum Tokens {
    // MARK: Color — hex from the handoff palette
    enum C {
        static let bg     = Color.black                  // OLED #000000
        static let accent = Color(hex: 0xe0813e)         // orange
        static let warn   = Color(hex: 0xe0a14d)
        static let good   = Color(hex: 0x5fb88f)
        static let cool   = Color(hex: 0x7aa9cf)
        static let bad    = Color(hex: 0xe07171)
        static let sleep  = Color(hex: 0xb98ce0)

        static let ink  = Color.white                     // primary text
        static let ink2 = Color.white.opacity(0.60)       // secondary
        static let ink3 = Color.white.opacity(0.34)       // tertiary / hint

        static let card = Color.white.opacity(0.07)       // card fill
    }

    // MARK: Spacing / radius
    enum S {
        static let cardRadius: CGFloat = 14
        static let gutter: CGFloat = 8
    }
}

extension Color {
    /// 0xRRGGBB literal initializer.
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >> 8) & 0xff) / 255.0
        let b = Double(hex & 0xff) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
