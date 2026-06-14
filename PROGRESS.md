# TyFi watchOS PROGRESS

## Phase A — Pairing Flow
[done] A1: watch_pairing_codes table created. Columns: id,code,device_name,created_at,expires_at,used_at,issued_token_hash. Index on code.
[done] A2: POST+GET+DELETE /api/watch/auth/pair — wmp commit 9973edd7, deployed BUILD_ID zd6cibPURW8i7ahPDNTVe. HTTP 200 verified.
[done] A3: POST /api/watch/auth/redeem — wmp commit 03bb70d6, public+rate-limited, returns token+expires_at. HTTP 200 verified.
[done] A4: Settings UI "Pair Apple Watch" — wmp commit 725e0519. WatchPairingCard at /settings: generate+countdown+paired-devices-list+revoke. HTTP 200.
[done] A5: WatchAuth.swift — Keychain (replaced UserDefaults). kSecClassGenericPassword, service=fyi.tyfi.watch, account=bearerToken.
[done] A6: PairingView.swift — 6-digit entry, auto-submit on 6th digit, postPublic() to /api/watch/auth/redeem, onPaired callback. RootView.swift — isPaired guard shows PairingView until token in Keychain.
[done] A7 GATE PASSED: pair→code(859259)→redeem→token(64b26718...)→snapshot HTTP 200.
  CGM: 92 mg/dL rising_slow. Readiness: 49%. Water: 1863ml/3785ml. Steps: 4910. Paired devices list: 8.

## Phase B — Review Fixes
[done] B1: API.swift — removed stale "/api/glance" comment. New: "only /api/watch/* accepts this bearer token — /api/glance is Authelia-gated and NOT watch-callable". Added postPublic() for unauthenticated pairing calls.
[done] B2: project.yml — DEVELOPMENT_TEAM="" → "E5HE9TGHFQ". Build verification: hearth SSH not reachable from TyFi server. Build pending hearth/Gecko access.

## Phase C — Endpoint Verification
[done] C-auth: All 23 /api/watch/* routes use requireWatchAuth. 0 use requireWebhookAuth. Clean.
[done] C-sweep with real token: 12/12 GET endpoints HTTP 200 with real data. POST hydration/log 200. session/detect 400 "mode required" (correct). capture/voice 400 "idempotency_key required" (correct).

## Phase D — New Screens
[done] D1: GET /api/watch/nutrition — health_meal_logs today macros + libre_glucose CGM (value_mgdl/trend_arrow/timestamp columns). HTTP 200. calories=0 (no meals today), glucose=77 mg/dL rising_slow.
[done] D1: NutritionView.swift — macro progress bars (calories/protein/carbs/fat vs targets) + CGM color-coded.
[done] D2: GET /api/watch/zone2 — health_zone2_sessions weekly/today totals + recent sessions. HTTP 200. weekly=238 min / 150 min target (159%).
[done] D2: Zone2View.swift — circular ring (weekly vs 150min target) + recent sessions list.
[pending] D3-D9: Wind-down, Check-in, Flight, Home, Capture, Voice, Environment views not built.

## Phase E — Enhancements
[done] E0: TyFiWatch.entitlements created with com.apple.developer.healthkit capability.
[done] E0: project.yml — HealthKit entitlements path + NSHealthShareUsageDescription + NSHealthUpdateUsageDescription added.
[pending] E1-E9: HealthKit data reads (HRV, steps, SpO2) not yet wired in Swift.

## Phase F — WidgetKit
[pending] F1: WidgetKit complication target not yet added to project.yml.

## Phase G/H — Decisions / Deferrals
[decision-needed] G1: NFC tag scan — options: (a) iOS companion app with Core NFC + handoff to watch, (b) defer entirely. No watch-side build until Ty decides.
[deferred] H1: Garden screen — hardware-procurement track. No soil/irrigation hardware exists. Do NOT build.

## Phase I — Device Install
[pending-hardware] I1: Device install blocked on Gecko being reachable from hearth LAN (192.168.20.x). Device UDID: DD16DE6F-5CCC-515B-9C25-C2B71AC4B379. Command when ready: xcrun devicectl device install app --device DD16DE6F-5CCC-515B-9C25-C2B71AC4B379 <signed .app>

## Tab Order (RootView — 12 screens)
1. NowView 2. WaterView 3. ProtocolView 4. ReadinessView 5. SleepView 6. TrendsView
7. NutritionView 8. Zone2View 9. LiveSensorsView 10. SessionTimerView 11. FastingView 12. BreathworkView

## Infra Notes
- wmp branch: master. tyfi-watchos branch: main.
- WMP deploy pattern: git pull origin master → wmp-deploy.sh --force (takes ~4min). pm2 restart step often fails silently mid-deploy — manually run: pm2 delete tyfi-web && pm2 start ecosystem.config.js --only tyfi-web
- Deploy log: /tmp/wmp-deploy-<label>.log. BUILD_ID in /home/ty/wmp/.next/BUILD_ID.
- libre_glucose real columns: value_mgdl, trend_arrow (int 1-7), timestamp. patient_id LIKE '4fb08ca2%'.
- Design system: Tokens.C, Type (not Typography), Tokens.S.gutter=8 / Tokens.S.cardRadius=14. No Tokens.S.m.
- API.swift: postPublic() for unauthenticated calls; get()/post() require Keychain token.
- WMP coord sessions: 704d8b91 (wmp), 74aa1955 (tyfi-watchos).
