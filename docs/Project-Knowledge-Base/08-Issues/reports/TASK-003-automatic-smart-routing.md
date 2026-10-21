---
id: task-003-report
title: Automatic Smart Routing
created: 2026-07-21
tags: [report, routing, linux, sing-box]
---

# TASK-003 — Automatic Smart Routing

## Problem

The routing engine and payload-free observer were implemented, but Linux learned only from a manual
UI probe. Accepted entries were persisted yet could not change a running sing-box route table. The
SOCKS retry also entered the same direct-by-default mixed inbound, so it was not guaranteed to test
the actual proxy outbound.

## Solution

- Forced the loopback mixed observer inbound to the `proxy` outbound while leaving TUN traffic
  direct by default.
- Added a conservative append-only sing-box failure watcher. It accepts only domain failures from
  `outbound/direct[direct]`, rejects malformed/IP targets, rate-limits candidates, and never treats
  log text as evidence by itself.
- Connected candidates to the existing direct/TLS probe and verified proxy retry. Two safe
  observations are still required and original application payload is never replayed.
- Added a private atomic sing-box local source rule-set containing active learned domains for the
  current network. sing-box automatically reloads it while running.
- Added a privacy-preserving Linux network fingerprint derived from hashed default-route material;
  raw interface and hardware identifiers are not persisted.

## Files changed

- `core/failurewatch/watcher.go`
- `core/failurewatch/watcher_test.go`
- `core/networkscope/scope.go`
- `core/networkscope/scope_linux.go`
- `core/networkscope/scope_other.go`
- `core/networkscope/scope_test.go`
- `core/router/singbox.go`
- `core/router/engine_test.go`
- `core/configbuilder/config.go`
- `core/configbuilder/config_test.go`
- `core/cmd/routerctl/tunnel.go`
- `core/cmd/routerctl/probe.go`
- `core/cmd/routerctl/service.go`

## Verification

- `go test ./...` passes.
- `go vet ./...` passes.
- `go test -race ./...` passes outside the restricted sandbox required by the Unix-socket test.
- Windows AMD64 and Darwin ARM64 `routerctl` cross-builds pass.
- A live unprivileged sing-box lifecycle starts and remains healthy with `route.final=direct`, a
  forced-proxy mixed inbound, and a `0600` reloadable local learned rule-set.
- A Smart TUN launch passes configuration validation and reaches `TUNSETIFF`; the host denies the
  required capability, and status confirms there is no running process or stale state afterward.

TASK-004 remains open for service installation and a real TUN/network-namespace suite on a capable
Linux host.
