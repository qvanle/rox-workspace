#!/usr/bin/env bash
# Read-only status. No push, sync, promote or playbook execution.
# Overrides: ROXCTL_BIN, ROX_MANIFEST_DIR, ROX_SHIP_REPO, ROX_SHIP_COMMIT,
# ROX_SHIP_PIPELINE_WAIT, ROX_SHIP_ARGO_WAIT, ROX_SHIP_POLL_SECONDS, ROX_SHIP_COMMAND_TIMEOUT.
set -euo pipefail
if [ "$#" -ne 1 ] && [ "$#" -ne 3 ]; then
  echo 'usage: ship-status.sh <service> [--env staging|production]' >&2
  exit 2
fi
service="$1"
environment=staging
if [ "$#" -eq 3 ]; then
  [ "$2" = --env ] || { echo 'usage: ship-status.sh <service> [--env staging|production]' >&2; exit 2; }
  environment="$3"
fi
case "$environment" in staging|production) ;; *) echo 'usage: ship-status.sh <service> [--env staging|production]' >&2; exit 2 ;; esac
[[ "$service" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]] || { echo 'usage: service must be kebab-case' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo 'FAIL python3 missing -- install Python 3'; exit 1; }
python3 - "$service" "$environment" <<'PY'
import sys, os, shutil, json, subprocess, time, re
from pathlib import Path
try:
    import yaml
except ImportError:
    print('FAIL PyYAML missing -- install PyYAML for Python 3')
    sys.exit(1)
service, environment = sys.argv[1:]
rox = os.environ.get('ROXCTL_BIN', 'roxctl')
repo = os.environ.get('ROX_SHIP_REPO', service)
commit = os.environ.get('ROX_SHIP_COMMIT', '')
if not commit:
    try:
        result = subprocess.run(['git', 'rev-parse', 'HEAD'], capture_output=True, text=True, timeout=5)
        commit = result.stdout.strip() if result.returncode == 0 else ''
    except Exception:
        pass
if commit and not re.fullmatch(r'[0-9a-f]{7,64}', commit):
    print('FAIL expected commit invalid -- set ROX_SHIP_COMMIT to the source commit SHA')
    sys.exit(2)
try:
    pipeline_wait = float(os.environ.get('ROX_SHIP_PIPELINE_WAIT', '2700' if service == 'agent' else '900'))
    argo_wait = float(os.environ.get('ROX_SHIP_ARGO_WAIT', '600'))
    interval = float(os.environ.get('ROX_SHIP_POLL_SECONDS', '10'))
    command_timeout = float(os.environ.get('ROX_SHIP_COMMAND_TIMEOUT', '30'))
    if min(pipeline_wait, argo_wait) < 0 or interval <= 0 or command_timeout <= 0:
        raise ValueError()
    if not all(__import__('math').isfinite(x) for x in (pipeline_wait, argo_wait, interval, command_timeout)):
        raise ValueError()
except ValueError:
    print('usage: wait ceilings must be nonnegative and poll/command timeout positive seconds')
    sys.exit(2)
labels = ['Push landed on internal', 'Pipeline for that commit', 'Image in registry', 'Manifest bump',
          'Argo application', 'Workload health', 'Smoke', 'Promote', 'Production']
print('| # | Checkpoint | Status | Detail |', flush=True)
print('| --- | --- | --- | --- |', flush=True)
failed = False
incomplete = False

def row(index, status, detail):
    global failed, incomplete
    print(f'| {index} | {labels[index-1]} | {status} | {detail} |', flush=True)
    failed |= status == 'FAIL'
    incomplete |= status in ('SKIP', 'WAIT')

if not shutil.which(rox):
    row(1, 'FAIL', 'roxctl missing -- install/build roxctl or set ROXCTL_BIN')
    for i in range(2, 10):
        row(i, 'SKIP', 'preflight failed')
    sys.exit(1)

# Do not print raw stdout/stderr: upstream diagnostics may contain credentials.
# Category --help is safe in the current CLI; some leaf --help commands execute.
# Require a category-advertised full Usage contract before any leaf help probe.
# Unknown JSON schemas also SKIP: fixture support is not proof of a live CLI contract.
help_cache = {}
def run(args, timeout=None):
    try:
        p = subprocess.run([rox, 'platform'] + args, capture_output=True, text=True,
                           timeout=timeout or command_timeout)
        return p.returncode, p.stdout
    except subprocess.TimeoutExpired:
        return 124, ''
    except OSError:
        return 127, ''

def contract(command, flags):
    category = command[0]
    if category not in help_cache:
        help_cache[category] = run([category, '--help'])
    rc, summary = help_cache[category]
    full = 'platform ' + ' '.join(command)
    usages = [line for line in summary.splitlines() if 'Usage:' in line and full in line]
    if rc or not usages or '--help' not in summary:
        return False, 'category help does not document safe leaf help/arguments; flags unknown'
    if not all(any(flag in line for line in usages) for flag in flags):
        return False, 'category help lacks required flags: ' + ', '.join(flags)
    rc, detail = run(command + ['--help'])
    if rc or full not in detail or not all(flag in detail for flag in flags):
        return False, 'leaf help does not confirm required flags; no guessed invocation'
    return True, ''

