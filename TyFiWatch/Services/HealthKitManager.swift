import HealthKit
import Foundation

/// HealthKit wrapper for live sensor streaming (HR, HRV, SpO₂, skin temp,
/// active calories, steps) plus breathwork HKWorkoutSession.
/// All @Published properties are updated on MainActor.
@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    // MARK: - Published live values
    @Published var heartRate: Double?       // bpm
    @Published var hrv: Double?             // SDNN ms
    @Published var spo2: Double?            // fraction 0–1
    @Published var skinTempC: Double?       // °C, night-only, may be nil during day
    @Published var activeCalories: Double?  // kcal today
    @Published var steps: Int?              // steps today

    /// Legacy alias kept for binary compatibility with any caller using currentHR.
    var currentHR: Double? { heartRate }

    @Published var authorized = false

    // MARK: - Breathwork workout session
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    // MARK: - Streaming query handles (retain to keep alive)
    private var hrQuery: HKAnchoredObjectQuery?
    private var hrvQuery: HKAnchoredObjectQuery?
    private var spo2Query: HKAnchoredObjectQuery?
    private var stepsTimer: Timer?
    private var calTimer: Timer?

    // MARK: - Auth

    func requestAuth() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        var readTypes: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.stepCount),
        ]
        if #available(watchOS 9.0, *) {
            readTypes.insert(HKQuantityType(.appleSleepingWristTemperature))
        }

        let shareTypes: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKObjectType.workoutType(),
        ]

        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            authorized = true
        } catch {}
    }

    // MARK: - Start all live streams

    func start() {
        startHRStream()
        startHRVStream()
        startSpo2Stream()
        refreshSteps()
        refreshCalories()
        if #available(watchOS 9.0, *) { refreshSkinTemp() }

        // Refresh cumulative stats every 60 s
        stepsTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSteps()
                self?.refreshCalories()
            }
        }
    }

    func stop() {
        hrQuery.map { store.stop($0) }; hrQuery = nil
        hrvQuery.map { store.stop($0) }; hrvQuery = nil
        spo2Query.map { store.stop($0) }; spo2Query = nil
        stepsTimer?.invalidate(); stepsTimer = nil
        calTimer?.invalidate(); calTimer = nil
    }

    // MARK: - HR stream (HKAnchoredObjectQuery)

    private func startHRStream() {
        let type = HKQuantityType(.heartRate)
        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.handleHRSamples(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handleHRSamples(samples)
        }
        hrQuery = query
        store.execute(query)
    }

    private func handleHRSamples(_ samples: [HKSample]?) {
        guard let s = (samples as? [HKQuantitySample])?.last else { return }
        let bpm = s.quantity.doubleValue(for: .init(from: "count/min"))
        Task { @MainActor [weak self] in self?.heartRate = bpm }
    }

    // MARK: - HRV stream

    private func startHRVStream() {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.handleHRVSamples(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handleHRVSamples(samples)
        }
        hrvQuery = query
        store.execute(query)
    }

    private func handleHRVSamples(_ samples: [HKSample]?) {
        guard let s = (samples as? [HKQuantitySample])?.last else { return }
        let ms = s.quantity.doubleValue(for: .init(from: "ms"))
        Task { @MainActor [weak self] in self?.hrv = ms }
    }

    // MARK: - SpO2 stream

    private func startSpo2Stream() {
        let type = HKQuantityType(.oxygenSaturation)
        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.handleSpo2Samples(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handleSpo2Samples(samples)
        }
        spo2Query = query
        store.execute(query)
    }

    private func handleSpo2Samples(_ samples: [HKSample]?) {
        guard let s = (samples as? [HKQuantitySample])?.last else { return }
        let frac = s.quantity.doubleValue(for: .percent())
        Task { @MainActor [weak self] in self?.spo2 = frac }
    }

    // MARK: - Steps today (cumulative)

    private func refreshSteps() {
        let type = HKQuantityType(.stepCount)
        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: nil)
        let q = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: pred,
            options: .cumulativeSum
        ) { [weak self] _, stats, _ in
            let v = stats?.sumQuantity()?.doubleValue(for: .count())
            Task { @MainActor [weak self] in self?.steps = v.map { Int($0) } }
        }
        store.execute(q)
    }

    // MARK: - Active calories today (cumulative)

    private func refreshCalories() {
        let type = HKQuantityType(.activeEnergyBurned)
        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: nil)
        let q = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: pred,
            options: .cumulativeSum
        ) { [weak self] _, stats, _ in
            let v = stats?.sumQuantity()?.doubleValue(for: .kilocalorie())
            Task { @MainActor [weak self] in self?.activeCalories = v }
        }
        store.execute(q)
    }

    // MARK: - Skin temperature (most recent sleeping wrist temp -- night-only)

    @available(watchOS 9.0, *)
    private func refreshSkinTemp() {
        let type = HKQuantityType(.appleSleepingWristTemperature)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let s = (samples as? [HKQuantitySample])?.first else { return }
            let c = s.quantity.doubleValue(for: .degreeCelsius())
            Task { @MainActor [weak self] in self?.skinTempC = c }
        }
        store.execute(q)
    }

    // MARK: - Breathwork session

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
        return (nil, nil)
    }
}
