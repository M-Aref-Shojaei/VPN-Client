---
id: system-overview
title: System Architecture Overview
created: 2026-07-07
updated: 2026-07-21
tags: [architecture]
---

# System Architecture Overview

Home: [[00-Index/Home]]

Hiddify App is an architectural and UX reference, not a source dependency. The clean-room boundary
and current upstream findings are recorded in [[01-Architecture/Hiddify-Reference-Baseline]] and
[[07-Decisions/ADR-006-Hiddify-Reference-Strategy]].

## Target shape

```text
Flutter application
  ├─ connection status and controls
  ├─ profile import/selection
  ├─ routing inspector and overrides
  └─ TunnelService contract
             │
             ▼
Native platform tunnel adapter
  ├─ Android VpnService
  ├─ Apple Network Extension
  ├─ Windows TUN integration
  └─ Linux routerctl process adapter
             │
             ▼
Go control and routing core
  ├─ profile validation
  ├─ routing policy evaluation
  ├─ network-specific learning
  ├─ atomic learned-state persistence
  └─ sing-box configuration generation
             │
             ▼
sing-box data plane
  ├─ TUN and local mixed inbounds
  ├─ proxy outbound from the active profile
  ├─ direct outbound
  └─ DNS interception and explicit resolution
```

## Implemented modules

### Flutter application (`app/`)

- Material 3 responsive navigation switches between bottom navigation and a desktop navigation
  rail.
- Connection page exposes actual adapter capability and cannot connect when no adapter is present.
- Routing page normalizes domains, previews decisions, and edits manual direct/proxy overrides.
- Profiles page imports the same `{id, name, outbound}` JSON shape used by the Go config builder.
- `TunnelService` defines the platform boundary; `MethodChannelTunnelService` uses
  `dev.adaptivevpn/tunnel`.
- `LinuxProcessTunnelService` and `WindowsProcessTunnelService` invoke `routerctl` without a shell, pass credentials only on
  standard input, restores live running state during initialization, and converts non-zero exits
  into user-visible failures.
- `SecureProfileStore` persists versioned profiles, routing policy, HTTPS subscriptions, and
  trusted rule-set metadata through platform secure storage with a 1 MiB schema boundary.
- `ProfileLinkParser` converts eight common share-link families into current sing-box structures;
  WireGuard is emitted as an endpoint, not the removed legacy outbound.
- `SubscriptionService` accepts HTTPS-only, credential-free URLs and enforces redirect, response,
  size, profile-count, and schema bounds.
- `RuleSetService` requires same-origin payloads, SHA-256, an increasing version, and an Ed25519
  signature before replacing known-blocked domains.

### Go core (`core/`)

- `router.Engine` applies deterministic precedence and always finishes with direct.
- `router.Learner` accepts only strong failure signals with verified proxy success before
  application payload forwarding.
- Learned entries are scoped to a network, expire, can be pruned, and are saved using a
  write-sync-rename sequence with `0600` file permissions.
- `configbuilder.Build` validates an opaque sing-box proxy outbound and generates TUN, mixed proxy,
  DNS, direct outbound, and route configuration.
- `routerctl` offers `decide`, `learn`, `export`, and `build` commands for testing and platform
  integration, plus `capability`, `start`, `stop`, and `status` for Linux and Windows lifecycle control.
- `tunnel.Manager` validates configuration before launch, keeps runtime/config/log/state private,
  confirms the child survives startup, binds state to both `/proc` start time and executable path,
  sends `SIGTERM`, and uses `SIGKILL` only after a bounded timeout.
- The Linux AMD64 development core is accepted only when it matches
  `packaging/sing-box-linux-amd64.sha256`.
- `observer.Observer` performs a payload-free direct TCP/TLS probe and retries through the local
  SOCKS endpoint only after timeout, DNS-not-found, reset, or narrow TLS interference signals. The
  mixed observer inbound is explicitly forced to `proxy`; it cannot fall back into the default
  direct route.
- `failurewatch.Watcher` tails only newly appended bounded log lines, accepts only domain failures
  from `outbound/direct[direct]`, rate-limits triggers, and asks the observer to independently verify
  both paths. Log text alone never becomes learning evidence.
- `networkscope.Resolve` derives a truncated SHA-256 Linux or Windows network fingerprint from the default
  route/interface without storing the raw interface or hardware address.
- Active learned domains are written as a private atomic sing-box local source rule-set. sing-box
  watches that file and applies accepted learning without a tunnel restart.
- `controlsocket.Server` exposes only bounded lifecycle requests over a mode `0660` Unix socket or
  per-user ACL-protected Windows named pipe. The service canonicalizes client probe options,
  serializes lifecycle operations, and owns all privileged binary/state paths.
- `AdaptiveVPNService` runs the verified sing-box data plane as LocalSystem while Flutter remains
  unprivileged. Protected runtime ACLs, Windows process identity checks, and transactional
  install/update/rollback scripts complete the service foundation.

## Legacy layer

The original repository contained v2rayN runtime output rather than application source:

- `binConfigs/config.json` is Xray format.
- `binConfigs/configPre.json` is sing-box format.
- `guiConfigs/guiNConfig.json` is v2rayN state.
- Shell scripts apply Linux desktop proxy settings and start/stop a locally installed binary.

These files remain reference material. New code must not write into them or treat them as the
product's persistence format.

## Trust boundaries

1. Flutter receives user profile data and passes it to the adapter only on connection. Linux uses
   standard input, so credentials do not appear in process arguments.
2. Desktop app clients have no privilege. The Linux root service runs with only
   `CAP_NET_ADMIN`/`CAP_NET_RAW`, fixed installed paths, `/dev/net/tun` access, system protection,
   and group-restricted IPC. Windows uses a LocalSystem service and an installing-user pipe ACL.
   Neither app handles an administrator or sudo password.
3. The Go core generates the runtime configuration; sing-box owns packet transport.
4. Credentials and learned history stay local. Neither is a telemetry source.
5. Runtime configuration and state are excluded from Git.

## Not yet implemented

- Installation and a real TUN integration test on a capable Linux host.
- Native `dev.adaptivevpn/tunnel` handlers for Android and Apple.
- Windows device validation for the service scripts, signed TUN-driver lifecycle, route cleanup,
  multi-interface behavior, and DNS leak prevention.
- Product-level selection between Smart TUN, full TUN, and local-proxy modes.
- Exact design changes requested by the product owner; visual references are still required.
- Release signing, store metadata, and packaged core artifacts.

These are tracked in [[08-Issues/Bug-Registry]] and must not be represented as shipped features.
