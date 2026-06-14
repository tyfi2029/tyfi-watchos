# FIRST TASK — gap re-audit + scaffold

## Phase 0 — gap re-audit (Haiku subagent, READ-ONLY)
The handoff PRD gap analysis is STALE vs live wmp master (verified 2026-06-14: Environment/NFC/checkin/glance/sync/watch namespaces already exist). Re-derive truth.
For each of the 24 screens, resolve every read/write to a concrete route under wmp src/app/api/ (start /api/watch/*, then /api/health/*, /api/glance, /api/sync, /api/voice, /api/smart-home, /api/notifications, /api/travel). Confirm the route emits the needed fields. Classify BACKED | PARTIAL (name missing fields) | MISSING. Output a table; commit to development-hub checkpoints/2026-06-14-watch-gap-reaudit.md. No wmp src edits.

## Phase 1 — scaffold (NOT gated on Phase 0)
1. coord register: agent_type=claude-code, repo=tyfi2029/tyfi-watchos, planned_files=[scaffold], description="watchOS scaffold + design system".
2. Create/init tyfi2029/tyfi-watchos. Xcode watchOS app target (SwiftUI, watchOS 11.5).
3. Design system module: Color / Typography / Motion / Units from CLAUDE.md tokens.
4. Build the confirmed-BACKED, highest-value screens first: Now, Water, Protocol, Readiness — wired to /api/watch/* + /api/health/*; auth via /api/watch/auth.
5. GATE: xcodebuild to Ultra 2 (49mm) sim -> BUILD SUCCEEDED. Capture log tail. coord add_note per screen.

## Phase 2 — remaining BACKED/PARTIAL screens (per Phase-0 table)
Wire the rest. For PARTIAL, consume what exists; log missing fields as wmp gaps.

## Phase 3 — genuinely MISSING (Fasting / Breathwork engine / Garden + slivers: thermal auto-detect, noise dosimetry, water Oasis catalog)
These likely need NEW wmp backend. DO NOT build watch UI against nonexistent endpoints. Emit a coord-registered wmp dispatch for each missing backend; build the watch screen only after its endpoint returns 200 with the needed fields.

## Done = per phase: BUILD SUCCEEDED + coord notes + (Phase 0) checkpoint committed.


## CRITICAL CONSTRAINTS (verified 2026-06-13 — read BEFORE Phase 0)
1. WATCH AUTH SURFACE. The watch can ONLY reach the token-gated /api/watch/* namespace
   (verified: /api/watch/snapshot -> app-level 401 UNAUTHORIZED, not an SSO redirect).
   /api/health/*, /api/glance, /api/travel/* are Authelia-gated (verified: /api/glance
   redirects to auth.tyfi.fyi) and are NOT reachable by a watch client.
   => In Phase 0, mark a screen BACKED only if its data is reachable via /api/watch/*.
      FIRST inspect src/app/api/watch/snapshot/route.ts — it is likely a composite; enumerate
      exactly which fields it returns. A route under /api/health/* does NOT make a screen
      watch-BACKED; mark those "NEEDS WATCH-SURFACE EXPOSURE" (backend task: surface the field
      on /api/watch/* or extend snapshot), NOT a watch-UI task.
2. CORE NFC is unavailable to 3rd-party watchOS apps. Screen 11 (Tag scan) CANNOT be built on
   the watch as designed. Do NOT attempt it in Phase 1/2; flag for redesign (iPhone-side Core
   NFC + handoff, or manual tap-to-log on watch).
3. SIGNING: automatic, team E5HE9TGHFQ, Apple Development identity. Simulator needs no profile;
   on-device dev works now. No Distribution cert present -> TestFlight/App Store deferred.
