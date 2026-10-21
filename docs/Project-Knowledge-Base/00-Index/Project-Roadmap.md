---
id: project-roadmap
title: Project Roadmap
created: 2026-07-07
updated: 2026-07-21
tags: [roadmap, planning]
---

# Project Roadmap

Home: [[00-Index/Home]]

## Phase 0 — Runtime investigation ✅

- Captured v2rayN Xray and sing-box configurations.
- Confirmed legacy Linux system-proxy behavior.
- Identified Hiddify and v2rayN as references rather than suitable universal foundations.
- Re-evaluated Hiddify App `4.1.x` and Hiddify Core `v3`: retain a clean-room product while using
  their cross-platform UX and privileged desktop service split as reference patterns.

## Phase 1 — Product foundation ✅

- Created a Flutter project for Android, iOS, Windows, macOS, and Linux.
- Added responsive connection, routing, and profile screens.
- Added a platform tunnel-service contract with explicit capability reporting.
- Built a Go routing learner, policy evaluator, sing-box route exporter, and full config generator.
- Added Go, Dart model, and Flutter widget tests.
- Validated generated output with the bundled sing-box 1.13.14 `check` command.

Phase 1 is a configuration and UX foundation. It does not yet establish a privileged system tunnel.

## Phase 2 — Linux vertical slice 🔄

- [x] Implement a typed Linux Flutter-to-`routerctl` process adapter.
- [x] Pin and verify the development sing-box 1.13.14 Linux AMD64 checksum.
- [x] Add config validation, private atomic runtime files, process identity checks, startup-failure
      detection, and graceful/forced shutdown.
- [x] Implement a group-restricted Unix-socket service with fixed privileged paths, bounded
      requests, systemd capability sandboxing, and explicit install/uninstall scripts.
- [ ] Install the Linux service and pass a real TUN/network-namespace test on a host with
      `/dev/net/tun` and `CAP_NET_ADMIN`.
- [x] Add direct/TLS failure classification, SOCKS proxy retry, and `router.Learner` persistence.
- [x] Feed conservative sing-box direct-failure events into the observer, verify the real proxy
      path, and auto-reload network-scoped learned rules without restarting the tunnel.
- [x] Persist profiles, policies, subscriptions, and trusted rule metadata through OS secure
      storage.
- [ ] Add an end-to-end network namespace test for direct/proxy routing.
- [ ] Expose Smart TUN, full TUN, and local-proxy modes in the desktop UI after the corresponding
      mode contracts are enforced end to end.

The service protocol passed capability, mixed-proxy start/status/stop, smart-route configuration,
and cleanup tests. A TUN launch reached `TUNSETIFF` and was correctly denied by this environment;
it left no false running state. Installing the service is intentionally a separate, explicit system
administration action.

## Phase 3 — Android vertical slice

- [x] Pin a reproducible official libbox AAR build script and Android API 23 baseline.
- [ ] Implement `VpnService`, permission flow, foreground notification, and protected sockets.
- [ ] Bind the Go/sing-box core through a mobile-safe library interface.
- [ ] Add package-based split routing and lifecycle recovery.
- [ ] Validate sleep, network switch, captive portal, and process restart behavior.

## Phase 4 — Apple platforms

- [x] Pin a macOS-only official libbox XCFramework build script.
- [ ] Implement Network Extension packet tunnel targets.
- [ ] Configure signing, entitlements, app groups, and shared profile storage.
- [ ] Validate iOS background limits and macOS system extension behavior.

## Phase 5 — Windows

- [x] Implement a least-privilege Windows service/control boundary; the Flutter process must not
      run as Administrator.
- [ ] Integrate a signed TUN driver through sing-box and implement full create/teardown recovery.
- [x] Implement checksum-verified, versioned service install/update/rollback.
- [ ] Validate DNS leak prevention and multi-interface changes.

The service, named-pipe ACL, protected process manager, Windows network scope, Flutter adapter, and
transactional packaging compile and pass platform-neutral tests. They have not been executed on a
Windows Administrator host, so the platform gate remains open.

## Phase 6 — Product completion

- [x] Parse VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC, WireGuard, and SSH links.
- [x] Add HTTPS subscription updates with schema, redirect, count, and size validation.
- [x] Add same-origin SHA-256 and Ed25519-verified remote rule-set updates; retain the prior rules
      on every verification failure.
- [ ] Add accessibility, localization, crash recovery, and migration tests.
- [x] Add Go/Flutter tests, Linux bundle CI, cross-platform scaffold CI, and dependency monitoring.
- [ ] Build signed CI artifacts for all supported platforms.
- [ ] Complete security review and store-release checklists.

## Deferred product-design track

Design work is intentionally paused until the product owner resumes it. Current implementation
priority is tunnel and smart-routing correctness.

- [ ] Define the exact screens/components to redesign from user references or annotated
      screenshots.
- [ ] Keep a distinct product name, layout, iconography, and interaction model; do not reproduce
      Hiddify's interface.
- [ ] Add a compact home connection control, visible active-profile selector, route-mode control,
      and a smart-routing activity summary.
- [ ] Complete keyboard, screen-reader, scalable-text, RTL, and narrow/wide-window validation.

## Release definition

The first public release is ready only when at least one complete platform vertical slice can create
a real TUN connection, safely stop it, recover after failure, prevent DNS leaks, and pass the
end-to-end routing suite. UI and config generation alone are not called a VPN release.
