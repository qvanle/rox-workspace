---
description: "Build a pma task on the right executor (sr-se inline, jr-se Haiku subagent, entry-se Codex job) and move it to Review"
argument-hint: "<task-id> [--exec sr|jr|entry] [--tier light|standard|complex]"
allowed-tools: Bash, Read, AskUserQuestion, Agent, SendMessage
---

Build a task. Arguments: `$ARGUMENTS`. SKILL_DIR is `${CLAUDE_PLUGIN_ROOT}/skills/rox-workspace`. Read `SKILL_DIR/domains/product/roles/_common.md` (relay mode, briefs) and the executor table in `SKILL_DIR/domains/product/roles/se.md` first. Never commit or move the task to Done.

1. **Task id.** Required; ask if missing. Roles are advisory: if `qc` or `qa` is active, warn and ask.
2. **Preflight.** `bash "SKILL_DIR/scripts/preflight.sh" pma` (use `all` when the executor will be `entry`). On FAIL print it and stop.
3. **Read.** `roxctl workspace pma show <id>` (check `roxctl workspace --help` for the exact form): requirement, labels, bucket, project. Find the spec: the `docs/specs/*.md` of the repo whose `Requirement:` line names the task. No spec: tell the user `sr-se` must specify it first, stop.
4. **Gate.** Spec has `Status: approved`, `Test plan: reviewed`; task is in `To do` or `Specifying`; for `jr`/`entry` no `needs-decision`, `needs-design`, `blocked`. Missing: say what, stop. A task already in `Implementing`: report it (and any live job), stop.
5. **Choose.** Use an existing `exec:*` label, else the table: no approved spec, security/breaking/secrets/auth, `area:infra`, multi-repo or size L/XL -> `sr`; needs roxctl or pma/wiki writes by the executor -> `jr`; precise self-contained code -> `entry`. `--exec` wins, with a warning if it contradicts. State choice and reason in one line.
6. **Move** the task to `Implementing` (look up the bucket id with `bucket ls`).
7. **Brief and dispatch.** `jr`: Task brief per `_common.md`, `Agent` with `subagent_type: "rox-workspace:jr-se"`. `entry`: fill `SKILL_DIR/domains/product/templates/entry-se-brief.md` into a scratch file under `$CLAUDE_JOB_DIR/tmp` or the scratchpad, then from inside the repo `scripts/entry-se-run.sh [--tier T] start <repo> <brief>`, `wait <job>`, `result <job>`. Codex unavailable: stop, never build inline. `sr`: implement yourself from the spec.
8. **Relay.** `NEEDS-INPUT`: ask the user, `SendMessage` (jr) or `entry-se-run.sh resume` (entry). A second `NEEDS-INPUT` escalates to `exec:sr`; say so. `BLOCKED`: report, stop.
9. **Check.** Treat `DONE` as unchecked: `git diff --stat`, re-run the TESTS commands once. Mismatch: send back once with the output, then tell the user.
10. **Finish.** Tests pass: move to `Review`, show the summary. Never move to Done, never commit.
