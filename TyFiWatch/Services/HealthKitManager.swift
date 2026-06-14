import HealthKit
import Foundation

/// Minimal HealthKit wrapper for breathwork session HR streaming.
/// Requires com.apple.developer.healthkit entitlement (in TyFiWatch.entitlements).
@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    @Published var currentHR: Double? = nil
    @Published var authorized = false

    func requestAuth() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let readTypes: Set<HKSampleType> = [HKQuantityType(.heartRate)]
        let shareTypes: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKObjectType.workoutType(),
        ]
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            authorized = true
        } catch {}
    }

    func startBreathworkSession() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .mindAndBody
        config.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let b = session.associatedWorkoutBuilder()
            b.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            self.workoutSession = session
            self.builder = b
            session.startActivity(with: Date())
            try await b.beginCollection(at: Date())
        } catch {}
    }

    func stopBreathworkSession() async -> (preHRV: Double?, postHRV: Double?) {
        workoutSession?.end()
        do { try await builder?.endCollection(at: Date()) } catch {}
        do { try await builder?.finishWorkout() } catch {}
        workoutSession = nil
        builder = nil
        return (nil, nil) // HRV post-processing is a future task
    }
}
