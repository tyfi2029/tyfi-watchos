# TyFi watchOS — Executor Session (hearth)

You build the **native SwiftUI watchOS app** for TyFi. This Mac (hearth, Intel, Xcode 16.4, watchOS 11.5 SDK, Apple Watch Ultra 2 simulator) compiles and runs it. Re-implement the SwiftUI way — never embed a WebView.

## Targets
- watchOS 11.5 SDK, Xcode 16.4, Swift 6. Device: Apple Watch Ultra 2 (49mm, 410x502).
- App repo: tyfi2029/tyfi-watchos. Bundle: fyi.tyfi.watch (watch app fyi.tyfi.watch.watchkitapp).
- Signing: Automatic, "Apple Development: Tyler Brenenstuhl (GCQP72P4NX)". Simulator builds need no profile.

## Backend — CONSUME, do NOT rebuild
wmp (tyfi2029/wmp, base https://life.tyfi.fyi) already ships the watch contract (verified 2026-06-14):
- /api/watch/{auth,capture,hydration,protocol,quick-log,session,snapshot,venue}
- /api/glance (face/complication feed), /api/sync/status
- /api/health/* (~95 routes incl. recovery,sleep,zone2,metabolic,meals,water,protocol,cgm,glucose,circadian,ans,thermal,environment,skincare,regimen,supplements,rfid,checkin,venues)
- /api/voice/*, /api/smart-home/{eight-sleep,actions,...}, /api/notifications/*, /api/travel/*
If a screen needs a field a route does not emit, log it as a wmp gap — do NOT stub it on the watch.

## Design tokens (handoff README — load-bearing)
- OLED bg #000000. accent #e0813e, warn #e0a14d, good #5fb88f, cool #7aa9cf, bad #e07171, sleep #b98ce0. ink #fff / ink2 0.60 / ink3 0.34. card fill 0.07 white.
- SF Pro; every numeral .monospacedDigit() (tabular). Face clock 118pt orange + live :ss.
- Rings: stroke-dashoffset 500ms cubic-bezier(.2,.7,.2,1). Press scale .93/80ms; value bump 1->1.14->1/340ms.
- Global units: store Fahrenheit + ml internally, format at view layer; toggle re-renders all temp/volume.
- 24 screens. IA: face carries complications; app opens to Now; Smart Stack nudges; Action button -> Voice.

## Credentials
coord webhook token + wmp GitHub read token: resolve from Vaultwarden (v.tyfi.fyi) or env. Do NOT hardcode secrets into repo files.

## Discipline
- Register with session-coord BEFORE writing repo files.
- Verify EVERY screen: xcodebuild -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 2 (49mm)' -> require BUILD SUCCEEDED. No completion claim without it. Show the log tail.
- Phase-0 audit subagent: CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-4-5 (read-only, pass/fail).
- Incomplete work -> coord handoff, never silent end_session.