def read(command, args, flags, ceiling=0, pending=None):
    supported, reason = contract(command, flags)
    if not supported:
        return 'SKIP', reason, None
    start = time.monotonic()
    while True:
        remaining = max(0, ceiling - (time.monotonic()-start))
        rc, output = run(command+args, min(command_timeout, max(0.1, remaining)) if ceiling else command_timeout)
        elapsed = int(time.monotonic()-start)
        if rc == 124:
            return 'WAIT', f'command wait ceiling reached after {elapsed}s; stop polling', None
        if rc:
            return 'FAIL', 'read command failed -- inspect authentication/tool availability via roxctl platform', None
        try:
            data = json.loads(output)
        except (ValueError, TypeError):
            return 'SKIP', 'JSON output schema unknown; inspect supported output format', None
        if pending and pending(data):
            note = '; agent base-image build takes about 35 minutes' if service == 'agent' else ''
            if time.monotonic()-start >= ceiling:
                return 'WAIT', f'ceiling reached; elapsed {elapsed}s; still running{note}', data
            print(f'WAIT elapsed {elapsed}s; stage still running{note}', flush=True)
            time.sleep(min(interval, max(0, ceiling-(time.monotonic()-start))))
            continue
        return 'OK', 'read completed', data

def same_commit(data):
    return isinstance(data, dict) and data.get('commit', data.get('sha')) == commit

def pending_pipeline(data):
    return same_commit(data) and data.get('repo') == repo and str(data.get('status', '')).lower() in ('running', 'pending', 'blocked')

def pending_app(data):
    if not isinstance(data, dict):
        return False
    status = data.get('status', {})
    return isinstance(status, dict) and (status.get('operationState', {}).get('phase') == 'Running'
        or status.get('health', {}).get('status') == 'Progressing')

manifest_value = os.environ.get('ROX_MANIFEST_DIR')
manifest = Path(manifest_value) if manifest_value else next(
    (p/'manifest' for p in [Path.cwd()]+list(Path.cwd().parents) if (p/'manifest').is_dir()), None)

def pins(env):
    if not manifest:
        return None, 'manifest root unknown; set ROX_MANIFEST_DIR'
    overlay = manifest/'clusters/rum'/(service+'-staging' if env == 'staging' else service)
    try:
        path = next((overlay/n for n in ('kustomization.yaml', 'kustomization.yml') if (overlay/n).is_file()), None)
        if path is None:
            return None, 'overlay kustomization absent'
        doc = yaml.safe_load(path.read_text())
        images = doc.get('images', [])
        values = {image.get('name'): image.get('digest') for image in images}
        if not values or any(not isinstance(v, str) or not re.fullmatch(r'sha256:[0-9a-f]{64}', v) for v in values.values()):
            return None, 'image digest absent or not pinned by sha256'
        return values, ''
    except Exception:
        return None, 'overlay YAML invalid (values suppressed)'

registry_digest = None
staging_pins = None
staging_ok = {5: False, 6: False}

def app_check(app):
    state, reason, data = read(['cd', 'app', 'show'], [app, '--json'], ['--json'],
                               argo_wait, pending_app)
    if state != 'OK':
        return state, reason
    try:
        status = data['status']
        sync, health = status['sync']['status'], status['health']['status']
        phase = status.get('operationState', {}).get('phase')
    except (KeyError, TypeError):
        return 'SKIP', 'Argo JSON schema unknown'
    if sync == 'Synced' and health == 'Healthy' and phase not in ('Failed', 'Error'):
        return 'OK', 'Synced and Healthy'
    return 'FAIL', 'Argo not Synced/Healthy or failed operation -- inspect ship traps; failed hooks may need approved force-resync'

def pod_check(namespace):
    state, reason, data = read(['kube', 'pod', 'list'], ['-n', namespace, '--not-ready', '--json'],
                               ['-n', '--not-ready', '--json'])
    if state != 'OK':
        return state, reason
    items = data.get('items') if isinstance(data, dict) else data if isinstance(data, list) else None
    if not isinstance(items, list):
        return 'SKIP', 'pod JSON schema unknown'
    # --not-ready is confirmed by help; empty list means no unready pods.
    if items:
        return 'FAIL', 'pods not ready -- inspect events; distroless CrashLoopBackOff needs numeric runAsUser'
    return 'OK', 'no unready pods; recent events need separate documented read'

