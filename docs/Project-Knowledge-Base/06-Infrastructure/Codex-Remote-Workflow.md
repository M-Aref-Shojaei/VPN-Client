---
id: codex-remote-workflow
title: Codex Remote Workflow
created: 2026-07-18
updated: 2026-07-18
tags: [infrastructure, codex, remote, mobile]
---

# Codex Remote Workflow

Home: [[00-Index/Home]]

## Phone control

OpenAI introduced Codex remote access in preview through the ChatGPT mobile application. Supported
desktop Codex tasks appear in the mobile app's **Remote** tab, where the user can continue threads,
approve actions, review diffs/tests, and steer work.

As of 2026-07-18, OpenAI's availability note requires the Codex app on a **macOS host** and says
Windows host support is coming. This repository is currently open on a Linux host, so this exact
local session cannot be paired directly with the mobile Remote tab.

Official references:

- [Work with Codex from anywhere](https://openai.com/index/work-with-codex-from-anywhere/)
- [ChatGPT Work and Codex](https://help.openai.com/en/articles/20001275)

## Available Linux alternative: Codex Cloud

Codex Cloud can work from a GitHub repository in an isolated environment:

1. Remove runtime credentials from the repository and its history.
2. Run `make cloud-safety`; it must succeed.
3. Create a private GitHub repository and push the reviewed branch.
4. In Codex Cloud, connect GitHub, authorize only that repository, and create an environment.
5. Configure `scripts/codex-cloud-setup.sh` as the environment setup command.
6. Start or steer cloud tasks from a supported Codex surface and review the returned diff or PR.

Official references:

- [Codex Cloud](https://developers.openai.com/codex/cloud)
- [Cloud environments](https://developers.openai.com/codex/cloud/environments)

Cloud tasks see the selected Git commit, not uncommitted files on this workstation.

## Current upload blocker

`scripts/check-cloud-safety.sh` currently fails because these legacy runtime files are tracked:

- `binConfigs/config.json`
- `binConfigs/configPre.json`
- `guiConfigs/guiNConfig.json`

They contain credential-shaped configuration fields. Ignoring them now is insufficient because
they already exist in Git history. Before any remote is added, preserve required user data outside
the repository, replace the tracked files with safe examples, and create a clean history. History
rewrite or repository replacement is intentionally not performed without explicit approval.

## Environment behavior

The setup script pins Flutter 3.44.5 by default, uses the official Flutter storage endpoint unless
the environment provides a trusted mirror, downloads dependencies during setup, and leaves
credentials out of the repository. Codex secrets should be limited to setup-only needs; VPN
profile credentials are not required for analysis or unit tests and must not be configured.
