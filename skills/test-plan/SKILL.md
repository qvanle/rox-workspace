---
name: test-plan
description: Plan QA coverage for RotexAI rox-workspace pma requirements before implementation. Turn each R-id into criteria and evidence commands in the repo spec; propose needs-info for untestable requirements without editing task notes.
---

# test-plan

## 1. Scope and preflight

QA works before the build; qc verifies after it. This skill writes the spec's test plan, not production code or test implementations. Load testing strategy and security review belong elsewhere (`/security-review`).
Run `bash ../rox-workspace/scripts/preflight.sh pma` from this skill's base directory; add wiki preflight when reading a linked tactic. On FAIL show the fix and stop the failed tool; no raw ol/vja, browser or local substitute for missing pma/wiki data.
Read `../rox-workspace/references/pma.md` and active role cards with `roles/_common.md` under `../rox-workspace/domains/product/`; apply the union and warn-and-ask, with no warnings when none is active.

## 2. Read and judge testability

1. Run `roxctl workspace pma show <id>`; read the immutable requirement note, all R1..Rn, the repo spec and the linked tactic (what “worked” means). Link these sources; never copy or change the task's note/title.
2. Decide whether each R-id has an observable pass/fail. Flag vague “fast”, “easy”, “secure” without a threshold, or a “how” without a testable “what”; do not invent an acceptance threshold.
3. Propose to po a `needs-info` **label** and a comment in the reply naming the untestable R-ids. No task-note edit or invented task-comment command. Apply the label only after confirmation, following pma label reuse/colour rules; never `--force-create`.

## 3. Draft coverage

For every testable R-id, give Given / When / Then criteria for the happy path, at least one edge and one error; add non-functional criteria when the requirement names them. Name each test so an engineer can find it; specify unit, integration, end-to-end, manual or probe and a concrete evidence command/check.
For infra or docs requirements use probe/manual, with the roxctl command or explicit check. Planning does not execute cluster mutations. Never expose secret values in criteria, commands or output.

| R-id | Criterion (Given / When / Then) | Test | Level | Evidence command |
| --- | --- | --- | --- | --- |

Count distinct requirement R-ids, not table rows: every R-id needs at least one test. List uncovered and untestable R-ids explicitly. Return the table plus `n of n R-ids covered`, or a one-line list of the gaps.

## 4. Review and write

Show the concrete plan first. On the user's yes, write only `## Test plan` and the `Test plan:` header in the spec; preserve its standalone approval line and other content. A missing spec needs the sr-se Specify workflow first.

```text
Requirement: <pma project> #<id>
Status: draft | approved YYYY-MM-DD (<user>, sr-se) | superseded
Test plan: reviewed YYYY-MM-DD (<user>, qa) | not reviewed
```

Set `Test plan: reviewed YYYY-MM-DD (<user>, qa)` after approval; resolve the user's identity rather than inventing it. A missing header counts as not reviewed. Flag any unresolved R-ids even when a partial plan is accepted; do not claim complete coverage.
QA review is sr-se's warn-and-ask prerequisite to spec approval; this skill does not approve the spec. `brief.sh specs-no-test-plan` already lists specs whose test plan section cites no R-id; that brief is not a complete coverage check.
If sr-se authored the spec and also reviews as qa, allow it and note `plan reviewer == spec author` in the plan header. qa with qc is allowed without a separation warning.

## 5. Roles and handoff

| Role | Behaviour |
| --- | --- |
| qa | Owns writing/reviewing the plan |
| qc | May read; writing is qa's call (warn and ask) |
| sr-se | Consulted; may write without qa after one warning and yes |
| po | Reads criteria and resolves needs-info |
| jr-se, entry-se, pm, des, sa | Writing is out of role (warn and ask); jr-se and entry-se never edits specs, commits, pushes, ships, seals or scaffolds |

Handoff: tests/code to the engineer, requirement doubts to po, post-build proof to `rox-workspace:verify`. Record commit/PR links in the spec, never the task note. This skill needs no bucket move; any separately authorised move looks up `roxctl workspace pma <project> bucket ls` then uses `roxctl workspace pma edit <id> --bucket-id <id>`.
