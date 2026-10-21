---
id: testing-strategy
title: Testing Strategy
created: 2026-07-18
updated: 2026-07-21
tags: [quality, testing]
---

# Testing Strategy

## Current automated checks

| Layer | Command | Coverage |
|---|---|---|
| Go unit | `cd core && go test ./...` | routing, learning, live rule-set, failure watcher, config shape, private files, desktop lifecycle |
| Go race | `cd core && go test -race ./...` | watcher/service concurrency and all Go packages |
| Go static | `cd core && go vet ./...` | common correctness defects |
| Flutter static | `cd app && flutter analyze` | Dart/Flutter diagnostics and lints |
| Flutter unit/widget | `cd app && flutter test` | routing/UI, secure snapshots, eight link families, subscriptions, signed rules, desktop control |
| Core compatibility | `sing-box check -c <generated-config>` | generated schema against packaged sing-box |

The Linux lifecycle suite starts a helper process without a shell, checks `0600` files, exercises
status and graceful stop, rejects a reused PID, and verifies ANSI-free errors. A live sing-box probe
also confirms early kernel-permission failure is detected and leaves no running state.

The control-socket suite requires local Unix-socket permission. Signed-rule tests generate an
ephemeral Ed25519 key and reject stale, cross-origin, and invalid-signature data. Subscription tests
reject HTTP, oversized responses, and bad status. The WireGuard example is checked by the pinned
sing-box 1.13.14 binary.

The automatic-routing tests reject non-direct failures, IP targets, malformed domains, duplicate
events inside the cooldown, and pre-existing log lines. Config tests prove the observer mixed inbound
uses `proxy`, manual direct precedes the learned rule-set, and `route.final` remains `direct`. The live
mixed-inbound run confirmed the generated rule-set and runtime config are mode `0600`; a real TUN
attempt reached and cleanly recovered from the host's `TUNSETIFF` privilege denial.

Windows validation currently covers AMD64 cross-compilation of `routerctl` and Windows-only test
packages, shared race tests, and the Flutter credential-safe adapter contract. The Windows helper
lifecycle test deliberately skips without an elevated Windows host because its protected ACL is
part of the behavior under test.

## Required integration suites

### Linux network namespace

- Simulated open destination reachable directly.
- Simulated blocked destination times out/resets direct but succeeds through proxy.
- DNS poisoning signal plus proxy success.
- No learning when both paths fail.
- IPv4/IPv6 and TCP/UDP route verification.
- Cleanup after SIGTERM, SIGKILL recovery, and helper crash.

### Mobile

- VPN permission denial/retry.
- Process/background lifecycle.
- Wi-Fi/cellular transition and captive portal.
- App inclusion/exclusion.
- Device sleep and low-memory restart.

### Desktop

- Driver/helper installation and rollback.
- Multiple interfaces and virtual-machine adapters.
- DNS leak prevention.
- OS update and application upgrade.

## Release gates

Every release records exact Flutter, Go, sing-box, Android Gradle, Xcode, Windows SDK, and packaging
versions. Generated configs are checked using the exact sing-box binary being shipped.
