# Entry.SE brief — one approved task

## 1. Context (relay fills every placeholder)

| Field | Value |
| --- | --- |
| Repo / only writable working tree | <absolute repo path> |
| Task | <project> #<task id> |
| Domain | product |
| Approved spec (read-only) | <absolute spec path> |
| Role (read-only) | <absolute plugin path>/skills/rox-workspace/domains/product/roles/se.md — tier entry |
| Common rules (read-only) | <absolute plugin path>/skills/rox-workspace/domains/product/roles/_common.md |

Requirement text from `pma show` (no session context is otherwise available):

<requirement text, including all R-ids and the user's task-specific instructions>

## 2. Tier entry (from se.md; relay includes any task-specific limits)

Read the role, common rules and the complete spec before editing. Require `Status: approved ...`;
otherwise return BLOCKED. Make the smallest change that meets every R-id and run the named tests.
<tier rules and scope limits from se.md, tier entry, for this task>

- Edit only the given repo's working tree; run tests and linters. Specs and role files are read-only.
- Never commit, push, switch branches, ship, seal, scaffold services or touch another repo.
- No `roxctl`, `ol`, `vja`, pma or wiki access. The relay performs progress writes and any approved wiki proposal.
- Never edit a spec, task note or title; never delete or move a task to Done. Never print secrets.
- NEEDS-INPUT: two reasonable ways left open, a named test cannot be written as named,
  an out-of-scope file is needed, or an R-id cannot be met. Do not invent requirements or widen scope.
- BLOCKED: any preflight FAIL, missing tool or contradictory spec. Decline out-of-role work.
- Report tests with command, exit code and what each proves; the relay re-runs them before Review.

## 3. Return contract (last block of the final message)

Choose one RESULT. Include CHANGED/TESTS for DONE, QUESTION for NEEDS-INPUT, or REASON for BLOCKED.

```text
RESULT: DONE | NEEDS-INPUT | BLOCKED
TASK: <project> #<id>
CHANGED: <files, one per line>
TESTS: <command> -> exit <code>; <what it proves> (one line per command)
QUESTION: <one question, with options>
REASON: <why it cannot continue>
```

Relay: run `wait` and `result` from the repo above; jobs are looked up in that repo's companion state.
