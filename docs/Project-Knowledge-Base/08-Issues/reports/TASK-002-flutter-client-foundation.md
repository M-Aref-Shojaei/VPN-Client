---
id: report-task-002
title: TASK-002 — Flutter client foundation
created: 2026-07-18
tags: [report, flutter, ui]
---

# TASK-002: Flutter client foundation

## Problem

The repository had v2rayN GUI state but no UI source, shared cross-platform project, product
navigation, profile import flow, routing editor, or platform tunnel contract.

## Solution

- Scaffolded Flutter targets for Android, iOS, Windows, macOS, and Linux.
- Added responsive navigation for mobile and desktop widths.
- Added connection status/capability UI that does not claim an unavailable adapter is connected.
- Added domain route inspection and manual direct/proxy rule editing.
- Added validated sing-box outbound profile JSON import and selection.
- Added light/dark Material 3 themes.
- Defined the `dev.adaptivevpn/tunnel` MethodChannel contract.
- Added routing unit tests and connection/profile widget tests.
- Documented platform responsibilities and native-adapter delivery boundaries.

## Files changed

- `app/lib/main.dart`
- `app/lib/src/app.dart`
- `app/lib/src/controller/*`
- `app/lib/src/models/*`
- `app/lib/src/screens/*`
- `app/lib/src/services/*`
- `app/test/*`
- Flutter-generated platform directories under `app/`
- `docs/Project-Knowledge-Base/01-Architecture/Platform-Matrix.md`
- `docs/Project-Knowledge-Base/03-Product/Product-Requirements.md`

## Verification

- `dart format lib test`
- `flutter analyze --no-pub`
- `flutter test --no-pub`

Native artifact compilation remains blocked on this workstation by missing platform build
toolchains and is tracked separately from the UI foundation.
