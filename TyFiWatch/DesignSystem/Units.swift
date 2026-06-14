import SwiftUI
import Combine

/// Global units store. Per the handoff spec we store **Fahrenheit + ml**
/// internally and format at the view layer; flipping a toggle re-renders every
/// temperature/volume on screen because views observe this object.
@MainActor
final class Units: ObservableObject {
    @AppStorage("units.metricVolume") var metricVolume: Bool = false   // ml ↔ oz
    @AppStorage("units.celsius") var celsius: Bool = false             // °F ↔ °C

    static let shared = Units()

    // MARK: Volume — internal unit is ml
    func volume(_ ml: Double) -> String {
        if metricVolume {
            return "\(Int(ml.rounded())) ml"
        } else {
            let oz = ml / 29.5735
            return String(format: "%.0f oz", oz)
        }
    }

    /// Just the numeric part (for big readouts where the unit is shown separately).
    func volumeValue(_ ml: Double) -> String {
        metricVolume ? "\(Int(ml.rounded()))" : String(format: "%.0f", ml / 29.5735)
    }
    func volumeUnit() -> String { metricVolume ? "ml" : "oz" }

    // MARK: Temperature — internal unit is °F
    func temp(_ f: Double) -> String {
        if celsius {
            return String(format: "%.0f°C", (f - 32) * 5 / 9)
        } else {
            return String(format: "%.0f°F", f)
        }
    }
}
