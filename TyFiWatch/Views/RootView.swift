import SwiftUI

/// Entry point. Shows PairingView until a valid Keychain token is present,
/// then switches to the main tab carousel. No network call on launch.
struct RootView: View {
    @State private var isPaired = WatchAuth.shared.isPaired

    var body: some View {
        Group {
            if isPaired {
                mainTabView
            } else {
                PairingView(onPaired: { isPaired = true })
            }
        }
    }

    @ViewBuilder
    private var mainTabView: some View {
        TabView {
            NowView()
            WaterView()
            ProtocolView()
            ReadinessView()
            SleepView()
            TrendsView()
            NutritionView()
            Zone2View()
            LiveSensorsView()
            SessionTimerView()
            FastingView()
            BreathworkView()
            WindDownView()
            EnvironmentView()
            CheckInView()
            FlightView()
            HomeView()
            CaptureView()
        }
        .tabViewStyle(.verticalPage)
        .background(Tokens.C.bg)
    }
}

#Preview { RootView().environmentObject(Units.shared) }
