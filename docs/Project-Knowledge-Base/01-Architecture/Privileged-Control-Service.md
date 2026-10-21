---
id: privileged-control-service
title: Linux Privileged Control Service
created: 2026-07-19
updated: 2026-07-21
tags: [architecture, linux, security, systemd]
---

# Linux Privileged Control Service

Home: [[00-Index/Home]]

## Boundary

The Flutter process invokes the unprivileged `routerctl` client. Installed clients require
`/run/adaptive-vpn/control.sock`; they do not fall back to launching the data plane themselves.
The socket is owned by `root:adaptive-vpn` with mode `0660`.

The service accepts only `capability`, `start`, `stop`, `status`, and bounded `probe` requests.
Clients cannot override:

- sing-box executable or checksum;
- runtime, log, state, or learned-route paths;
- SOCKS retry address;
- service command executable.

Messages are JSON, limited to 2 MiB, decoded with unknown-field rejection, and subject to a
30-second connection deadline. The service invokes `routerctl` without a shell and forwards profile
JSON through standard input.

While the tunnel runs, the service tails only new sing-box log data and parses conservative direct
failure candidates. It invokes `probe` without a shell, with a bounded timeout and fixed local SOCKS
address. The mixed inbound is forced to the proxy outbound. Successful evidence updates a `0600`
local rule-set in the fixed runtime directory; clients cannot choose that path. The watcher is
single-worker and per-target rate-limited, preventing unbounded probe creation from log volume.

## systemd sandbox

`packaging/linux/adaptive-vpn.service` runs as `root:adaptive-vpn` with only
`CAP_NET_ADMIN`/`CAP_NET_RAW`. It uses fixed state/runtime directories, `NoNewPrivileges`,
read-only system/home protections, namespace/kernel/control-group restrictions, restricted address
families, a closed device policy, and explicit `/dev/net/tun` access.

`packaging/linux/install.sh` requires an explicit root invocation, verifies the exact sing-box
SHA-256, installs root-owned executables, creates the service group, and optionally adds one named
user. It never reads, receives, or pipes a password. Uninstall preserves private state by default.

## Verification status

- Unix socket request/response and non-socket replacement refusal: automated.
- Privileged option injection rejection: automated.
- Mixed proxy start/status/stop with direct-final routing, forced proxy observer inbound, private
  reloadable learned rule-set, and automatic network scope: passed.
- TUN start reached `TUNSETIFF` and was rejected by this environment, which has no available TUN
  capability. TASK-004 remains open until the same package passes a real namespace/TUN suite.
