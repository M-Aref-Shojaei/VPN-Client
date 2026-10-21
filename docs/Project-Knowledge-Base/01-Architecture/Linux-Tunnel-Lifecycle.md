---
id: linux-tunnel-lifecycle
title: Linux Tunnel Lifecycle
created: 2026-07-18
updated: 2026-07-19
tags: [architecture, linux, tunnel, security]
---

# Linux Tunnel Lifecycle

Home: [[00-Index/Home]]

## Flow

```text
Connect button
  → AppController
  → LinuxProcessTunnelService
  → routerctl client (JSON request on stdin)
  → /run/adaptive-vpn/control.sock
  → privileged routerctl service with fixed paths
  → configbuilder.Build
  → private atomic sing-box.json
  → SHA-256 verification
  → sing-box check
  → detached sing-box run
  → startup survival check
  → PID + /proc start-time state
```

Disconnect follows the same boundary in reverse. `routerctl stop` reads the private state, verifies
that the PID still has the recorded Linux process start time and executable path, then sends
`SIGTERM`. It sends `SIGKILL` only if the process remains after the configured timeout.

## Modules and guarantees

### `core/tunnel/manager_linux.go`

- Accepts explicit core, config, state, and log paths.
- Rejects missing and non-executable core files.
- Writes directories as `0700` and runtime files as `0600` using write-sync-rename.
- Executes argument arrays through `os/exec`; no shell or `sudo -S` is used.
- Runs `sing-box check -c` with a 15-second timeout.
- Captures early process exit and a bounded, ANSI-free error.
- Prevents an unrelated/reused PID from being signalled.
- Cleans stale state and makes stop idempotent.

### `core/cmd/routerctl/tunnel.go`

- Limits the standard-input request to 1 MiB and rejects unknown fields.
- Builds the active sing-box configuration from opaque profile outbound plus routing policy.
- Verifies SHA-256 before capability or start.
- Exposes machine-readable `capability`, `start`, `stop`, and `status`.
- Locates development binaries without hard-coded usernames; production packaging should pass
  explicit paths.

### `app/lib/src/services/tunnel_service.dart`

- Selects the Linux process service while retaining MethodChannel for future native platforms.
- Sends the profile JSON over standard input; credentials never enter process arguments.
- Reports a verified running process during app initialization.
- Treats all non-zero control exits as failures.

## Privilege boundary

The manager does not request privilege in the application process. The packaged systemd service
owns the narrow privileged boundary described in [[01-Architecture/Privileged-Control-Service]].
The client cannot choose privileged executable, state, or proxy paths.

The mixed-proxy lifecycle passed through a temporary service. The current workstation reaches the
TUN boundary and receives `TUNSETIFF: operation not permitted`. This is a verified limitation, not
a successful tunnel. TASK-004 stays open until a network-namespace test creates and tears down a
real TUN.

## Tests

- Helper-process lifecycle: validate, start, status, graceful stop.
- Owner-only runtime-file mode.
- Stale/reused PID rejection.
- Flutter capability decoding.
- Credential transport over standard input.
- Error propagation from a failed control process.
- Unix-socket protocol, safe stale-socket behavior, and privileged option-injection rejection.
