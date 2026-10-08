---
name: ship
description: Follow an aos service from its internal push through Woodpecker, registry digest, GitOps manifest and Argo health. Use for staging delivery or gated production promotion in rox-workspace.
---

# ship

## 1. Preflight and scope

Start after the push to `internal`; pushing belongs to `rox-workspace:commit`.
Resolve service, source repo, expected commit and `manifest/` from cwd or ask for missing inputs.
Use only `roxctl platform` and tracked Ansible playbooks for cluster access; never ad-hoc SSH or kubectl.
Check roxctl and its wrapped argocd, woodpecker-cli and regctl availability; stop the tool on FAIL with its fix.
Read the installed help before using flags. Some leaf `--help` calls execute commands:
use category help first; if it cannot document the command and flags, report SKIP rather than probe blindly.

## 2. Status

Run `bash <skill base dir>/scripts/ship-status.sh <service> [--env staging|production]`.
The self-contained Bash entrypoint needs Python 3 and PyYAML; `ROXCTL_BIN` permits fake binaries.
Set `ROX_SHIP_COMMIT`, `ROX_SHIP_REPO` and `ROX_MANIFEST_DIR` to resolved inputs.
It reads only; stdout contains the nine checkpoints and sanitized summaries, never raw tool output.

| # | Checkpoint | Evidence |
| --- | --- | --- |
| 1 | Push landed on internal | Internal branch contains the expected commit |
| 2 | Pipeline for that commit | Repo and commit match; verify/build status |
| 3 | Image in registry | Digest for that commit |
| 4 | Manifest bump | Staging image digest equals registry digest |
| 5 | Argo application | Staging Synced and Healthy |
| 6 | Workload health | Staging pods ready; recent events |
| 7 | Smoke | Read-only route probe specified by this service's spec |
| 8 | Promote | Manual run, then staging and production digest equality |
| 9 | Production | Production Argo and pods healthy |

Stop at the first FAIL; later rows are SKIP. SKIP never proves health.
Running stages print WAIT with elapsed seconds; ceilings default to 2700s for agent pipelines,
900s for others and 600s for Argo. Overrides: `ROX_SHIP_PIPELINE_WAIT`, `ROX_SHIP_ARGO_WAIT`,
`ROX_SHIP_POLL_SECONDS` (default 10), `ROX_SHIP_COMMAND_TIMEOUT` (default 30).
At the ceiling stop waiting, leave WAIT and hand control back; do not call the running build failed.
The agent base-image build can take about 35 minutes.
Smoke convention and promote CLI are unresolved: the script SKIPs them; run the service's documented
probe separately and inspect the manual Woodpecker run before claiming success.

## 3. Failure and action tiers

On FAIL load [references/traps.md](references/traps.md); name the matching cause and tracked fix.
If no match, say "no known cause" and hand to `rox-workspace:diagnose`.
For a write (sync, rerun, promote, seal): state its effect, get yes, then use supported dry-run first.
For destructive/force operations require the application name typed back. Root playbooks use `-u qvanle`.
The force-resync playbook deletes hook Jobs, can strip finalizers and terminates stuck operations;
show those effects before asking, including `-e target_app=<app>`.
Re-run status after an approved fix. Never silently execute a fix in the status script.

## 4. Production and roles

Require green staging evidence, the same digest and the task state before promotion.
`Done` means qc verified it; in `Review`, warn "that is qc's call; promote anyway?" and await yes.
Read active roles and `../rox-workspace/domains/product/roles/_common.md`.
sa or sr-se may ship; other roles warn and ask; jr-se and entry-se never ship or promote.
Rollback: name the manifest digest commit to revert through `commit`; never push a revert yourself.
Finish with the checkpoint table and one line: healthy environment at digest, WAIT ceiling, or failing checkpoint.
