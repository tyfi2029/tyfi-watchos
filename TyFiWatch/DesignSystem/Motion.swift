import SwiftUI

/// Motion tokens from the handoff README.
/// - Ring fill: 500ms cubic-bezier(.2,.7,.2,1)
/// - Press: scale .93 over 80ms
/// - Value bump: 1 → 1.14 → 1 over 340ms
enum Motion {
    static let ring = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.5)
    static let press = Animation.easeOut(duration: 0.08)
    static let bumpHalf = Animation.easeOut(duration: 0.17) // half of the 340ms round trip
}

/// Press-scale interaction: scales to .93 on touch-down, springs back on release.
struct PressScale: ViewModifier {
    @State private var pressed = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.93 : 1.0)
            .animation(Motion.press, value: pressed)
            .onTapGesture { /* tap handled by caller's Button/onTapGesture */ }
            ._onButtonGesture(pressing: { pressed = $0 }, perform: {})
    }
}

/// One-shot "value bump": 1 → 1.14 → 1 when `trigger` changes.
struct ValueBump: ViewModifier {
    let trigger: Int
    @State private var scale: CGFloat = 1.0
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, _ in
                withAnimation(Motion.bumpHalf) { scale = 1.14 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
                    withAnimation(Motion.bumpHalf) { scale = 1.0 }
                }
            }
    }
}

extension View {
    func pressScale() -> some View { modifier(PressScale()) }
    func valueBump(on trigger: Int) -> some View { modifier(ValueBump(trigger: trigger)) }
}
