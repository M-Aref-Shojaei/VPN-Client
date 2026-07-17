---
id: push-checklist
title: Push Checklist
created: 2026-07-07
tags: [governance, git, push, checklist, quality-gate]
---

# Push Checklist

Related: [[02-Governance/Coding-Standards]]

---

## What "push" means

When asked to **push**, do not run `git push` immediately. First complete every gate below.
Only push when all gates are green.

---

## Gates (in order)

### 1. Task complete
- The feature/fix is fully implemented — no partial work, no TODOs left.
- The item is marked ✅ Solved in `[[08-Issues/Bug-Registry]]`.

### 2. No secrets committed
- `binConfigs/config.json`, `configPre.json`, and `guiConfigs/guiNConfig.json` contain no real
  server credentials (uuid, password, subscription URL) before staging — check `git diff --staged`
  for `uuid`, `password`, `server`, `vless://`, `vmess://`, `trojan://`, `ss://` before every commit.
  This repo has no `.env`-style secret separation yet, so this check is manual.

### 3. No bugs introduced
- Read through the diff and confirm no obvious logic errors, especially in the shell scripts
  (`binConfigs/*.sh` run with sudo — a bug there has real system impact).

### 4. Docs updated
- `01-Architecture/System-Overview.md` and `00-Index/Project-Roadmap.md` reflect what changed.

### 5. Commit message follows Conventional Commits
```
<type>(<scope>): <short summary>
```
Example: `feat(router): add smart routing rules to configPre.json`

---

## Then push
```bash
git add <files>
git commit -m "<message>"
git push
```
