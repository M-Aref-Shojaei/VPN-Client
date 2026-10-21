# Adaptive VPN Client

Cross-platform proxy client focused on adaptive, direct-by-default routing. Known or learned blocked
domains use the encrypted proxy tunnel; other traffic uses the normal network path.

The repository is being migrated from a v2rayN runtime snapshot into a product codebase:

- `app/` — Flutter user interface for Android, iOS, Windows, macOS, and Linux.
- `core/` — Go routing, learning, profile validation, and sing-box configuration generation.
- `packaging/` — reviewed runtime checksums and future release packaging metadata.
- `scripts/` — reproducible Codex Cloud setup and repository safety checks.
- `binConfigs/` and `guiConfigs/` — legacy runtime reference files; not application source.
- `docs/Project-Knowledge-Base/` — architecture, decisions, roadmap, issue registry, and reports.

## Core quick start

```bash
cd core
go test ./...
go run ./cmd/routerctl decide \
  -domain example.com \
  -network home \
  -policy policy.example.json
go run ./cmd/routerctl build \
  -profile profile.example.json \
  -policy policy.example.json
```

The example profile contains only reserved placeholder values. Real profile credentials belong in
the operating system's application-data directory and must never be committed.

## Linux development adapter

Build the control process, then run the Flutter app from `app/`:

```bash
make core-build
cd app
flutter run -d linux
```

On Linux, Flutter invokes `routerctl` directly with an argument array. Profile credentials are sent
over standard input, not command-line arguments. Installed clients forward lifecycle requests over
a group-restricted Unix socket to the hardened systemd service. The service verifies sing-box,
writes `0600` runtime state, validates configuration, and supervises the detached core.

The service installer is explicit and never handles a password:

```bash
make core-build
sudo packaging/linux/install.sh --user "$USER"
```

Review the installer and service first. Sign out and back in after group membership changes. This
workstation cannot run the real TUN test because its execution environment has no usable
`/dev/net/tun`/`CAP_NET_ADMIN`.

Profiles can be imported as JSON or VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC, WireGuard,
and SSH links. Profiles, subscriptions, policy, and rule trust metadata use OS secure storage.

## Windows development adapter

On Windows, build a release bundle with an explicitly supplied sing-box executable and SHA-256:

```powershell
.\scripts\build-windows-bundle.ps1 `
  -SingBoxPath C:\verified\sing-box.exe `
  -SingBoxSha256 <64-character-sha256>
```

From an explicitly elevated PowerShell window, run `install-service.ps1`. Later bundles use
`update-service.ps1`; `rollback-service.ps1` restores the preceding immutable native version. The
Flutter application itself stays unprivileged and talks to `AdaptiveVPNService` through a
per-installing-user named pipe. This code is cross-compiled and unit-tested, but a Windows device
must still pass real TUN create/teardown, multi-interface, and DNS-leak tests before release.

After installing the service, run the cleanup-safe device smoke test with a copied test profile:

```powershell
.\test-tunnel.ps1 -ProfilePath C:\test\profile.json
```

Add `-BlockedDomain blocked.example` only for a hostname that is genuinely blocked on that test
network and reachable through the configured proxy. The script always attempts to stop the tunnel.

## Codex remote work

Run `make cloud-safety` before creating any GitHub remote. The check currently blocks this legacy
repository because three credential-shaped runtime files are tracked in its history. Do not upload
the repository until those files are migrated and a clean history is created.

See the [Codex remote workflow](docs/Project-Knowledge-Base/06-Infrastructure/Codex-Remote-Workflow.md)
for mobile-host support and Codex Cloud setup.

## Safety model

Adaptive learning accepts a block classification only when a direct connection fails with a strong
network-level signal and a proxy retry succeeds before application payload is forwarded. Decisions
are isolated by network fingerprint and expire automatically.

See the [knowledge-base home](docs/Project-Knowledge-Base/00-Index/Home.md) for the full design and
current delivery status.
