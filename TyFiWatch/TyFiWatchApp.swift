import SwiftUI

@main
struct TyFiWatchApp: App {
    @StateObject private var units = Units.shared
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(units)
                .tint(Tokens.C.accent)
                .preferredColorScheme(.dark)
        }
    }
}
