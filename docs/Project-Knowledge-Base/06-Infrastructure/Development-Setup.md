---
id: development-setup
title: Development Setup
created: 2026-07-18
tags: [infrastructure, development]
---

# Development Setup

## Required tools

- Go 1.26 or compatible version declared by `core/go.mod`.
- Flutter 3.44 / Dart 3.12 or compatible version declared by `app/pubspec.yaml`.
- sing-box 1.13.14 for current configuration compatibility validation.
- Platform-specific Android, Xcode, Windows, or Linux desktop toolchains.

## Commands

```bash
make core-test
make core-vet
make core-build
make app-analyze
make app-test
make check
make cloud-safety
```

Generate and validate an example:

```bash
cd core
go run ./cmd/routerctl build \
  -profile profile.example.json \
  -policy policy.example.json > /tmp/adaptive-vpn-config.json
../bin/sing_box/sing-box check -c /tmp/adaptive-vpn-config.json
```

## Local environment note

During initial setup on 2026-07-18, the primary Flutter artifact endpoint returned HTTP 403. The
Flutter storage/pub mirror was used for SDK bootstrap. The project source does not hard-code a
mirror; CI must pin and verify its own trusted download source.

The current workstation lacks the Android SDK and Linux `clang`/CMake/Ninja/GTK3 development
packages. Flutter analysis/tests run, but native Linux/Android artifacts cannot be compiled until
those system toolchains are installed. macOS and Windows builds require their respective hosts.

## Linux process adapter

`make core-build` creates ignored `core/routerctl`. When the Flutter process starts from `app/`, it
discovers `../core/routerctl`; installed packages should place it beside the application or set
`ADAPTIVE_VPN_ROUTERCTL`. `routerctl` discovers the development sing-box core and checksum from the
repository. Production packages must provide reviewed explicit locations.

Build `core/routerctl` before reviewing the privileged package:

```bash
make core-build
bash -n packaging/linux/install.sh packaging/linux/uninstall.sh
sudo packaging/linux/install.sh --user "$USER"
```

Installation is intentionally not performed by tests or the Flutter application. Review
`packaging/linux/adaptive-vpn.service` first. The live unprivileged service protocol passed
mixed-proxy start/status/stop. The current execution environment has no usable `/dev/net/tun` or
`CAP_NET_ADMIN`; TUN startup is rejected at `TUNSETIFF` and leaves no running state.

## Mobile core builds

`scripts/build-libbox-android.sh` pins sing-box 1.13.14 and the official SagerNet gomobile fork. It
requires Android SDK/NDK and OpenJDK 17. `scripts/build-libbox-apple.sh` requires macOS and Xcode.
Generated AAR/XCFramework files are ignored; release CI must checksum/sign artifacts rather than
commit binaries.

## Codex environment

Use `scripts/codex-cloud-setup.sh` as a Codex Cloud setup command only after `make cloud-safety`
passes. See [[06-Infrastructure/Codex-Remote-Workflow]].
