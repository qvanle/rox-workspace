---
name: verify
description: Verify built RotexAI rox-workspace tasks as qc by running the repo spec's test plan and recording evidence per R-id. Move Review to Done only with proof, or back to Implementing with findings; never edit code, tests or task notes.
---

# verify

## 1. Preflight and gates

Run `bash ../rox-workspace/scripts/preflight.sh pma` from this skill's base directory. Show FAIL and its fix; stop that tool without a raw vja/browser fallback. Check each evidence tool before use; a missing tool makes its R-ids unproven.
Read `../rox-workspace/references/pma.md`, active cards and `../rox-workspace/domains/product/roles/_common.md`; apply union and warn-and-ask. No active role means no role warning.
Run `roxctl workspace pma show <id>` and read the requirement R-ids, task bucket, repo spec and its test plan. Require task in `Review` and standalone `Status: approved ...`; otherwise state the failed gate and stop. Missing approval is unapproved.
No spec (including a chore): report evidence in the reply, request a spec from sr-se, and do not move to Done. Missing/empty plan: report the QA gap, never infer a passing plan.
In the code repo record `git rev-parse HEAD` and `git status --short`. State dirty-tree changes explicitly and that evidence includes them; never imply that the SHA alone reproduces those results.

## 1b. Mode

By default `verify` runs as the `rox-workspace:qc` subagent (a fresh context, brief from `templates/qc-brief.md`): the agent does sections 3 and 4, the relay
re-runs one plan command and does the move in section 5. "Verify inline" runs everything in the main session.

## 2. Separation of duties

| Situation | Action |
| --- | --- |
| This active set implemented the same task this session (e.g. sr-se qc) | Warn once: “you implemented this; verify anyway?”; proceed on yes and record `verifier == implementer` |
| jr-se or entry-se implemented, qc verifies | Intended path; no warning |
| qa wrote the plan, qc verifies | Allowed in one set; no warning |

## 3. Run and judge

1. Run each named plan command yourself, one at a time in its named environment; record its exact command and exit code. A pasted “all tests pass” is not evidence. For manual criteria, perform the check and record observed evidence; never invent an exit code.
2. For each R-id, say what the evidence proves and does not prove. A green test that never exercises its requirement is a gap. Every R-id must be proven, not just present in the table.
3. Label every added check `inferred` in its own evidence row; keep it distinct from planned evidence. Run only the plan by default; report any encountered full-suite failure as a finding.
4. Do not fix code or tests to make verification pass. Failures go to the engineer, wrong/missing tests to qa, doubtful requirements to po.

Check commands' action tiers before execution. Cluster probes use only roxctl or tracked Ansible, never ad-hoc SSH/kubectl. Root-required playbooks use `-u qvanle`. Write: state effect and get yes, dry-run where supported. Force/destructive: live preview and user-typed target/required confirmation; never type it for them. No secrets, tokens or values in output; cite redacted evidence paths. Say project.

## 4. Record the verdict

Write only `## Review notes` in the spec, never the task's note/title. Preserve the requirement/spec links, approval and test-plan headers; record commit or PR in the spec.

```text
Verified at commit <sha> on YYYY-MM-DD by <user>.
```

| R-id | Command | Exit | Proves | Does not prove | Inferred? | Verdict |
| --- | --- | --- | --- | --- | --- | --- |

Include dirty-tree disclosure and any separation warning in these notes. Resolve the user's identity; never invent it. For manual checks use `N/A (manual)` for Exit. Pass only if all R-ids have proof; otherwise name failed and unproven R-ids. Return the table plus one verdict/next-action line.

## 5. Move after recording

| Verdict | Lookup | Move |
| --- | --- | --- |
| Pass: every R-id proven | `roxctl workspace pma <project> bucket ls` → Done id | `roxctl workspace pma edit <id> --bucket-id <Done id>` |
| Fail/gap | `roxctl workspace pma <project> bucket ls` → Implementing id | `roxctl workspace pma edit <id> --bucket-id <Implementing id>` |

State the concrete move's effect and get a yes under the Write tier unless already authorised. Moving into Done completes the task; do not toggle it again. Stop if the target bucket is missing/ambiguous; do not guess an id or use a bucket-name flag. On failure tell the implementer which R-ids need work in the reply/handoff, with findings in the spec.

## 6. Roles

| Role | Behaviour |
| --- | --- |
| qc | Owns verification, notes and Review → Done/Implementing |
| qa | May read notes; running verification needs warn-and-ask |
| sr-se | Out of role unless qc is also active |
| po, jr-se, entry-se, pm, des, sa | Verification is out of role; jr-se and entry-se never edits specs, fixes verification, commits, pushes, ships, seals or scaffolds |

Reading is always allowed. Labels or owner handoffs are proposals, never edits to an existing task's note.
