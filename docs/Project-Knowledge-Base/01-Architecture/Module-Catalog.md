---
id: module-catalog
title: Module Catalog
created: 2026-07-18
updated: 2026-07-21
tags: [architecture, modules]
---

# Module Catalog

Home: [[00-Index/Home]]

This catalog records every active source module. Detailed behavior belongs in the linked design
notes and task reports.

| Module | Responsibility | Tests / validation |
|---|---|---|
| `app/lib/main.dart` | Select platform tunnel service and start Flutter | Widget suite |
| `app/lib/src/app.dart` | Theme and controller lifetime | Widget suite |
| `app/lib/src/controller/app_controller.dart` | Connection/profile/routing UI state | Widget and service fakes |
| `app/lib/src/models/profile.dart` | Validate imported profile envelope | Dart model tests |
| `app/lib/src/models/profile_link_parser.dart` | Convert eight share-link families to current sing-box structures | Protocol matrix tests + WireGuard sing-box check |
| `app/lib/src/models/routing.dart` | Normalize and preview direct/proxy policy | `routing_test.dart` |
| `app/lib/src/models/rule_set.dart` | Persist trusted signed-rule metadata | Secure snapshot tests |
| `app/lib/src/models/subscription.dart` | Persist validated HTTPS subscription metadata | Secure snapshot tests |
| `app/lib/src/screens/*` | Responsive overview, profiles, and routing UI | `widget_test.dart` |
| `app/lib/src/services/tunnel_service.dart` | MethodChannel contract and Linux/Windows process adapters | `linux_tunnel_service_test.dart` |
| `app/lib/src/services/profile_store.dart` | Versioned OS-secure profile/policy state | `profile_store_test.dart` |
| `app/lib/src/services/subscription_service.dart` | Bounded HTTPS JSON/base64 subscription updates | `subscription_service_test.dart` |
| `app/lib/src/services/rule_set_service.dart` | SHA-256/Ed25519 same-origin rule verification | `rule_set_service_test.dart` |
| `core/router/domain.go` | Domain/IP normalization and private destination detection | Router tests |
| `core/router/engine.go` | Deterministic route precedence | Router tests |
| `core/router/learner.go` | Evidence threshold, expiry, network scope, atomic learned state | Router tests |
| `core/router/singbox.go` | Convert decisions and active learning to inline/live sing-box rules | Router tests + sing-box check |
| `core/router/types.go` | Shared route/evidence data contracts | Compile and consumer tests |
| `core/configbuilder/config.go` | Build validated sing-box DNS/inbound/outbound/route config | Config builder tests |
| `core/observer/observer.go` | Conservative direct/proxy evidence probe and learning | Observer classification/acceptance tests |
| `core/failurewatch/watcher.go` | Parse/rate-limit new direct data-plane failures and trigger verification | Parser, append-only, and debounce tests |
| `core/networkscope/*` | Privacy-preserving current-network scope | Unit tests + cross-platform builds |
| `core/controlsocket/*` | Bounded Unix socket / Windows named-pipe IPC | Unix round-trip/refusal + Windows cross-compile |
| `core/tunnel/manager_linux.go` | Secure Linux data-plane process lifecycle | Lifecycle helper-process tests |
| `core/tunnel/manager_windows.go` | Protected Windows data-plane process lifecycle | Windows helper test compile; device run required |
| `core/tunnel/manager_unsupported.go` | Explicit unsupported-platform behavior | Cross-platform compilation |
| `core/cmd/routerctl/main.go` | Routing/config CLI dispatch | Go tests and manual commands |
| `core/cmd/routerctl/tunnel.go` | Linux control protocol, paths, checksum, runtime config | Go tests + live failure probe |
| `core/cmd/routerctl/probe.go` | Payload-free direct/proxy observation and live rule refresh | Observer/router tests |
| `core/cmd/routerctl/service.go` | Fixed-path daemon, forwarding, and automatic failure watcher | Injection tests + live lifecycle |
| `scripts/codex-cloud-setup.sh` | Reproducible Go/Flutter cloud environment setup | `bash -n`; environment run required |
| `scripts/check-cloud-safety.sh` | Block upload while runtime credentials are tracked | Expected failure on legacy history |
| `scripts/build-libbox-android.sh` | Reproducible official 1.13.14 Android AAR build | Requires Android SDK/NDK and JDK 17 |
| `scripts/build-libbox-apple.sh` | Reproducible official 1.13.14 Apple XCFramework build | Requires macOS/Xcode |
| `packaging/sing-box-linux-amd64.sha256` | Pin reviewed development data-plane artifact | Checked on every capability/start |
| `packaging/linux/*` | Hardened service plus explicit install/uninstall | Shell syntax + live temporary service |
| `packaging/windows/*` | Versioned service lifecycle and cleanup-safe TUN smoke test | Review + Windows device run required |
| `scripts/build-windows-bundle.ps1` | Verify native core and build complete Windows bundle | Windows CI/device required |
| `.github/workflows/ci.yml` | Go, Flutter, Linux, macOS, and Windows verification | Runs after safe publication |

Generated files such as `core/routerctl`, Flutter build output, runtime configs, state, PIDs, and logs
are not modules and remain excluded from Git.
