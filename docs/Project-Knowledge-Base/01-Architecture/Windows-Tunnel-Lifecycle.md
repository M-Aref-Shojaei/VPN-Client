---
id: windows-tunnel-lifecycle
title: Windows Tunnel Lifecycle
created: 2026-07-21
updated: 2026-07-21
tags: [architecture, windows, service, tun]
---

# Windows Tunnel Lifecycle

Home: [[00-Index/Home]]

## Boundary

The Flutter application runs without elevation and invokes its bundled `routerctl.exe`. Lifecycle
requests are forwarded to `AdaptiveVPNService` over `\\.\pipe\adaptive-vpn-control`. The named
pipe ACL grants full control to LocalSystem and Administrators and read/write access only to the
Windows user who explicitly installed the service. A client cannot override the installed core,
checksum, runtime directory, learned-rule path, or observer endpoint.

The service runs as LocalSystem because creating a system TUN interface and routes is a machine
operation. It depends on `Tcpip`, uses an unrestricted service SID, starts automatically, and has
bounded restart recovery. It reports `Running` to the Service Control Manager only after a
self-capability request succeeds through the named pipe. Flutter never runs as Administrator and
never receives an elevation or account password.

## Data-plane lifecycle

The service verifies the pinned SHA-256 of `sing-box.exe` before installation and every service
start. Runtime configuration, learned rules, logs, and PID identity state are written under a
protected ProgramData directory whose DACL permits only LocalSystem and Administrators.

Before launch, `sing-box check` validates the generated Smart TUN configuration. The Windows
manager starts sing-box without a console, confirms it survives the startup window, and records
the PID, executable path, and Windows process creation time. Status and stop require all identity
fields to match, preventing a recycled PID from being terminated. Stop uses a bounded process wait
and removes stale state.

Lifecycle commands are serialized in the service. Smart-routing probes can run independently, but
they receive only canonical, bounded options. A `start` request is fail-closed if the service pipe
is unavailable because its credential-bearing standard input cannot safely be replayed.

## Installation and upgrades

Release bundles contain explicit elevated PowerShell scripts. They copy verified native binaries
into content-addressed version directories under Program Files and keep a non-secret installation
manifest under ProgramData. Updates install a new immutable version, remove the old service, start
the new service, and restore the previous service if any step fails. Rollback performs the inverse
transaction. Uninstall removes the service but deliberately preserves private runtime state and
rollback binaries.

`test-tunnel.ps1` accepts a profile JSON file through PowerShell memory/stdin, starts Smart TUN,
requires a running status, optionally probes a genuinely blocked domain twice to verify the
evidence threshold, and stops the tunnel in `finally`. The profile is never placed in process
arguments. DNS-leak and multi-interface checks remain separate because they need controlled test
networks and an external resolver observer.

## Verification status

- Go Windows AMD64 compilation: passed.
- Windows-specific package test compilation: passed.
- Shared Go unit, vet, and race suites: passed on Linux.
- Flutter Windows process-adapter contract: passed.
- Service install/update/rollback script execution: requires Windows Administrator test host.
- Real TUN create/route/DNS/teardown: requires the separate Windows test device and remains open.

The platform is not considered solved until a signed Windows bundle creates and tears down a real
TUN and passes DNS-leak and multi-interface tests.
