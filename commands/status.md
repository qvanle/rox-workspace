---
description: "Daily check: stale wiki docs, active role brief, running Codex jobs, tasks waiting on you (read-only)"
argument-hint: "[--domain <domain>]"
allowed-tools: Bash, Read
---

Status report. Arguments: `$ARGUMENTS` (default domain `product`). SKILL_DIR is `${CLAUDE_PLUGIN_ROOT}/skills/rox-workspace`. Read-only: move nothing, start nothing, cancel nothing, never wait.

1. `bash "SKILL_DIR/scripts/preflight.sh" all`. A FAIL collapses the dependent sections to one line with the fix; print the rest.
2. In parallel: `roxctl workspace wiki stale` (check `roxctl workspace --help` for the form); `bash "SKILL_DIR/scripts/brief.sh" <active roles> --domain <d>` per active role; Codex job status per repo that has a `.codex-runs/` directory (aos workspace and this plugin repo), via the companion `status`.
3. Print tables in order: Roles (active ids and modes from the conversation, else "none"), Docs (count, top 5 oldest), Brief (per role), Codex jobs (id, repo, model, effort, elapsed, state), Waiting on you (`needs-decision`, `needs-design`, tasks in Review).
4. An empty section is one line ("no stale docs"). End with at most three suggested next commands (for example `/rox-workspace:verify 123`).
