---
name: seal-secret
description: Seal aos per-service staging or production env files offline into GitOps SealedSecrets through roxctl, showing only key-name diffs and registering the overlay resource.
---

# seal-secret

## 1. Preflight and resolve

Check kubeseal, roxctl, `env/sealed-secrets-cert.pem`, and a nonempty env source; FAIL stops with a fix.
Resolve service, environment, purpose/name and namespace; ask for missing inputs.
Check the service exists in `manifest/services/`; removed services such as cms must stop.
Check `git check-ignore` and `git status` for the source; stop if it is tracked, staged or not ignored.
Do not assume `env/` is ignored. Read key names only; never cat/echo/grep values into output.

| Item | Path/rule |
| --- | --- |
| Source | Workspace `env/<service>/{staging,production}.env` |
| Certificate | Workspace `env/sealed-secrets-cert.pem`; offline, no cluster required |
| Output | `manifest/clusters/rum/<service>[-staging]/<service>-<purpose>.sealedsecret.yaml` |
| Secret name | File stem excluding `.sealedsecret.yaml`, e.g. `iap-cdn` |
| Namespace | `<service>-staging` or `<service>` for production |
| Registration | Overlay `kustomization.yaml` resources |

## 2. Key diff and confirmation

Run `bash <skill base dir>/scripts/seal-diff.sh <env-file> <sealedsecret.yaml>`.
It needs Python 3 and PyYAML, prints env/existing names and added/removed/unchanged tables,
and fails on empty values, duplicate keys, whitespace or invalid characters in a key.
A missing sealed file is a first seal; an existing malformed file stops. Parser errors are sanitized.
Show the key-name diff and output path; call removed names intentional removal or orphan cleanup.
State that sealing writes the output and registers it, then ask yes before doing either.
Never print, log, paste or pass values as command-line arguments; never create tracked `kind: Secret`, even temporarily.
Seal each environment from its own file; never copy production values to staging.

## 3. Seal, register and validate

Discover supported flags from safe category help; leaf `--help` may execute commands in current roxctl.
Use the following only when the installed CLI confirms the flags and certificate source:
`roxctl platform secrets seal run <env-file> --name <name> --namespace <ns> --out <output>`.
Sealing is local kubeseal against the certificate, with file paths only; no playbook or cluster access.
If the installed interface is unclear, stop with SKIP and the unknown flag; never invent a certificate flag.
Ensure the sealed file is in `resources:`; add the relative filename when absent.

| Check | Command/action |
| --- | --- |
| Shape/key names | `roxctl platform secrets seal check` (inspect supported scope first) |
| No plaintext | In manifest: `npm run check:unsealed-secrets` |
| Render | `kubectl kustomize <overlay> --load-restrictor LoadRestrictionsNone` |
| Placement | Verify namespace, secret name and resource registration |

`seal check` may scan all env/overlay pairs; distinguish unrelated drift from this output's validation.
Never claim it verifies ciphertext decryption unless help explicitly establishes that behavior.
Hand the commit to `rox-workspace:commit`, and first sync to `rox-workspace:ship`.
Finish with a key-name table, output path and the next action; no values or ciphertext.

## 4. Roles

Read active roles and `../rox-workspace/domains/product/roles/_common.md`.
sa owns sealing. sr-se sealing its own service warns that secrets are sa's area and asks.
po, pm, des, qa and qc warn and ask; jr-se and entry-se never seal. No role active follows the write confirmation above.
