---
id: adr-003
title: Linux Control Process Boundary
created: 2026-07-18
status: accepted
tags: [adr, linux, security]
---

# ADR-003 — Linux Control Process Boundary

## Context

The Flutter foundation defined a MethodChannel contract, but the Linux product also needs a
testable core lifecycle and a privilege design that does not reproduce the legacy scripts'
hard-coded paths and password piping.

## Decision

For the Linux vertical slice, Flutter calls a Go `routerctl` executable through a typed Dart
service. Requests containing profile credentials use standard input. The Go process verifies the
sing-box checksum, generates private runtime configuration, validates it, and supervises sing-box.

The control process remains unprivileged. A separately reviewed installer/service or
capability-limited package will provide the eventual TUN boundary. The unprivileged client will not
be allowed to choose arbitrary privileged executable or configuration paths.

Other platforms retain MethodChannel until their platform-native service or extension adapters are
implemented.

## Consequences

- Linux lifecycle behavior is testable without Flutter native build dependencies.
- Credentials are absent from process arguments and shell history.
- PID reuse and early startup failure are handled centrally.
- Linux cannot claim a real VPN connection until the privilege boundary and network-namespace
  integration test are complete.
- Release packaging must install both `routerctl` and a checksum-verified sing-box core.
