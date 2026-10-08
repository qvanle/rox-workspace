---
name: diagnose
description: Diagnose RotexAI aos cluster and platform faults using known symptoms, read-only roxctl probes and tracked Ansible diagnostics. Require evidence before a cause or tracked fix; never use ad-hoc SSH.
---

# diagnose

## 1. Scope and preflight

Investigate cluster/platform faults; application fixes belong to sr-se, capacity planning is outside this skill.
Read [symptoms.md](references/symptoms.md) first. Locate aos and `IaC/`; verify every selected playbook exists and read its header and tasks before running it. Directory placement alone does not establish a read tier.
Check the needed binary (`ROXCTL_BIN` or `roxctl`; Ansible only if needed) with `command -v`, and inspect read-only `--help` for exact probe syntax. On failure print `FAIL <tool>: missing -- <installation/setup fix>` and stop that tool; never silently fall back to SSH, kubectl or raw HTTP.
All cluster interaction uses roxctl or tracked playbooks. Root-required playbooks use `-u qvanle`; inventory user deploy has no sudo. Do not print secrets, tokens or private values; redact evidence before displaying it.

## 2. Investigation

| Step | Action | Tier |
| --- | --- | --- |
| Symptom | Restate service, environment, where and since when; ask only for missing facts | Read |
| Match | Name the matching likely cause and first probe; a match is a hypothesis | Read |
| Probe | Prefer read-only `roxctl infra` / `roxctl platform kube, cd, ci, registry, observation`; then immutable diagnostics; then diagnose-only incidents after reading the header | Read |
| Hypotheses | Cause / evidence for / evidence against / confidence table; at least two when evidence is thin | Read |
| Narrow | Run the cheapest probe that separates the leading hypotheses | Read |
| Fix | Name the tracked fix, scope and blast radius; apply section 3 before executing | Write/destructive |
| Verify | Re-run the probe that exposed the fault; confirm healthy evidence | Read |
| Record | Offer a symptoms row and, for incidents, `docs/18-history-and-decisions.md` entry; hand commit to `rox-workspace:commit` | Write |

Reports land in gitignored `IaC/runtime/reports/`. Cite the report path or actual command output, never remembered behaviour. Load existing reports only when the user names one; read reports produced by this investigation.
With no match say “no known cause”, then use generic read probes: `roxctl platform kube pod list --not-ready`, `roxctl platform kube event list --since <window>`, `roxctl platform cd app list`, and `roxctl platform observation` (resolve required subcommands with `--help`).

## 3. Action tiers and traps

| Tier | Before execution |
| --- | --- |
| Read | No confirmation for genuine read-only probes |
| Write | State the effect in one line, get a yes; use `--dry-run` or Ansible `--check` first where supported |
| Destructive / force / hard to reverse | Show the live preview, ask the user to type the target name; retain every typed confirmation the playbook demands |

Never type or supply confirmation variables for the user, including `DELETE ORPHANS`, `PURGE` or `ROLL AMBIENT PODS`. Do not weaken roxctl's gates. The registry push probe creates pods and uploads blobs: treat it as Write despite living in diagnostics.
Post-reboot ambient 502s need pod recreation through the tracked repair; restarting ztunnel alone does not re-adopt pods. A stuck hook with stale digest may need `force-resync-app.yml -e target_app=<app>` after evidence and force confirmation.
Fold new logic into the role/playbook owning the resource, never a new playbook or opt-in flag. Link incident wiki pages when known; do not invent links or copy their content.

## 4. Roles

Load `../rox-workspace/domains/product/roles/_common.md` and active cards; apply union, warn and ask before out-of-role actions. No active role means no role warning.

| Role | Behaviour |
| --- | --- |
| sa | Primary: probes, fixes and records |
| sr-se | Investigates own services; infra fixes to sa (warn and ask) |
| po, pm | Status summaries and reports; running probes needs warn-and-ask |
| des, qa, qc | Read reports; other actions need warn-and-ask |
| jr-se, entry-se | Read reports through brief; never runs fixes, commits, pushes, ships, seals or scaffolds |

## 5. Output

| Symptom | Evidence | Cause | Confidence | Next action |
| --- | --- | --- | --- | --- |

Follow with one next-action line. Distinguish a hypothesis from a confirmed cause and name any evidence still missing.
