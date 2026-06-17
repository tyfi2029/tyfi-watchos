import XCTest

/// §3 POST verification (hermetic). Two concerns, no network:
///  1. Request body shape — encode each POST body with JSONEncoder exactly as
///     `API.post`/`postPublic` do, and assert keys/values match the §2 frozen contract.
///  2. Success/failure handling — decode `Envelope<T>` (the very type `API.send` uses)
///     for `{ok,data}` and `{ok:false,error}` and assert payload vs error behaviour.
final class PostContractTests: XCTestCase {

    private func json<T: Encodable>(_ value: T,
                                    file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try XCTUnwrap(obj, "encoded value was not a JSON object", file: file, line: line)
    }

    // MARK: 1. Body shapes

    func testHydrationLogBody() throws {
        let j = try json(HydrationLog(amount_ml: 350, brand: "LMNT", logged_at: "2026-06-17T16:00:00Z"))
        XCTAssertEqual(j["amount_ml"] as? Double, 350)
        XCTAssertEqual(j["brand"] as? String, "LMNT")
        XCTAssertEqual(j["logged_at"] as? String, "2026-06-17T16:00:00Z")
    }

    func testProtocolToggleBody() throws {
        let j = try json(ProtocolToggle(done: true, toggled_at: "2026-06-17T16:00:00Z"))
        XCTAssertEqual(j["done"] as? Bool, true)
        XCTAssertEqual(j["toggled_at"] as? String, "2026-06-17T16:00:00Z")
    }

    func testFastingActionBody() throws {
        XCTAssertEqual(try json(FastingAction(action: "start"))["action"] as? String, "start")
        XCTAssertEqual(try json(FastingAction(action: "end"))["action"] as? String, "end")
    }

    func testBreathStartBodyHasConstantAction() throws {
        let j = try json(BreathStart(technique: "box", target_duration_seconds: 300,
                                     target_cycles: 10, pre_hrv_deviation: -0.2, pre_stress_tier: 2))
        XCTAssertEqual(j["action"] as? String, "start")
        XCTAssertEqual(j["technique"] as? String, "box")
        XCTAssertEqual(j["target_duration_seconds"] as? Int, 300)
    }

    func testSessionStartBody() throws {
        let j = try json(SessionStartBody(mode: "cold", temp_f: 48, target_sec: 180,
                                          started_at: "2026-06-17T16:00:00Z",
                                          backfill_sec: nil, detection_source: nil, detection_score: nil))
        XCTAssertEqual(j["mode"] as? String, "cold")
        XCTAssertEqual(j["temp_f"] as? Double, 48)
        XCTAssertEqual(j["target_sec"] as? Int, 180)
    }

    func testVenueCheckinBody() throws {
        // §2: body {venue_id, checked_in_at, lat?, lng?}
        let j = try json(VenueCheckinBody(venue_id: 501, checked_in_at: "2026-06-17T16:00:00Z",
                                          lat: 39.7, lng: -104.9))
        XCTAssertEqual(j["venue_id"] as? Int, 501)
        XCTAssertEqual(j["checked_in_at"] as? String, "2026-06-17T16:00:00Z")
        XCTAssertEqual(j["lat"] as? Double, 39.7)
    }

    func testVenueRatingBody() throws {
        // §2: body {venue_id, stars, rated_at}
        let j = try json(VenueRatingBody(venue_id: 501, stars: 5, rated_at: "2026-06-17T16:00:00Z"))
        XCTAssertEqual(j["venue_id"] as? Int, 501)
        XCTAssertEqual(j["stars"] as? Int, 5)
    }

    func testCaptureBodyRequiresTranscriptAndKey() throws {
        // §2: capture/voice body requires {transcript, idempotency_key} + optionals.
        let j = try json(CaptureBody(transcript: "ate eggs", idempotency_key: "uuid-1",
                                     category_hint: "meal", captured_at: nil, metadata: nil))
        XCTAssertEqual(j["transcript"] as? String, "ate eggs")
        XCTAssertEqual(j["idempotency_key"] as? String, "uuid-1")
        XCTAssertEqual(j["category_hint"] as? String, "meal")
        XCTAssertNil(j["captured_at"])   // nil optionals omitted
    }

    func testQuickLogBody() throws {
        let j = try json(QuickLogBody(category: "mood", text: "great", logged_at: "2026-06-17T16:00:00Z",
                                      metadata: ["score": "8"]))
        XCTAssertEqual(j["category"] as? String, "mood")
        XCTAssertEqual((j["metadata"] as? [String: Any])?["score"] as? String, "8")
    }

    // MARK: 2. Envelope success/failure handling (mirrors API.send)

    func testEnvelopeSuccessYieldsPayload() throws {
        let data = Data(#"{"ok":true,"data":{"checkin_id":"ck_9","venue_name":"Othership"}}"#.utf8)
        let env = try JSONDecoder().decode(Envelope<VenueCheckinResult>.self, from: data)
        XCTAssertTrue(env.ok)
        XCTAssertEqual(env.data?.checkin_id, "ck_9")
        XCTAssertNil(env.error)
    }

    func testEnvelopeFailureCarriesError() throws {
        let data = Data(#"{"ok":false,"error":"venue closed"}"#.utf8)
        let env = try JSONDecoder().decode(Envelope<VenueCheckinResult>.self, from: data)
        XCTAssertFalse(env.ok)
        XCTAssertNil(env.data)
        XCTAssertEqual(env.error, "venue closed")
        // API.send throws APIError.envelope(error) for exactly this shape.
    }
}
