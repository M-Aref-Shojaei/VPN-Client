---
id: task-009-report
title: Codex Cloud Setup and Safety Preflight
created: 2026-07-18
tags: [report, infrastructure, security]
---

# TASK-009 — Codex Cloud Setup and Safety Preflight

## Problem

The project needs remote Codex work, but the local Linux session cannot currently pair with the
ChatGPT mobile Remote preview and the legacy Git history includes credential-shaped runtime files.
Uploading the repository without a guard would risk disclosing VPN credentials.

## Solution

- Added a reproducible Codex Cloud environment setup script for Go and pinned Flutter tooling.
- Added a tracked-content safety gate that blocks known runtime configuration paths and scans for
  proxy-link/private credential patterns.
- Documented the current macOS-host mobile limitation and the GitHub/Codex Cloud alternative.
- Recorded that Git ignores cannot remove secrets already present in history and that history
  cleanup requires explicit approval.

## Files

- `scripts/codex-cloud-setup.sh`
- `scripts/check-cloud-safety.sh`
- `Makefile`
- `README.md`
- `docs/Project-Knowledge-Base/06-Infrastructure/Codex-Remote-Workflow.md`

## Verification

- `bash -n` validates both scripts.
- `make cloud-safety` fails as designed and names only the three unsafe tracked paths; it never
  prints credential values.

The setup and safety tooling is complete. Connecting or pushing a repository remains blocked until
the user authorizes credential migration and clean-history creation.
