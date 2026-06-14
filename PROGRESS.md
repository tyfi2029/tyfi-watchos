# TyFi watchOS PROGRESS

## Phase A — Pairing Flow
[done] A1: watch_pairing_codes table created. Columns: id,code,device_name,created_at,expires_at,used_at,issued_token_hash. Index on code.
[done] A2: POST+GET+DELETE /api/watch/auth/pair — wmp commit 9973edd7, deployed BUILD_ID mla2RdOWQl__Y9Z8YFt_5. HTTP 200 verified.
[done] A3: POST /api/watch/auth/redeem — wmp commit 03bb70d6, deployed same build. HTTP 200, returns token + expires_at.
[done] A4: Settings UI "Pair Apple Watch" — wmp commit 725e0519. WatchPairingCard component in /settings with generate+countdown+paired-devices+revoke. Verified at /settings page.
[done] A5: WatchAuth.swift — Keychain (replaced UserDefaults). Uses kSecClassGenericPassword, service=fyi.tyfi.watch.
[done] A6: PairingView.swift added (postPublic to /api/watch/auth/redeem, onPaired callback); RootView.swift guards on WatchAuth.shared.isPaired.
[done] A7 GATE: pair→code(859259)→redeem→token(64b26718...)→snapshot HTTP 200 with real data.
  CGM: 92 mg/dL rising_slow. Readiness: 49%. Water: 1863ml/3785ml. Steps: 4910.
  Paired devices list: 8 devices. GET /api/watch/auth/pair HTTP 200.

## Phase B — Review Fixes
[done] B1: API.swift stale /api/glance comment removed. Replaced with: "only /api/watch/* accepts this bearer token — /api/glance is Authelia-gated and NOT watch-callable". Added postPublic() method for unauthenticated redeem calls.
[done] B2: project.yml DEVELOPMENT_TEAM="" → DEVELOPMENT_TEAM="E5HE9TGHFQ". Build verification: hearth SSH not reachable from TyFi server (ssh hearth → timeout). Build pending physical access to hearth or Gecko.

## Phase C — Endpoint Verification
[done] C: Swept all 23 watch routes — all use requireWatchAuth (none use requireWebhookAuth). 0 auth issues.
[done] C sweep with real token (16e1e5cb...): 12/12 GET endpoints HTTP 200, POST hydration/log 200. POST session/detect returns 400 "mode required" (correct — missing required param). POST capture/voice returns 400 "idempotency_key required" (correct). No 401s.

## Phase D — Remaining Screens
[pending] D1: /api/watch/nutrition — route not yet created. meals table exists. NutritionView.swift not yet built.
[pending] D2: /api/watch/zone2 — route not yet created. health_zone2_sessions table exists.
[pending] D3-D9: Wind-down, Check-in, Flight, Home, Capture, Voice, Environment screens not yet built.

## Phase E — Enhancements
[pending] E0: HealthKit entitlement not yet added to project.yml.

## Phase F — WidgetKit
[pending] F1: WidgetKit complication target not yet added.

## Phase G/H — Decisions / Deferrals
[decision-needed] G1: NFC tag scan — options: (a) iOS companion app with Core NFC + handoff to watch, (b) defer entirely. No watch-side build until Ty decides.
[deferred] H1: Garden screen — hardware-procurement track. No soil/irrigation hardware exists. Do NOT build.

## Phase I — Device Install
[pending-hardware] I1: Device install blocked on Gecko being reachable from hearth LAN (192.168.20.x). Device UDID: DD16DE6F-5CCC-515B-9C25-C2B71AC4B379. Command when ready: xcrun devicectl device install app --device DD16DE6F-5CCC-515B-9C25-C2B71AC4B379 <signed .app>

## Notes
- wmp repo branch: master
- tyfi-watchos repo branch: main
- WMP deploy: /home/ty/wmp-deploy.sh --force (git pull must be done first if new commits exist)
- WMP server: pm2 delete tyfi-web && pm2 start ecosystem.config.js --only tyfi-web (if pm2 restart step fails mid-deploy)
- Design system: Tokens.C, Type (not Typography), Tokens.S.gutter/cardRadius. No Tokens.S.m.
- API.swift: postPublic() for unauthenticated calls (pairing); post()/get() require token.
