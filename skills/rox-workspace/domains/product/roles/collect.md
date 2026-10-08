# Collect work: read-only gathering goes to jr-se and entry-se

Applies to every role. Reading and collecting information is cheap to parallelise and needs no judgment, so the expensive session
breaks it down, delegates it, and keeps only the synthesis and the decisions. No approved spec and no pma task are needed.

## When to delegate

| Delegate | Keep in the main session |
| --- | --- |
| Searching or reading code, docs, configs, logs, saved reports; listing tasks or docs; running read probes; checking claims one by one | Choosing between options, trade-offs, decisions, anything that depends on the previous answer |
| Each sub-question is independent and answerable from files or read commands | A sub-question that takes under about 3 tool calls (the brief costs more than the work) |

## Break down

Split the request into independent sub-questions. Each has: one question, its scope (paths, commands, repo), the answer form, and a cap
("at most 10 findings"). Group them by executor and, for Codex, by repo.

## Route

| The sub-question needs | Executor |
| --- | --- |
| Files, code, docs or saved reports in one repo; large reads, greps, summaries | `entry-se` (Codex, read-only): `entry-se-run.sh start <repo> <brief> --read-only`. One job per repo: put all of that repo's questions in one brief. Different repos run in parallel |
| `roxctl` reads (pma, wiki, platform, infra), cluster probes, anything Codex's sandbox cannot reach | `jr-se` (Haiku subagent) in collect mode. Several may run in parallel |

## Rules for the executors (both)

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
unavailable, route its questions to `jr-se`; if that fails too, ask the user before reading inline.
