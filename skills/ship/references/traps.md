# Ship traps


Each row is a symptom at a checkpoint, the cause found before, and the tracked fix. Add a row when a new cause is found.

| At | Symptom | Cause | Fix |
| --- | --- | --- | --- |
| 2 | Clone step times out on `github.com` (about 15 to 35 percent of runs) | Regional routing upstream | Re-run the pipeline. Raising `plugin-git` attempts or backoff does not help (it only retries "find remote ref") |
| 2 | Agent image build seems stuck for 30 minutes or more | The base-image build legitimately takes about 35 minutes | Wait; the keepalive setting keeps the gRPC stream alive |
| 2 | Pipelines cancelled at random | The descheduler evicting the Woodpecker server pod | Annotation `descheduler.alpha.kubernetes.io/evict: "false"` (already set; check it survived) |
| 2 | Repo has no pipelines after the forge changed | Stale `forge_remote_id` | `repair-woodpecker-repos.yml` (read-only phase first) |
| 3 | Push refused by the registry | Kaniko credentials: the global `REGISTRY_USER` / `REGISTRY_PASSWORD` secrets | Check them with `roxctl platform ci secret`; do not print values |
| 3 | Pin or retention surprise | Zot retention keeps the newest N tags | `roxctl platform registry pin check` and `pin margin` |
| 5 | Application stuck, a PreSync or PostSync hook Job failing on a stale digest | `hook-delete-policy: BeforeHookCreation` only replaces the Job on the next sync | `IaC/playbooks/hotfixes/maintenance/force-resync-app.yml -e target_app=<app>` (it deletes failed hook Jobs, hard-refreshes and waits for Synced and Healthy) |
| 5 | Application never syncs a new PVC or workload | Sync-wave order wrong (a copied template) | Re-derive the waves for that service (`new-service` spec section 3); do not copy another service's |
| 6 | Pod `CrashLoopBackOff` with a distroless image and `runAsNonRoot` | `runAsUser` must be numeric | Set a numeric `runAsUser` in the deployment patch |
| 6 | A service returns 502 after a node reboot | Ambient mesh: pods were not adopted | Recreate the pods; restarting ztunnel alone is not enough |
| 7 | Portal static assets hang | The known asset-stall incident | `IaC/playbooks/hotfixes/incidents/01-route-check.yml` then `02-portal-asset-stall.yml` |
| 9 | Production digest not updated | The promote run did not complete | Re-run the manual promote; confirm with checkpoint 4 on the production overlay |


Force-resync is destructive: deletes failed hook Jobs, may strip finalizers and terminates running operations.
Require the application name typed back before running; root playbooks use `-u qvanle`.
No matching symptom: say "no known cause" and hand to `rox-workspace:diagnose`.
