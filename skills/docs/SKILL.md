---
name: docs
description: Write, update, verify or explain RotexAI aos in-repo docs, READMEs and runbooks against code and manifests. Use for the numbered docs set and role-aware explanations; route wiki documents and pma requirements to rox-workspace.
---

# docs

## 1. Scope and preflight

Owns `aos/docs/NN-*.md`, nested-repo READMEs, runbooks and diagrams. Wiki and pma belong to `rox-workspace`; specs use its Specify workflow with `superpowers:brainstorming`. Code comments follow the code repo's conventions.
For “write that up” without context, ask: wiki (why, intent, outcome) or repo (how it is built, how to run it)?
First locate the aos root, target repo and source files. The local checker requires Bash and Python 3; it prints a FAIL with a fix on missing inputs/tools. Stop that check on FAIL, with no silent fallback.
Only when wiki/pma is needed, run `bash ../rox-workspace/scripts/preflight.sh wiki|pma|all` relative to this skill's base directory; stop the failed tool. Local docs need no cluster access.

## 2. Modes

| Mode | Trigger | Result |
| --- | --- | --- |
| write | Document a new service/subsystem | New file only if no existing file covers it; index row |
| update | Update docs for a change | Minimal edit; preserve untouched sections |
| verify | Are these docs right? Before a release | Claim / evidence / verdict table; fix on the user's yes |
| explain | Explain, walk through, how does it work? | Answer for the active audience; save only after their choice |

## 3. Write, update and verify

1. Search the docs and `00-index.md`; prefer the existing subject file over a near-duplicate. Number `05` is deliberately unused.
2. Read the actual code, manifest or tracked playbook; attach a source to each factual claim. Start a doc with coverage and the date it was written from code.
3. Draft or audit; run `bash <skill base dir>/scripts/claims-check.sh <file.md> [--manifest <aos>/manifest]`. `AOS_ROOT` overrides repo path resolution; otherwise use the manifest's parent. Default manifest discovery searches the doc's and current directory's ancestors.
4. Fix every FAIL; decide and report every WARN, including legitimate historical mentions. The checker finds local claims, not proof of runtime health. Check backticked service slugs against manifest directories, paths against disk, and hosts against route/certificate fields. Plain code identifiers are not automatically services.
5. Flag doc/code discrepancies explicitly in the doc, following `24-wiki-vs-code-reconciliation.md`; never silently replace a conflicting claim.
6. Update `00-index.md` for a new numbered file or changed coverage. Show `git diff --stat` and the claims table; hand the commit to `rox-workspace:commit` (jr-se hands off to sr-se).

Use tables for components, routes, hosts and flows; diagrams only when clearer. Link requirements, specs and wiki pages instead of copying. Say project; use Outline and IAP. Read [removed-things.md](references/removed-things.md) for stale names; add a row when something is removed. Never expose secrets, tokens or private values; cite sealed-secret names and key names only.

## 4. Explain for the audience

Use the active role set; with none active, ask the audience in one line. Answer first, evidence after; tables before prose. Every code reference has `file:line`; state what remains unverified. In a combined set, use the role that owns the subject.

| Role | Pitch | Lead |
| --- | --- | --- |
| po | Outcomes, users, risks, cost of change | User outcome, then trade-off table |
| pm | State, dependencies, blockers, sequencing | Status table, then what unblocks what |
| des | Flows, states, edge cases, user-visible messages | Step / state / message table |
| sr-se | Mechanism, boundaries, failures, decisions | Code walk with `file:line`, rejected alternatives |
| jr-se, entry-se | One task's path through code in order | Numbered steps tied to spec R-ids |
| sa | Runtime, ports, hosts, secret names, blast radius, rollback | Runtime table, then runbook |
| qa | Testability and test level | R-id to testable behaviour |
| qc | Proof and its limits | Evidence needed per R-id |

After an explanation that took real work, offer saving to `aos/docs/NN-*.md`, saving a wiki reference through `rox-workspace`, or leaving it in the terminal. Never save without that choice.

## 5. Roles and handoff

With active roles, load `../rox-workspace/domains/product/roles/_common.md` and the relevant role card; apply union and warn-and-ask. With none, no role warnings.

| Role | Behaviour |
| --- | --- |
| sr-se, sa | Write/update their area; sa owns runtime and infra docs |
| po, pm, des, qa, qc | Explain/verify; warn and ask before writing code docs, except their own artefacts |
| jr-se, entry-se | Update docs only for its task; larger rewrites to sr-se; never commit, push, ship, seal or scaffold |

Return the table plus one next-action line. Verification is on request or before release; README format is free-form under these rules.
