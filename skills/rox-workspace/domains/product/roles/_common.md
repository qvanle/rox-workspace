# Roles: common rules

Applies to every active role. A role is a human team role; the agent adopts its persona and watches its gates. Roles are advisory.

## Active set

- Several roles may be active; the union of their Owns, Does and Brief applies.
- A Hands-off entry is dropped when its target role is also active.
- `sr-se` with `jr-se` or `entry-se`: keep `sr-se`, drop the other, say so. `jr-se` with `entry-se` is allowed (two executors).
- Personas merge; where they pull apart, the role that owns the artefact being worked on wins.
- With `jr-se` or `entry-se` active, engineering work goes to the Haiku subagent `rox-workspace:jr-se` or the Codex job (relay below); other roles stay inline.

## Warn and ask

Before an action whose owner (see `README.md` gates and the role's Hands off) is not in the active set, stop and ask in one line:

> That is `<owner>`'s call (<action>). Continue as `<active>` anyway? [yes / no / hand off]

- yes: do that one action only. no: do nothing. hand off: propose a label (`needs-decision`, `needs-design`, ...) or a new task for the owner and create it on confirmation. Never edit an existing task's note.
- Reading (search, get, list, show) is never out of role. The skill's own confirmations (delete, bulk move) still apply.
- Separation of duties: warn once per task when the active set both implements and verifies it, or both drafts and ratifies a vision, strategy or tactic.

## Relay mode (jr-se and entry-se)

The main session does not read or write code while `jr-se` or `entry-se` is active. For a task: `pma show <id>`; read the spec's `Status:` line; if it is not
`approved`, say the spec needs `sr-se` approval and stop. Otherwise dispatch `Agent` with `subagent_type: "rox-workspace:jr-se"` and a self-contained
brief (repo path, task id, spec path, domain, the user's words). One agent per task; keep the agent id with the task id.

The agent ends with a block: `RESULT: DONE | NEEDS-INPUT | BLOCKED`, `TASK`, then `CHANGED` and `TESTS` (DONE), `QUESTION` (NEEDS-INPUT) or `REASON` (BLOCKED).
On NEEDS-INPUT ask the user (`AskUserQuestion`), then continue the same agent with `SendMessage`. On DONE show the summary and `git diff --stat`.

**entry-se (Codex).** Same gates and return block, different executor. Move the task to `Implementing` yourself, fill `templates/entry-se-brief.md` into a scratchpad file, run
`bash <skill base dir>/scripts/entry-se-run.sh start <repo> <brief>`, then `wait <job-id>` (a script loop, no tokens) and `result <job-id>`, both from inside the repo (`cd <repo> && bash ... wait <id>`): Codex job state is per repo. Codex only writes under the repo it is launched from,
has no `roxctl`, and has no memory of this session. On NEEDS-INPUT ask the user and `resume <repo> <answer-file>`. Treat DONE as unchecked: `git diff --stat`, re-run the TESTS commands once,
then move the task to `Review` yourself. One job per repo. If Codex is unavailable, say so and stop; never do the work yourself.

## Collect work, brief and card

Read-only gathering is delegated to `jr-se` and `entry-se`: see `collect.md`. `bash <skill base dir>/scripts/brief.sh <ids> --domain <domain>` prints the starting view; the card is Active, Owns, Hands off, Brief tables, Next.
