---
description: "Run a Claude-written command file through Codex (lint, launch, wait, verify, snapshot check) and report a table"
argument-hint: "<command-file> [--tier light|standard|complex]"
allowed-tools: Bash, Read, AskUserQuestion
---

Run mode. Arguments: `$ARGUMENTS`. SKILL_DIR is `${CLAUDE_PLUGIN_ROOT}/skills/rox-workspace`. Format: `SKILL_DIR/domains/product/templates/run-brief.md`.

1. **File** required; ask if missing. Run it from the repo the file targets.
2. **Lint** `bash "SKILL_DIR/scripts/run-lint.sh" <file>`. Any violation: print it and stop; fix the file, never bypass. If the file writes (fixtures, builds) and the active role is not `sr-se`, `sa`, `qa` or `qc`, warn and ask.
3. **Launch** `bash "SKILL_DIR/scripts/entry-se-run.sh" --tier T run <repo> <file>`. Busy repo: stop with the message. Codex unavailable: say delegation was skipped and run the commands inline.
4. **Wait** `entry-se-run.sh wait <job>`.
5. **Verify** `entry-se-run.sh result <job> --commands <file>`. A `FAIL violation: changed outside .codex-runs/` is reported as a failure.
6. **Report** a table: command, exit code, one-line outcome; then DONE, PARTIAL or BLOCKED and the `.codex-runs/<job>.log` path. A failing command is reported, never repaired.
