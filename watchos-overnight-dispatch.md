# Overnight Dispatch — tyfi-watchos to Archive-Ready (88 tasks, unsupervised)

**Mission:** take `tyfi2029/tyfi-watchos` from "views exist, unwired, never compiled on macOS" to "all views wired, all targets build green in the watchOS Simulator, complications + Smart Stack done, unsigned archive dry-run passes, morning handoff written." Run **autonomously through the night**, committing a resumable checkpoint after every task.

**Repo (edit):** `tyfi2029/tyfi-watchos` @ `main` · **Backend (read-only ref):** `tyfi2029/wmp` @ `master` · **Live:** `https://life.tyfi.fyi` · **macOS build host:** hearth `100.67.254.53`

---

## §00 · EXECUTION HARNESS (READ FIRST — this is what makes it survive the night)

**Substrate:** run as **Claude Code on hearth** (`100.67.254.53`, the macOS host) against a **local clone** of `tyfi2029/tyfi-watchos`. Local Mac ⇒ local `xcodebuild`, local `git`, no SSH-relay fragility.

**Preflight (already passed — skip re-running):** xcodebuild 16.4 ✅ · xcodegen ✅ · repo main@dceb8ef ✅ · SIM_UDID 0E618FB6 (Apple Watch Series 10 46mm, watchOS 11.5) ✅ · claude CLI v2.1.179 ✅

**Build check — use everywhere a task says "build green":**
```bash
set -o pipefail
xcodebuild -scheme TyFiWatch -destination "platform=watchOS Simulator,id=0E618FB6" build 2>&1 | tee /tmp/xb.log | xcbeautify
rc=${PIPESTATUS[0]}
[ $rc -ne 0 ] && grep -nE "error:" /tmp/xb.log | head
```

**Commits:** after each task gate → `git add -A && git commit -m "<task msg>" && git push`. One commit per task = one resume point.

