---
name: new-service
description: Scaffold an aos GitOps service with staging and production overlays, Argo applications, mesh policy and derived sync-waves. Use when adding a service to manifest, before sealing, committing or shipping.
---

# new-service

## 1. Preflight and inputs

Check Python 3/PyYAML for the planner, kubectl for local render, and npm for manifest validation.
Stop the tool on FAIL with a fix. Read the closest existing service for structure only, never copy its waves.
Ask one missing input at a time, with defaults; infer what is in the service's spec/repo.

| Input | Default/source |
| --- | --- |
| Name/namespace | Kebab-case; `<service>` and `<service>-staging` |
| Kind | Stateless/stateful, public route, PreSync/PostSync hook |
| Image | `registry.rotexai.com/<image>`; overlays pin digest, never tag |
| Port, probes, resources | Spec or ask; numeric runAsUser, runAsNonRoot for distroless |
| Host/route | If public, under rotexai.com with a Certificate |
| Secrets | Key names only; values belong to seal-secret |
| Environments | Staging and production are both required |

## 2. Plan and scaffold

Show a one-screen file plan, state the writes and ask yes. Populate [templates/](templates/), replacing
all `<placeholders>`; remove unused optional PVC/route/certificate/hook files and their resource entries.
Templates use `services/<service>`, `clusters/rum/<service>[-staging]` and `clusters/rum/apps/`.
Register BOTH applications in `clusters/rum/apps/kustomization.yaml`; the rum root includes `apps`.
Argo uses default project, manifest Gitea URL, main, CreateNamespace, prune and selfHeal.
The templates are a stateless base plus optional PVC/StatefulSet/hooks; choose one workload.
Enroll namespaces in ambient mesh; use a per-environment L4 AuthorizationPolicy with explicit callers,
including monitoring and self; check all callers are enrolled. sa owns mesh, secrets and Argo.
The current agent/agent-staging policies differ by namespace; production azp constraints need review,
and L7 constraints need a waypoint. Never put azp rules into a ztunnel-only L4 policy.
For stateful services review WaitForFirstConsumer binding; a PVC must not block its consumer from starting.

## 3. Derive waves

Run `bash <skill base dir>/scripts/syncwave-plan.sh <service-dir>` for the base and BOTH overlays.
The planner uses `kubectl kustomize <dir> --load-restrictor LoadRestrictionsNone` locally when available;
otherwise it parses local YAML and reports that patches/generators need a full render before approval.
`KUBECTL_BIN` overrides the binary; `ROX_MANIFEST_DIR` selects the comparison tree (default inferred).

| Dependency class | Proposed wave | Why |
| --- | --- | --- |
| Namespace, ServiceAccount | 0 | Prerequisites |
| ConfigMap, SealedSecret | 10 | Configuration before pods |
| PVC, StatefulSet claims | 20 | Storage before consumers |
| PreSync Job | 30 | Migration dependencies |
| Deployment, StatefulSet, other pod workloads | 40 | Consume earlier resources |
| Service, Certificate, IngressRoute, AuthorizationPolicy | 50 | Network/policy |
| PostSync Job | 60 | After healthy workload |

Explain gaps and adjust numbers for this service; the script proposes, never edits.
Missing waves and unknown classes need review; later PVC waves exit 1; BeforeHookCreation hooks are flagged.
Argo phases precede wave ordering: a PreSync hook cannot rely on Sync-phase configuration/PVCs just by wave.
Resolve phase dependencies explicitly; the optional hook skeleton requires an approved phase and wave.
Read-only comparison shows existing waves. Never treat another service's waves as defaults.

## 4. Validate and hand off

All checks must pass before offering a commit: in manifest run `bash scripts/check-kustomizations.sh`,
render both new overlays with kubectl, `npm run check:unsealed-secrets`, and the wave planner (no deadlock).
Confirm both overlays and applications exist, registration is complete and placeholders are gone.
Hand secrets to `rox-workspace:seal-secret`, commits to `rox-workspace:commit`, first deployment to `rox-workspace:ship`.
Offer separate commits for the service repo's verify/kaniko/staging-bump/manual-promote Woodpecker pipeline
(using global REGISTRY_USER/REGISTRY_PASSWORD), monitor metrics/alert tiers, and docs inventory through `docs`.
Keep `env/<service>/{staging,production}.env` ignored and untracked; never commit plaintext.
List Keycloak client, DNS/Cloudflare and any IAP `/v1/*` routing entry as follow-ups, not done.

## 5. Roles

Read active roles and `../rox-workspace/domains/product/roles/_common.md`.
sr-se and sa may scaffold; other roles warn and ask. jr-se and entry-se never scaffold: say it is sr-se's call.
