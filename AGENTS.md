See project knowledge base: docs/Project-Knowledge-Base/00-Index/Home.md

This file mirrors CLAUDE.md for any agent that reads AGENTS.md instead (e.g. Codex CLI).

## When done — write a report

Before writing the report, review the actual code diff for this task (not the original plan) and
update `01-Architecture/System-Overview.md` and `00-Index/Project-Roadmap.md` so they match what was
actually implemented.

For each completed task, create a report file at
`docs/Project-Knowledge-Base/08-Issues/reports/<ID>-<short-name>.md` summarizing what was done
(problem, solution, files changed), and link it from the Report column in
`docs/Project-Knowledge-Base/08-Issues/Bug-Registry.md`. Then move the completed row to the bottom
of the table in Bug-Registry.md, so open and in-progress tasks stay visible at the top.

## When asked to "push"

Do NOT run `git push` immediately. This repo has no commits yet and no `.env`-style secret
separation — before every commit, run `git diff --staged` and check for `uuid`, `password`,
`server`, `vless://`, `vmess://`, `trojan://`, `ss://` in `binConfigs/config.json`,
`binConfigs/configPre.json`, and `guiConfigs/guiNConfig.json`. Then complete every gate:

1. **Task complete** — feature/fix fully implemented, no TODOs left in code
2. **No secrets committed** — see check above
3. **No bugs introduced** — read the diff, pay special attention to `binConfigs/*.sh` (run with sudo)
4. **Docs updated** — System-Overview / Project-Roadmap reflect the changes
5. **Task closed** — marked done in Bug Registry
6. **Commit message** — follows Conventional Commits: `<type>(<scope>): <summary>`

Only after all gates are green: `git add`, `git commit`, `git push`.

Full checklist: `docs/Project-Knowledge-Base/02-Governance/Push-Checklist.md`