for i in range(1, 10):
    if failed:
        row(i, 'SKIP', 'stopped at first FAIL')
        continue
    if i == 1:
        if not commit:
            row(i, 'SKIP', 'source commit unknown; set ROX_SHIP_COMMIT')
            continue
        state, reason, data = read(['codebase', 'status'],
            ['--repo', repo, '--commit', commit, '--remote', 'internal', '--json'],
            ['--repo', '--commit', '--remote', '--json'])
        if state == 'OK':
            if not isinstance(data, dict) or not isinstance(data.get('landed'), bool):
                state, reason = 'SKIP', 'internal branch JSON schema unknown'
            elif not data['landed'] or not same_commit(data) or data.get('remote') != 'internal':
                state, reason = 'FAIL', 'expected commit not on internal -- push internal too via rox-workspace:commit'
            else:
                reason = 'expected commit landed on internal'
        row(i, state, reason)
    elif i == 2:
        if not commit:
            row(i, 'SKIP', 'source commit unknown')
            continue
        state, reason, data = read(['ci', 'pipeline', 'list'],
            ['--repo', repo, '--commit', commit, '--json'], ['--repo', '--commit', '--json'],
            pipeline_wait, pending_pipeline)
        if state == 'OK':
            if not same_commit(data) or data.get('repo') != repo:
                state, reason = 'SKIP', 'cannot correlate pipeline JSON with source repo/commit'
            elif str(data.get('status', '')).lower() in ('success', 'passed'):
                reason = 'matching pipeline succeeded'
            elif str(data.get('status', '')).lower() in ('failure', 'failed', 'error', 'killed', 'cancelled', 'none'):
                state, reason = 'FAIL', 'pipeline failed or absent -- inspect failed step, clone routing, descheduler or forge id'
            else:
                state, reason = 'SKIP', 'pipeline status unknown'
        row(i, state, reason)
    elif i == 3:
        if not commit:
            row(i, 'SKIP', 'source commit unknown')
            continue
        state, reason, data = read(['registry', 'image', 'digest'],
            ['--service', service, '--commit', commit, '--json'], ['--service', '--commit', '--json'])
        if state == 'OK':
            if same_commit(data) and isinstance(data.get('digest'), str) and re.fullmatch(r'sha256:[0-9a-f]{64}', data['digest']):
                registry_digest = data['digest']
                reason = 'commit image digest found'
            elif same_commit(data) and 'digest' in data and not data['digest']:
                state, reason = 'FAIL', 'commit image absent in registry -- inspect kaniko build/push credentials without printing values'
            else:
                state, reason = 'SKIP', 'registry commit/digest JSON schema unknown'
        row(i, state, reason)
    elif i == 4:
        staging_pins, error = pins('staging')
        if error:
            row(i, 'FAIL' if manifest else 'SKIP', error + ' -- resolve manifest overlay/digest')
        elif not registry_digest:
            row(i, 'SKIP', 'registry digest unknown; cannot compare staging bump')
        elif len(staging_pins) != 1:
            row(i, 'SKIP', 'multiple images require per-image commit/digest correlation (agent builds two images)')
        elif registry_digest != next(iter(staging_pins.values())):
            row(i, 'FAIL', 'staging digest mismatch -- inspect update-staging-manifest and its push')
        else:
            row(i, 'OK', 'staging digest matches registry ' + registry_digest)
    elif i in (5, 6):
        state, reason = app_check(service+'-staging') if i == 5 else pod_check(service+'-staging')
        staging_ok[i] = state == 'OK'
        row(i, state, reason)
    elif i == 7:
        row(i, 'SKIP', 'smoke convention unresolved; run read-only probe from the service spec')
    elif i == 8:
        if environment == 'staging':
            row(i, 'SKIP', 'staging request; no production promotion performed')
        else:
            production_pins, error = pins('production')
            if error:
                row(i, 'FAIL' if manifest else 'SKIP', error + ' -- resolve production overlay')
            elif not staging_pins:
                row(i, 'SKIP', 'staging pins unknown')
            elif staging_pins != production_pins:
                row(i, 'FAIL', 'production digest differs from staging -- inspect manual promote run; request approval before rerun')
            else:
                row(i, 'OK', 'production pins equal staging; manual-run provenance requires separate evidence')
    elif i == 9:
        if environment == 'staging':
            row(i, 'SKIP', 'staging request')
        else:
            astate, areason = app_check(service)
            pstate, preason = pod_check(service) if astate == 'OK' else ('SKIP', 'Argo not healthy')
            row(i, 'FAIL' if 'FAIL' in (astate, pstate) else 'OK' if astate == pstate == 'OK' else
                'WAIT' if 'WAIT' in (astate, pstate) else 'SKIP', areason + '; ' + preason)
print('FAIL delivery checkpoint -- inspect traps; no writes performed' if failed else
      'WAIT delivery evidence incomplete -- resolve SKIP/WAIT, smoke and promotion gates' if incomplete else
      'OK delivery evidence complete')
sys.exit(1 if failed else 0)
PY
