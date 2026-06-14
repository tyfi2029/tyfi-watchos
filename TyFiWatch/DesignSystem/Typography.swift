import SwiftUI

/// SF Pro type ramp. Every numeral is tabular (`.monospacedDigit()`) per the
/// handoff spec so values don't jitter as they animate.
enum Type {
    /// Big metric readout (e.g. ml, glucose). Tabular by default.
    static func metric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    /// The 118pt face clock — orange, tabular, with a live :ss.
    static let faceClock = Font.system(size: 118, weight: .semibold, design: .rounded).monospacedDigit()

    static let title  = Font.system(size: 17, weight: .semibold)
    static let body   = Font.system(size: 15, weight: .regular)
    static let label  = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 11, weight: .regular)
}

extension View {
    /// Apply to any view containing digits that should not reflow.
    func tabularDigits() -> some View { self.monospacedDigit() }
}
