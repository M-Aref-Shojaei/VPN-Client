---
id: task-012-report
title: Windows Service Foundation
created: 2026-07-21
tags: [report, windows, service, security]
---

# TASK-012 — Windows Service Foundation

## Problem

The Windows Flutter target was only a scaffold. It had no unprivileged control client, privileged
service, protected sing-box lifecycle, network scope, or recoverable packaging flow.

## Solution

- Added a Windows Flutter process adapter that uses the same credential-safe stdin contract as
  Linux and requires the privileged service.
- Generalized control IPC and added a per-user ACL-protected Windows named pipe.
- Added `AdaptiveVPNService` installation, start, stop, shutdown, recovery, and fixed privileged
  path handling through the Windows Service Control Manager, including named-pipe readiness before
  the service reports `Running`.
- Added protected atomic runtime files, hidden sing-box validation/launch, process creation-time and
  executable identity checks, bounded termination, and stale-state cleanup.
- Added a privacy-preserving Windows network fingerprint based on the best-route interface.
- Serialized lifecycle requests and made failed `start` forwarding fail closed.
- Added checksum-verified versioned install, transactional update, rollback, and uninstall scripts;
  Flutter release bundles include the native binaries and service scripts when explicit verified
  inputs are supplied.
- Added a cleanup-safe Windows device smoke script for TUN start/status/stop and optional two-signal
  blocked-domain learning verification.

## Files changed

- `app/lib/src/services/tunnel_service.dart`
- `app/test/linux_tunnel_service_test.dart`
- `app/windows/CMakeLists.txt`
- `core/controlsocket/*`
- `core/networkscope/scope_windows.go`
- `core/tunnel/manager_windows.go`
- `core/tunnel/manager_windows_test.go`
- `core/cmd/routerctl/control_endpoint_windows.go`
- `core/cmd/routerctl/platform_service_windows.go`
- `core/cmd/routerctl/service.go`
- `core/cmd/routerctl/service_test.go`
- `packaging/windows/*`
- `scripts/build-windows-bundle.ps1`
- `.github/workflows/ci.yml`

## Verification

- `go test ./...`, `go vet ./...`, and `go test -race ./...` pass.
- Windows AMD64 `routerctl` cross-build passes.
- Windows builds of the network-scope, control-socket, and tunnel test packages pass.
- Darwin compilation still passes after the platform split.
- `flutter analyze` and all 20 Flutter tests pass.

This completes the Windows service foundation, not the Windows platform integration gate. TASK-005
remains open until an elevated Windows test device proves service scripts, real TUN create/teardown,
route recovery, and DNS-leak prevention with a signed release artifact.
