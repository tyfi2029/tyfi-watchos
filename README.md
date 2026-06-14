# TyFi watchOS

Native SwiftUI app for Apple Watch Ultra 2 (watchOS 11.5). Consumes the wmp
watch contract at `https://life.tyfi.fyi/api/watch/*` + `/api/glance`. No WebView.

## Build

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonik0/XcodeGen):

```bash
xcodegen generate
xcodebuild -project TyFiWatch.xcodeproj -scheme TyFiWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 2 (49mm)' \
  CODE_SIGNING_ALLOWED=NO build
```

`TyFiWatch.xcodeproj/` is git-ignored — regenerate it after pulling.

## Layout

- `TyFiWatch/DesignSystem/` — Tokens (color), Typography, Motion, Units, Components.
- `TyFiWatch/Services/` — `API` (watch-auth client), `WatchAuth` (bearer token).
- `TyFiWatch/Models/` — Codable mirrors of the verified wmp watch contract.
- `TyFiWatch/Views/` — screens. Phase 1: Now, Water, Protocol, Readiness.

## Backend contract

Only `/api/watch/*` and `/api/glance` accept the watch bearer token; `health/*`
routes require the webhook token and are **not** watch-callable. See the gap
re-audit in `development-hub/checkpoints/2026-06-14-watch-gap-reaudit.md`.
