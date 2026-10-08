#!/usr/bin/env bash
# Behaviour tests with a disposable local manifest and documents; no cluster access.
[ $# -eq 0 ] || { echo 'usage: run-tests.sh' >&2; exit 2; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
checker="$script_dir/../scripts/claims-check.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/rox-docs-tests.XXXXXX")" || exit 1
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/repo/manifest/services/auth" "$fixture/repo/manifest/services/workflows/be-proxy" \
  "$fixture/repo/manifest/clusters/rum/agent-staging" "$fixture/repo/codebase/backend/source-only" \
  "$fixture/repo/docs" "$fixture/repo/IaC/playbooks/immutable/diagnostics/general"
manifest="$fixture/repo/manifest"
doc="$fixture/repo/docs/check.md"
touch "$fixture/repo/codebase/backend/source-only/main.py" \
  "$fixture/repo/IaC/playbooks/immutable/diagnostics/general/check.yml" "$fixture/repo/docs/linked.md"
cat > "$manifest/clusters/rum/agent-staging/routes.yaml" <<'YAML'
kind: IngressRoute
spec:
  routes:
    - match: Host(`api.rotexai.com`) && PathPrefix(`/api`)
---
kind: Certificate
spec:
  dnsNames:
    - cert.rotexai.com
    - '*.preview.rotexai.com'
---
kind: Ingress
spec:
  rules:
    - host: ingress.rotexai.com
  tls:
    - hosts:
        - tls.rotexai.com
---
kind: Secret
stringData:
  host: secret-only.rotexai.com
  token: TEST_VALUE_MUST_NOT_APPEAR
---
kind: ConfigMap
data:
  host: config-only.rotexai.com
YAML
cat > "$manifest/services/auth/comment.yaml" <<'YAML'
kind: IngressRoute
# match: Host(`comment-only.rotexai.com`)
spec: {}
YAML
passed=0
failed=0
output=""
status=0
run() {
  output="$(AOS_ROOT="$fixture/repo" bash "$checker" "$doc" --manifest "$manifest" 2>&1)"
  status=$?
}
check() { # title, expected exit, required literal, optional forbidden literal
  local name="$1" expected="$2" required="$3" forbidden="${4:-}"
  if [ "$status" -eq "$expected" ] && [[ "$output" == *"$required"* ]] && \
    { [ -z "$forbidden" ] || [[ "$output" != *"$forbidden"* ]]; }; then
    echo "OK $name"
    passed=$((passed + 1))
  else
    echo "FAIL $name: unexpected verdict or exit $status -- inspect claims-check behaviour"
    failed=$((failed + 1))
  fi
}

printf '%s\n' '`auth` `be-proxy` `agent-staging` `source-only` `retired-service` `tenant_id` `SELECT`' > "$doc"
run
check 'service base' 0 'OK auth: deployed'
check 'nested component' 0 'OK be-proxy: deployed'
check 'cluster overlay' 0 'OK agent-staging: deployed'
check 'source-only service' 0 'WARN source-only: not deployed'
check 'unknown service slug' 0 'WARN retired-service: not deployed'
check 'identifiers excluded' 0 'OK claims scan' 'WARN tenant'

printf '%s\n' '`manifest/services/auth` `IaC/playbooks/immutable/diagnostics/general/check.yml` `codebase/backend/source-only/main.py:12` [link](linked.md#anchor)' > "$doc"
run
check 'repo paths and line anchor' 0 'OK codebase/backend/source-only/main.py: exists' 'FAIL'
check 'playbook path' 0 'OK IaC/playbooks/immutable/diagnostics/general/check.yml: exists'
check 'document-relative link' 0 'OK linked.md: exists'
printf '%s\n' 'See `codebase/backend/source-only/missing.py`.' '[missing](absent.md)' > "$doc"
run
check 'missing root path fails' 1 'FAIL codebase/backend/source-only/missing.py: missing --'
check 'missing doc link fails' 1 'FAIL absent.md: missing --'

