import SwiftUI

/// Motion tokens from the watchOS handoff spec.
/// Ring fill: 500 ms cubic-bezier(.2,.7,.2,1)
/// Press feedback: scale 0.93 over 80 ms
/// Value bump: 1 → 1.14 → 1 over 340 ms
enum Motion {
    static let ring  = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.5)
    static let press = Animation.easeOut(duration: 0.08)
    static let bump  = Animation.spring(response: 0.34, dampingFraction: 0.55)
    static let slide = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.32)
    static let bumpHalf = Animation.easeOut(duration: 0.17)
}

/// Press-scale: 0.93 on touch-down, springs back on release.
struct PressScale: ViewModifier {
    @State private var pressed = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.93 : 1.0)
            .animation(Motion.press, value: pressed)
            ._onButtonGesture(pressing: { pressed = $0 }, perform: {})
    }
}

/// Value-bump: 1 → 1.14 → 1 when `trigger` changes.
struct ValueBump: ViewModifier {
    let trigger: Int
    @State private var scale: CGFloat = 1.0
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, _ in
                Haptics.click()
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
