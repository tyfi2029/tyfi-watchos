# Fixtures — SYNTHETIC

These JSON fixtures are **synthetic**, hand-built from the §2 FROZEN CONTRACT in
`watchos-overnight-dispatch.md` (verified 2026-06-16) and `Models.swift`. They were
NOT captured live: Task 5 could not mint a verification token in the autonomous run
(no webhook credential resolved; §1 forbids any write to `life.tyfi.fyi` regardless),
so `LIVE_FIXTURES=false`.

Each file stores the **`data` payload** (the unwrapped contents of the `{ok,data,error}`
envelope) so a decode test can do `JSONDecoder().decode(<Type>.self, from: fixture)`.

| File | Type | Endpoint |
|------|------|----------|
| snapshot.json | `Snapshot` | GET /api/watch/snapshot |
| hydration_today.json | `WaterToday` | GET /api/watch/hydration/today |
| hydration_brands.json | `HydrationBrands` | GET /api/watch/hydration/brands |
| protocol_today.json | `ProtocolToday` | GET /api/watch/protocol/today (camelCase) |
| sleep.json | `SleepReport` | GET /api/watch/sleep |
| trends.json | `Trends` | GET /api/watch/trends |
| environment.json | `EnvironmentReport` | GET /api/watch/environment |
| session.json | `SessionList` | GET /api/watch/session |
| fasting.json | `FastingState` | GET /api/watch/fasting |
| breath.json | `BreathList` | GET /api/watch/breath |
| nutrition.json | `NutritionData` | GET /api/watch/nutrition |
| zone2.json | `Zone2Data` | GET /api/watch/zone2 |
| winddown.json | `WindDownData` | GET /api/watch/winddown |
| flight.json | `FlightData` | GET /api/watch/flight |
| home.json | `HomeData` | GET /api/watch/home |
| venue_nearby.json | `VenueList` | GET /api/watch/venue/nearby |

**Morning action:** re-capture these live (read-only GET with a real token) and overwrite,
then the decode tests become true contract-conformance checks against production shapes.