printf '%s\n' 'api.rotexai.com cert.rotexai.com build.preview.rotexai.com ingress.rotexai.com tls.rotexai.com missing.rotexai.com secret-only.rotexai.com config-only.rotexai.com comment-only.rotexai.com api.rotexai.com.evil' > "$doc"
run
check 'IngressRoute host' 0 'OK api.rotexai.com: route'
check 'certificate DNS' 0 'OK cert.rotexai.com: route'
check 'wildcard certificate' 0 'OK build.preview.rotexai.com: route'
check 'Ingress host' 0 'OK ingress.rotexai.com: route'
check 'Ingress TLS host' 0 'OK tls.rotexai.com: route'
check 'unrouted host warns' 0 'WARN missing.rotexai.com: no route'
check 'Secret is not route evidence' 0 'WARN secret-only.rotexai.com: no route' 'TEST_VALUE_MUST_NOT_APPEAR'
check 'ConfigMap is not route evidence' 0 'WARN config-only.rotexai.com: no route'
check 'comment is not route evidence' 0 'WARN comment-only.rotexai.com: no route'
check 'hostname suffix is not a hostname claim' 0 'OK claims scan' 'api.rotexai.com.evil'

printf '%s\n' 'Gitea as an AI-agent feature; cms; deeptutor-brain; agent-automation Postgres; `jwt-validator`; AFFiNE; iap-internal; web-registry. Tenant and tenant_id.' > "$doc"
run
check 'Gitea feature scoped removal' 0 'WARN Gitea as an AI-agent feature: removed (2026-08-25'
check 'cms removal' 0 'WARN cms: removed'
check 'deeptutor family removal' 0 'WARN deeptutor: removed'
check 'automation database removal' 0 'WARN agent-automation Postgres: removed (2026-09-09'
check 'jwt rename' 0 'WARN jwt-validator: removed (2026-09-04, replaced by iap)'
check 'wiki rename' 0 'replaced by Outline)'
check 'iap-internal removal' 0 'WARN iap-internal: removed'
check 'registry UI removal' 0 'WARN web-registry: removed'
check 'tenant terminology' 0 'WARN tenant: say project'
printf '%s\n' 'CI uses Gitea. rox-git is Gitea. `tenant_id`, tenant_id_suffix, tenants, tenancy.' > "$doc"
run
check 'active Gitea not removed' 0 'OK claims scan' 'WARN Gitea'
check 'tenant_id and other words allowed' 0 'OK claims scan' 'WARN tenant'

printf '%s\n' '`auth`' > "$doc"
output="$(cd "$fixture/repo/docs" && unset AOS_ROOT && bash "$checker" "$doc" 2>&1)"
status=$?
check 'default manifest discovery' 0 'OK auth: deployed'
mkdir -p "$fixture/detached/docs"
printf '%s\n' '`codebase/backend/source-only/main.py`' > "$fixture/detached/docs/check.md"
output="$(AOS_ROOT="$fixture/repo" bash "$checker" "$fixture/detached/docs/check.md" --manifest "$manifest" 2>&1)"
status=$?
check 'AOS_ROOT resolves detached docs' 0 'OK codebase/backend/source-only/main.py: exists'
output="$(bash "$checker" 2>&1)"; status=$?
check 'no args usage' 2 'usage:'
output="$(bash "$checker" "$doc" --unknown "$manifest" 2>&1)"; status=$?
check 'unknown flag usage' 2 'usage:'
output="$(bash "$checker" "$doc" --manifest 2>&1)"; status=$?
check 'missing flag value usage' 2 'usage:'
output="$(bash "$checker" "$fixture/no-file.md" 2>&1)"; status=$?
check 'missing document preflight' 1 'FAIL document:'
output="$(PYTHON_BIN=rox_nonexistent_python bash "$checker" "$doc" --manifest "$manifest" 2>&1)"; status=$?
check 'missing Python preflight' 1 'FAIL python3:'
output="$(bash "$checker" "$doc" --manifest "$fixture/no-manifest" 2>&1)"; status=$?
check 'missing manifest preflight' 1 'FAIL manifest:'

echo "docs tests: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
