import XCTest
// Models.swift is compiled directly into this host-less test bundle (see project.yml),
// so no @testable import of the app module is needed.

/// §3 GET verification: assert each §2 type decodes its captured fixture without error.
/// Fixtures are the unwrapped `data` payload (see Fixtures/README.md). Synthetic until
/// re-captured live (LIVE_FIXTURES=false this run).
final class FixtureDecodeTests: XCTestCase {

    /// Loads a fixture JSON from the test bundle and decodes it as `T`.
    private func decode<T: Decodable>(_ name: String, as _: T.Type,
                                      file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json") else {
            XCTFail("Fixture \(name).json not found in test bundle", file: file, line: line)
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func testSnapshot() throws {
        let s = try decode("snapshot", as: Snapshot.self)
        XCTAssertEqual(s.cgm?.glucose_mg_dl, 92)
        XCTAssertEqual(s.readiness?.recovery, 72)
        XCTAssertEqual(s.water_today?.goal_ml, 2500)
        XCTAssertEqual(s.protocol_progress?.total, 9)
    }

    func testHydrationToday() throws {
        let w = try decode("hydration_today", as: WaterToday.self)
        XCTAssertEqual(w.ml, 1600)
        XCTAssertEqual(w.brand, "Liquid IV")
    }

    func testHydrationBrands() throws {
        let b = try decode("hydration_brands", as: HydrationBrands.self)
        XCTAssertEqual(b.brands?.count, 3)
    }

    func testProtocolToday() throws {
        // §2: protocol/today is camelCase (rangeStart/rangeEnd/tempF) — no CodingKeys.
        let p = try decode("protocol_today", as: ProtocolToday.self)
        XCTAssertEqual(p.segments.count, 3)
        XCTAssertEqual(p.segments.first?.rangeStart, "06:00")
        XCTAssertEqual(p.segments.first?.items.first?.tempF, nil)
        XCTAssertEqual(p.segments[0].items[1].tempF, 180.0)
    }

    func testSleep() throws {
        let s = try decode("sleep", as: SleepReport.self)
        XCTAssertEqual(s.duration?.total_min, 442)
        XCTAssertEqual(s.hypnogram?.count, 20)
    }

    func testTrends() throws {
        let t = try decode("trends", as: Trends.self)
        XCTAssertEqual(t.series?["recovery"]?.count, 7)
        XCTAssertEqual(t.summary?["hrv"]??.delta, 5)
    }

    func testEnvironment() throws {
        let e = try decode("environment", as: EnvironmentReport.self)
        XCTAssertEqual(e.air_quality?.category, "Good")
        XCTAssertEqual(e.uv?.index, 6.0)
    }

    func testSession() throws {
        let s = try decode("session", as: SessionList.self)
        XCTAssertEqual(s.sessions.count, 3)
        XCTAssertEqual(s.rolling_7d?.heat_min, 116)
    }

    func testFasting() throws {
        let f = try decode("fasting", as: FastingState.self)
        XCTAssertEqual(f.active?.stage, "ketosis")
        XCTAssertEqual(f.active?.protocol, "16:8")
        XCTAssertEqual(f.streak, 12)
    }

    func testBreath() throws {
        let b = try decode("breath", as: BreathList.self)
        XCTAssertEqual(b.sessions.count, 2)
        XCTAssertEqual(b.rolling_7d?.total_min, 36)
    }

    func testNutrition() throws {
        let n = try decode("nutrition", as: NutritionData.self)
        XCTAssertEqual(n.today?.protein, 118)
        XCTAssertEqual(n.targets?.calories, 2200)
    }

    func testZone2() throws {
        let z = try decode("zone2", as: Zone2Data.self)
        XCTAssertEqual(z.weekly?.pct, 79)
        XCTAssertEqual(z.recent_sessions?.count, 2)
    }

    func testWindDown() throws {
        let w = try decode("winddown", as: WindDownData.self)
        XCTAssertEqual(w.eight_sleep?.targetTempF, 68.0)
        XCTAssertEqual(w.checklist?.count, 3)
    }

    func testFlight() throws {
        let f = try decode("flight", as: FlightData.self)
        XCTAssertEqual(f.active_flight?.flight_number, "UA 2291")
        XCTAssertEqual(f.jetlag?.direction, "west")
    }

    func testHome() throws {
        let h = try decode("home", as: HomeData.self)
        XCTAssertEqual(h.scenes?.count, 3)
    }

    func testVenueNearby() throws {
        let v = try decode("venue_nearby", as: VenueList.self)
        XCTAssertEqual(v.venues?.count, 3)
        XCTAssertEqual(v.venues?.first?.name, "Othership Sauna")
    }
}
