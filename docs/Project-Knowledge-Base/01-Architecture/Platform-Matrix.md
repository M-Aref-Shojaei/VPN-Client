---
id: platform-matrix
title: Platform Matrix
created: 2026-07-18
updated: 2026-07-21
tags: [architecture, platforms]
---

# Platform Matrix

| Platform | UI project | Required tunnel boundary | Current status |
|---|---:|---|---|
| Android | ✅ | `VpnService`, foreground service, protected core sockets | API 23 + pinned libbox build; adapter open |
| iOS | ✅ | Packet Tunnel Network Extension and app group | Scaffold only |
| Windows | ✅ | Privileged service plus signed TUN driver | Service/Flutter adapter implemented; live TUN gate open |
| macOS | ✅ | Packet Tunnel Network Extension | Scaffold only |
| Linux | ✅ | Hardened systemd service plus TUN | Smart TUN/service implemented; privileged host integration test open |

Flutter shares product/UI logic. Tunnel lifecycle cannot be safely generalized into Dart because
permissions, background execution, driver installation, DNS setup, and socket protection are native
platform responsibilities.

Android and Apple implementations will expose the same MethodChannel:

```text
channel: dev.adaptivevpn/tunnel
methods:
  capability -> {available: bool, message: string}
  connect    -> profile + policy
  disconnect
```

The channel must report unavailable until that platform implementation can create and cleanly tear
down a real tunnel. A missing plugin is a supported development state, not a connected state.

Linux currently implements the `TunnelService` contract through a typed `routerctl` process
adapter. It reports lifecycle capability separately from the result of a privileged TUN launch;
startup failure must never transition the controller to connected.

Windows uses the same typed process contract. `routerctl.exe` forwards to a per-user named pipe and
a LocalSystem service. The adapter remains unavailable when the service or verified core is absent,
and the platform is not release-ready until the real-device TUN and DNS gates pass.