**Failure classes:**
- **Code error** (compile/type/decode) → fix, retry ≤3, then `BLOCKED`.
- **Environment error** (sim won't boot, toolchain, DerivedData, provisioning) → clear once (`xcrun simctl shutdown all; rm -rf ~/Library/Developer/Xcode/DerivedData/TyFiWatch-*`), if still broken jump to Task 88 and stop.

**Fixture fallback:** if Task 5 can't mint a token, read WMP route source (`tyfi2029/wmp` `src/app/api/watch/.../route.ts`, read-only) and hand-build a representative fixture from its `ok({...})` return; decode-test against that. Mark such fixtures `synthetic` in the ledger.

**OUTER LOOP — drive from a re-spawn loop so each invocation does a bounded slice:**
```bash
# on hearth, inside tmux session "overnight-watchos":
cd ~/tyfi-watchos
while :; do
  ~/.local/npm/bin/claude --dangerously-skip-permissions -p "Resume the overnight build. Read OVERNIGHT-PROGRESS.md, start at the first incomplete task in watchos-overnight-dispatch.md, do ~8-12 tasks MAX, commit each, update the ledger, then STOP. Obey §00/§0/§1. On global-stop run Task 88 and write DONE-SENTINEL." 2>&1 | tee -a /tmp/overnight-watchos.log
  [ -f DONE-SENTINEL ] && break
  sleep 60
done
```

**Ledger line (append every task):** `2026-06-17THH:MM | T<n> | DONE|BLOCKED:<reason>|DEP-BLOCKED | build:ok/fail | <sha>`

---

## §0 · AUTONOMY CONTRACT

- Work tasks **in order**. After each task reaches its acceptance gate (§5), **commit** and update `OVERNIGHT-PROGRESS.md`.
- **Per-task circuit breaker:** 3 failed attempts → mark `BLOCKED:<reason>`, revert only that task's file changes so `main` stays green, move to next independent task.
- If a blocked task is a hard dependency, mark dependents `DEP-BLOCKED` and skip them.
- **Global stop** → jump to Task 88 if: ≥6 tasks blocked, OR a phase boundary build can't be made green, OR context/overload forces it.
- **`main` MUST never be left non-compiling.** Revert any change that breaks build before moving on.
- **Resume:** read `OVERNIGHT-PROGRESS.md`, find first incomplete task, continue from there.

## §1 · HARD NO-GO

1. **NEVER** POST/PUT/PATCH/DELETE against `life.tyfi.fyi`. GET only for fixture capture.
2. **NEVER** run prod SQL writes.
3. **NEVER** edit `tyfi2029/wmp`.
4. **NEVER** touch infra: WMP host, Caddy, Authelia, pm2, n8n, InfluxDB, deploy scripts.
5. **NEVER** attempt code signing, provisioning, or TestFlight/App Store upload. Archive dry-runs are **UNSIGNED** only.
6. **POST-path verification = Simulator + `MockURLProtocol` only.** Never exercise a real write endpoint.
7. No "done" without evidence (§5). No fabricated results.

## §2 · FROZEN CONTRACT (verified 2026-06-16)

**Transport/auth:** base `https://life.tyfi.fyi`; envelope `{ok,data,error}`, throw on `ok=false`; `Authorization: Bearer <raw>`. `API.shared` (actor) provides `get`/`post`/`postPublic`. **401 recovery:** API.swift clears Keychain + posts `watchAuthExpired`; RootView re-shows PairingView. Token in Keychain `fyi.tyfi.watch/bearerToken`, minted via `POST /api/watch/auth/redeem {code,device_name}`.

**Snapshot — GET `/api/watch/snapshot` (verified live):** `data = {fetched_at, cgm{glucose_mg_dl,trend,fresh_seconds_ago}, readiness{recovery,hrv,sleep,rhr,focus}, dol_next{id,title,due_at}, water_today{ml,goal_ml,pace_ml,brand,oasis_score}, protocol_progress{done,total,current_segment,next_segment_at}, supplement_am_done, supplement_pm_done, last_thermal_session{mode,completed_at,duration_sec,temp_f}, steps}`. Also emits `flight:null, smart_nudge:null` → **ignore, do not add to struct.**

**Endpoint → type map:**

| View(s) | Endpoint(s) | Type(s) |
|---|---|---|
| NowView, ReadinessView | GET /snapshot | `Snapshot` |
| WaterView | GET /hydration/today, /hydration/brands · POST /hydration/log | `WaterToday`, `HydrationBrands`, `HydrationLog` |
| ProtocolView | GET /protocol/today · POST /protocol/item/{id}/toggle | `ProtocolToday`, `ProtocolToggle` |
| SleepView | GET /sleep | `SleepReport` |
| TrendsView | GET /trends | `Trends` |
| EnvironmentView | GET /environment | `EnvironmentReport` |
| SessionTimerView | GET /session · POST /session/start,/end,/detect | `SessionList`, session start/end/detect bodies |
| FastingView | GET+POST /fasting | `FastingState`, `FastingAction`, `FastingPostResult` |
| BreathworkView | GET+POST /breath | `BreathList`, `BreathStart/End`, `BreathStartResult` |
| NutritionView | GET /nutrition | `NutritionData` |
| Zone2View | GET /zone2 | `Zone2Data` |
| WindDownView | GET /winddown | `WindDownData` |
| FlightView | GET /flight | `FlightData` |
| HomeView | GET /home | `HomeData` |
| CheckInView | GET /venue/nearby · POST /venue/checkin,/rate | `VenueList`, `VenueCheckin{Body,Result}`, `VenueRating{Body,Result}` |
| CaptureView, VoiceNoteView | POST /capture/* · /quick-log | **`CaptureBody`(ADD)**, `CaptureResult`, `QuickLog{Body,Result}` |
| LiveSensorsView | — HealthKit; glucose from /snapshot | — |

**Verified specifics — do NOT "fix":** `protocol/today` returns **camelCase** (`rangeStart`/`rangeEnd`/`tempF`) via `groupBySegment` → Swift matches, no CodingKeys. `session` maps DB `ended_at→completed_at`, `duration_minutes→duration_sec`, `therapy_type→mode`, `temperature`(C→F)`→temp_f`. `venue/checkin`→`{checkin_id,venue_name}`, body `{venue_id,checked_in_at,lat?,lng?}`. `venue/rate`→`{venue_id,stars}`, body `{venue_id,stars,rated_at}`. `capture/voice`→`{capture_id}`, body **requires** `{transcript,idempotency_key}` + optional `{category_hint,captured_at,metadata}`.

**Design system (already in `TyFiWatch/DesignSystem`):** use existing `Tokens` (accent #e0813e, warn #e0a14d, good #5fb88f, cool #7aa9cf, bad #e07171, sleep #b98ce0, true-black bg), `Type` (SF Pro, `.monospacedDigit()` on every number), `Units.shared` (°F/°C, ml/L/oz; store F+ml, format at view). Motion: press 0.93/80ms, bump 1→1.14→1/340ms, ring 500ms.

## §3 · VERIFICATION METHOD

- **GET decode** → assert the §2 type decodes a captured **fixture** (`TyFiWatchTests/Fixtures/<endpoint>.json`). Fixtures captured in Task 6 (read-only GETs) or seeded by Ty.
- **POST paths** → `MockURLProtocol` returns canned `{ok,data}` / `{ok:false,error}`; assert request body shape + success/failure handling. **Never** hit the live write endpoint.
- **Build** → `xcodegen generate && xcodebuild -scheme TyFiWatch -destination 'platform=watchOS Simulator,id=0E618FB6' build` on macOS. Green = exit code 0.

## §4 · TASKS

### Phase 0 — Baseline, safety, scaffolding
1. Read `protocols/startup-prompts/cowork.md` + `meta/agent-core-operating-rules.md`; resolve creds from `.claude/skills/devhub-tracker/references/credentials.md`. Coord-register (`session_label:"watch-overnight"`, repo `tyfi2029/tyfi-watchos`, `planned_files`: Models.swift + all `TyFiWatch/Views/*` + HealthKitManager + `TyFiWatchComplications/*` + Info.plist/entitlements). Create `OVERNIGHT-PROGRESS.md` ledger. Commit.
2. `xcodegen generate`; baseline `xcodebuild` of current `main`; record full output to ledger.
3. Resolve all compile errors in existing code + B's §3 structs to reach a **GREEN baseline** (no feature changes). Commit `chore: green baseline build`.
4. Add `CaptureBody: Encodable, Sendable {transcript:String, idempotency_key:String, category_hint:String?, captured_at:String?, metadata:[String:String]?}` to Models.swift. Build green. Commit.
5. Mint a verification token: `POST /api/watch/auth/pair` with the webhook credential → if 6-digit code, `POST /redeem {code,device_name:"overnight-verify"}` → token. If blocked, set `LIVE_FIXTURES=false`, note in ledger, proceed offline-only.
6. If token: GET each read endpoint **once**, save raw JSON to `TyFiWatchTests/Fixtures/<endpoint>.json` (read-only; never POST). Else: create the dir + a `FIXTURES_NEEDED.md` for Ty to seed. Commit.
7. Add `TyFiWatchTests` target with one decode test per fixture (type decodes without error). Build/test green for available fixtures. Commit.
8. Add shared load scaffolding: `enum LoadState<T>{case loading,loaded(T),empty,failed(String)}` + `@MainActor Loader` wrapping `API.shared.get` + reusable Loading/Empty/Error subviews on `Tokens`. Build green. Commit.

### Phase 1 — Snapshot views (verified live, lowest risk)
9. NowView — inspect current data source; record in ledger.
10. NowView — view-model loads GET /snapshot→`Snapshot` via Loader; replace placeholder data.
11. NowView — render 2×2 tiles + insight from decoded fields; LoadState; decode-test vs snapshot fixture; build green; commit.
12. ReadinessView — inspect.
13. ReadinessView — wire /snapshot; recovery ring + hrv/sleep/rhr/focus; LoadState.
14. ReadinessView — fixture decode-test; build green; commit.

### Phase 2 — GET read views (inspect → wire+decode → render+LoadState+test+commit)
15. WaterView — inspect.
16. WaterView — wire GET /hydration/today→`WaterToday` + /hydration/brands→`HydrationBrands` (brand cycle); render.
17. WaterView — LoadState + fixture test; build green; commit.
18. ProtocolView — inspect.
19. ProtocolView — wire GET /protocol/today→`ProtocolToday` (segments + items, camelCase); render.
20. ProtocolView — LoadState + fixture test; build green; commit.
21. SleepView — inspect.
22. SleepView — wire GET /sleep→`SleepReport`; hypnogram via Swift Charts; render.
23. SleepView — LoadState + fixture test; build green; commit.
24. TrendsView — inspect.
25. TrendsView — wire GET /trends→`Trends`; sparkline series + summary; render.
26. TrendsView — LoadState + fixture test; build green; commit.
27. EnvironmentView — inspect.
28. EnvironmentView — wire GET /environment→`EnvironmentReport`; render advisory + metrics.
29. EnvironmentView — LoadState + fixture test; build green; commit.
30. SessionTimerView — inspect (history list portion).
31. SessionTimerView — wire GET /session→`SessionList`; history + 7d rollup; render.
32. SessionTimerView — LoadState + fixture test; build green; commit.
33. FastingView — inspect.
34. FastingView — wire GET /fasting→`FastingState`; elapsed timer + stage + streak + eating window; render.
35. FastingView — LoadState + fixture test; build green; commit.
36. BreathworkView — inspect.
37. BreathworkView — wire GET /breath→`BreathList`; history + rollup; render.
38. BreathworkView — LoadState + fixture test; build green; commit.
39. NutritionView — inspect.
40. NutritionView — wire GET /nutrition→`NutritionData`; macro rings + targets; render.
41. NutritionView — LoadState + fixture test; build green; commit.
42. Zone2View — inspect.
43. Zone2View — wire GET /zone2→`Zone2Data`; rollup + zone bands; render.
44. Zone2View — LoadState + fixture test; build green; commit.
45. WindDownView — inspect.
46. WindDownView — wire GET /winddown→`WindDownData`; checklist + bed-temp target; render.
47. WindDownView — LoadState + fixture test; build green; commit.
48. FlightView — inspect.
49. FlightView — wire GET /flight→`FlightData`; gate/seat/progress/jetlag card; render.
50. FlightView — LoadState + fixture test; build green; commit.
51. HomeView — inspect.
52. HomeView — wire GET /home→`HomeData`; scenes + thermostat + rooms; render.
53. HomeView — LoadState + fixture test; build green; commit.
54. CheckInView — inspect.
55. CheckInView — wire GET /venue/nearby→`VenueList`; GPS-sorted list; render.
56. CheckInView — LoadState + fixture test; build green; commit.

### Phase 3 — Action/POST views (verify via MockURLProtocol only — never live)
57. Add `MockURLProtocol` test infra returning canned `{ok,data}`/`{ok:false,error}`; register in a test scheme. Build/test green. Commit.
58. WaterView `+log` → POST /hydration/log (`HydrationLog`) + optimistic ml bump; mock-verify body + success/fail; commit.
59. ProtocolView `toggle` → POST /protocol/item/{id}/toggle (`ProtocolToggle`) + optimistic check; mock-verify; commit.
60. SessionTimerView `start` → POST /session/start; live elapsed timer; mock-verify; commit.
61. SessionTimerView `end` → POST /session/end; rollup refresh; mock-verify; commit.
62. SessionTimerView detect banner → POST /session/detect (offer **user-confirmed** backfill; no auto-promote); mock-verify; commit.
63. FastingView start/end → POST /fasting (`FastingAction`); mock-verify; commit.
64. BreathworkView start/end → POST /breath (`BreathStart/End`); mock-verify; commit.
65. CheckInView checkin → POST /venue/checkin (`VenueCheckinBody`→`Result`); mock-verify; commit.
66. CheckInView rate → POST /venue/rate (`VenueRatingBody`→`Result`) 5-star; mock-verify; commit.
67. CaptureView → POST /capture/{voice,meal,nfc,paste} via `CaptureBody` (UUID `idempotency_key`); mock-verify each type; commit.
68. VoiceNoteView → record/transcribe → POST /capture/voice via `CaptureBody`; mock-verify; commit.
69. QuickLog → POST /quick-log (`QuickLogBody`→`Result`); mock-verify; commit.

### Phase 4 — HealthKit live
70. Audit `HealthKitManager` (breathwork-HR only); add read types HR, HRV(SDNN), restingHR, respiratoryRate, bloodOxygen, wristTemperature, stepCount, activeEnergy; add HealthKit entitlement + Info.plist usage strings. Build green. Commit.
71. LiveSensorsView — pure HealthKit stream (HR/HRV/SpO₂/skin-temp/motion); glucose from /snapshot CGM; LoadState. Build green. Commit.
72. SessionTimerView — live HR overlay from HealthKit during active session. Commit.
73. Zone2View — live HR + Z1–Z5 zone band from HealthKit. Commit.
74. BreathworkView — live HR + breath-pacing animation. Commit.
75. `HKWorkoutSession` integration for Session/Zone2 (keep app foregrounded + accurate HR during therapy/exercise). Build green. Commit.

### Phase 5 — Complications & Smart Stack
76. `TyFiWatchComplications` — implement `AppIntentTimelineProvider` fetching /snapshot via a shared App-Group cache (reuse Keychain token). Build green. Commit.
77. Families: accessoryCircular (recovery ring), accessoryCorner (glucose), accessoryInline (next protocol), accessoryRectangular (2-stat). Commit.
78. Timeline reload policy + `WidgetCenter.reloadTimelines` on app data change. Commit.
79. Smart Stack relevant rectangular widget surfacing the top next-action. Commit.
80. App Group + shared snapshot cache so widget + app share one fetch (no double auth). Commit.
81. Build all targets together (watch app + complications + widget); resolve cross-target issues; green. Commit.

### Phase 6 — Polish & deploy-prep
82. Navigation/UX: Digital Crown scroll on long views, `.verticalPage` tab order audit, dismiss consistency. Commit.
83. Haptics: wire design haptic events (.success/.click/value-bump) on actions. Commit.
84. Offline resilience: cache last-good snapshot; show stale-with-timestamp on failure; retry; confirm 401→re-pair path. Commit.
85. Accessibility: VoiceOver labels, Dynamic Type, contrast check against `Tokens`. Commit.
86. Release audit: Info.plist version/build bump, entitlements, App Group, bundle IDs, deployment target; **UNSIGNED** `xcodebuild archive` dry-run (do NOT sign/upload); record result. Commit.
87. Full clean build of all targets + all tests green. Record final `** BUILD SUCCEEDED **`. Commit.
88. **MORNING HANDOFF:** write `OVERNIGHT-REPORT.md` — per-task status + commit SHAs, BLOCKED items + reasons, final build/test state, and the **deployment checklist** (sign archive → TestFlight upload → on-device test → **G1 pairing-code page (WMP)** → item-4 score-column migration → item-3 auto-promote decision → seed any missing fixtures → delete phantom row `34806cfd-…`). Write a vault checkpoint. Coord `handoff` with `remaining` + `next_steps`. End.

## §5 · PER-TASK ACCEPTANCE GATE
A task is done only when: (1) the app **builds green** in the Simulator, (2) its verification passes (GET = fixture decode; POST = mock request/response), and (3) it's **committed** with the ledger updated.

## §6 · OUT OF SCOPE
- **G1 pairing-code UI** — WMP Next.js settings page rendering the `/auth/pair` code.
- **Item 4** — `thermal_session_detections.score` INTEGER→`numeric(4,3)` WMP/DB migration.
- **Item 3** — auto-promote design decision (detect→session).
- Any signing, provisioning, or TestFlight/App Store upload.

---
*Run order is risk-ascending: if this stops early, everything before the stop point is committed, green, and resumable. `main` is never left broken.*
