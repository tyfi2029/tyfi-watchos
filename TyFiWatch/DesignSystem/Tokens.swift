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
        static let hPad:      CGFloat = WatchScreen.hPad
        static let cardRadius: CGFloat = 22
        static let pillRadius: CGFloat = 99
        static let gap:       CGFloat = WatchScreen.gap
        static let gutter:    CGFloat = WatchScreen.gap
        static let tapH:      CGFloat = WatchScreen.tapH
    }
}

// MARK: - Screen-Adaptive Layout
#if os(watchOS)
import WatchKit

enum WatchScreen {
    static let width:  CGFloat = WKInterfaceDevice.current().screenBounds.width
    static let height: CGFloat = WKInterfaceDevice.current().screenBounds.height

    // Ring / orb diameters
    static let ringLg:    CGFloat = width * 0.62   // Water: 218–254pt
    static let ringMd:    CGFloat = width * 0.52   // Readiness/Fasting: 183–213pt
    static let ringSm:    CGFloat = width * 0.45   // Timer: 158–185pt
    static let ringXs:    CGFloat = width * 0.40   // Breathwork orb: 141–164pt
    static let ringMacro: CGFloat = width * 0.21   // Nutrition macro: 74–86pt

    // Ring stroke widths
    static let strokeLg:  CGFloat = max(12, width * 0.038)  // ~13–16pt
    static let strokeMd:  CGFloat = max( 9, width * 0.028)  // ~10–11pt
    static let strokeSm:  CGFloat = max( 6, width * 0.020)  //  ~7–8pt

    // Hero number font sizes
    static let heroXl:   CGFloat = min(72, width * 0.170)  // Zone2 HR: ~60–70pt
    static let heroLg:   CGFloat = min(68, width * 0.155)  // Water volume: ~54–64pt
    static let heroMd:   CGFloat = min(60, width * 0.135)  // Recovery/Sleep: ~47–55pt
    static let heroSm:   CGFloat = min(52, width * 0.115)  // Fasting elapsed: ~40–47pt
    static let heroXs:   CGFloat = min(44, width * 0.105)  // Timer countdown: ~37–43pt
    static let heroXxs:  CGFloat = min(36, width * 0.085)  // Breathwork count: ~30–35pt

    // Spacing
    static let hPad: CGFloat = max(14, width * 0.060)   // ~21–25pt
    static let gap:  CGFloat = max( 8, width * 0.028)   // ~10–11pt
    static let tapH: CGFloat = max(48, width * 0.135)   // ~47–55pt
}
#endif

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
