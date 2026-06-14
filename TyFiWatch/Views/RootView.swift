import SwiftUI

/// App opens to Now; remaining screens reachable by horizontal paging
/// (Smart Stack nudges + Action button → Voice handled elsewhere). IA per handoff.
struct RootView: View {
    var body: some View {
        TabView {
            NowView()
            WaterView()
            ProtocolView()
            ReadinessView()
            SleepView()
            TrendsView()
            LiveSensorsView()
            SessionTimerView()
            FastingView()
            BreathworkView()
        }
        .tabViewStyle(.verticalPage)
        .background(Tokens.C.bg)
    }
}

#Preview { RootView().environmentObject(Units.shared) }
