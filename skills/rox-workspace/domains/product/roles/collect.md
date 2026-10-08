# Collect work: read-only gathering goes to ba (Codex) and jr-se (roxctl)

Applies to every role. Reading and collecting is cheap to parallelise and needs no judgment, so the expensive session breaks it down,
delegates it, and keeps the synthesis and decisions. `po` and `pm` do this by default: they are the main requesters and `ba` is their assistant (`ba.md`). No approved spec or pma task is needed.

## When to delegate

| Delegate | Keep in the main session |
| --- | --- |
| Searching or reading code, docs, configs, logs, saved reports; listing tasks or docs; running read probes; checking claims one by one | Choosing between options, trade-offs, decisions, anything that depends on the previous answer |
| Each sub-question is independent and answerable from files or read commands | A sub-question that takes under about 3 tool calls (the brief costs more than the work) |

**Break down** into independent sub-questions, each with one question, its scope, the answer form and a cap ("at most 10 findings"); group them by executor and, for Codex, by repo.

## Route

| The sub-question needs | Executor |
| --- | --- |
| Files, code, docs or saved reports in one repo; large reads, greps, summaries | `ba` (Codex, read-only): `entry-se-run.sh start <repo> <brief> --read-only`. One job per repo: put all of that repo's questions in one brief. Different repos run in parallel |
| `roxctl` reads (pma, wiki, platform, infra), cluster probes, anything Codex's sandbox cannot reach | `jr-se` (Haiku subagent) in collect mode, acting as ba's roxctl leg. Several may run in parallel |

## Rules for the executors (ba and its roxctl leg)

- Strictly read-only: no file writes, no git writes, no pma or wiki writes, no mutating command; `roxctl` read tier only.
- Never read `env/` files or sealed-secret values; never print a secret.
- Every finding cites evidence (`file:line` or the exact command); a claim without evidence goes under UNVERIFIED.
- Stop at the cap; say what was not covered.

Return block (the last block of the reply):

```text
RESULT: DONE | PARTIAL | BLOCKED
Q<n>: <sub-question id>
FINDINGS:
| claim | evidence | confidence |
NOT FOUND: <what was searched and not found>
UNVERIFIED: <claims without evidence>
```

## Relay

Fill `templates/collect-brief.md` (one per executor job), launch, wait (Codex: `wait` from inside the repo), read the blocks. Treat them as
unchecked: open one or two cited `file:line` per job before relying on a conclusion. Merge into one answer with sources. If Codex is
unavailable, route its questions to `jr-se` with `FALLBACK: code` in the brief (it then reads the repo read-only); if that fails too, ask the user before reading inline.

## Run mode

A long command whose output needs judging (suite, build, wide log read): write a command file and run it with `entry-se-run.sh run <repo> <file>`
(spec `rox-workspace-run-mode.md`). Codex runs it verbatim into `<repo>/.codex-runs/<job>.log`; `run-lint.sh` refuses mutating commands before launch;
`result --commands <file>` checks the verdict against the exit codes. Never for short commands or anything that changes state.
