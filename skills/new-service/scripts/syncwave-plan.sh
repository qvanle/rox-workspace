#!/usr/bin/env bash
# Local render only, no cluster API. Self-contained; output is resource identities/waves.
set -euo pipefail
if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
  echo 'usage: syncwave-plan.sh <service-dir>' >&2
  exit 2
fi
command -v python3 >/dev/null 2>&1 || { echo 'FAIL python3 missing -- install Python 3'; exit 1; }
python3 - "$1" <<'PY'
import os, sys, subprocess, shutil, re
from pathlib import Path
try:
    import yaml
except ImportError:
    print('FAIL PyYAML missing -- install PyYAML for Python 3')
    sys.exit(1)
root = Path(sys.argv[1]).resolve()
annotation = 'argocd.argoproj.io/'
failed = False

def safe(value):
    # Only names/namespace/kind/waves are emitted, never spec data or exception text.
    value = str(value)
    return value if re.fullmatch(r'[A-Za-z0-9_.:/<>-]+', value) else '(invalid-name)'

def load(path):
    return [d for d in yaml.safe_load_all(path.read_text()) if isinstance(d, dict)]

def fallback(directory, seen=None):
    seen = set() if seen is None else seen
    directory = directory.resolve()
    if directory in seen:
        raise ValueError('cyclic resource reference')
    seen.add(directory)
    kfile = next((directory/n for n in ('kustomization.yaml', 'kustomization.yml', 'Kustomization')
                  if (directory/n).is_file()), None)
    docs = []
    if kfile:
        config = load(kfile)[0]
        for name in config.get('resources', []) + config.get('bases', []):
            resource = directory / name
            if resource.is_dir():
                docs += fallback(resource, seen)
            else:
                docs += load(resource)
        if any(config.get(k) for k in ('patches', 'patchesStrategicMerge', 'configMapGenerator',
                                      'secretGenerator', 'components', 'transformers')):
            print('SKIP fallback transformations: patches/generators/components require kubectl render')
        namespace = config.get('namespace')
        if namespace:
            for doc in docs:
                metadata = doc.setdefault('metadata', {})
                if doc.get('kind') == 'Namespace':
                    metadata['name'] = namespace
                elif doc.get('kind') not in ('ClusterRole', 'ClusterRoleBinding', 'CustomResourceDefinition'):
                    metadata['namespace'] = namespace
    else:
        for path in sorted(directory.rglob('*')):
            if path.suffix in ('.yaml', '.yml'):
                docs += load(path)
    seen.remove(directory)
    return docs

kubectl = os.environ.get('KUBECTL_BIN', 'kubectl')
try:
    if shutil.which(kubectl):
        result = subprocess.run([kubectl, 'kustomize', str(root), '--load-restrictor',
                                 'LoadRestrictionsNone'], capture_output=True, text=True, timeout=60)
        if result.returncode:
            print('FAIL local kustomize render -- fix resources/patches; tool output suppressed')
            sys.exit(1)
        docs = [d for d in yaml.safe_load_all(result.stdout) if isinstance(d, dict)]
        print('OK local kubectl kustomize render')
    else:
        print('SKIP kubectl absent: parsing local YAML; full render still required before commit')
        docs = fallback(root)
except Exception:
    print('FAIL resource parsing/render timeout -- fix YAML/references; values suppressed')
    sys.exit(1)
expanded = []
for doc in docs:
    expanded.extend(doc.get('items', []) if doc.get('kind') == 'List' else [doc])
docs = [d for d in expanded if isinstance(d, dict) and d.get('kind') != 'Kustomization']

classes = {
    'Namespace': (0, 'prerequisite'), 'ServiceAccount': (0, 'prerequisite'),
    'ConfigMap': (10, 'configuration'), 'SealedSecret': (10, 'configuration'),
    'PersistentVolumeClaim': (20, 'storage'),
    'Deployment': (40, 'workload'), 'StatefulSet': (40, 'workload'),
    'DaemonSet': (40, 'workload'), 'ReplicaSet': (40, 'workload'),
    'Pod': (40, 'workload'), 'Job': (40, 'workload'), 'CronJob': (40, 'workload'),
    'Service': (50, 'network'), 'Certificate': (50, 'network'), 'IngressRoute': (50, 'network'),
    'Ingress': (50, 'network'), 'AuthorizationPolicy': (50, 'network'), 'NetworkPolicy': (50, 'network')}
resources = []
print('| Resource | Namespace | Existing wave | Proposed wave | Dependency class |')
print('| --- | --- | --- | --- | --- |')
for doc in docs:
    kind = doc.get('kind', '')
    meta = doc.get('metadata', {}) or {}
    annotations = meta.get('annotations', {}) or {}
    name = meta.get('name', meta.get('generateName', '(unnamed)'))
    ns = meta.get('namespace', 'default')
    label = safe(kind) + '/' + safe(name)
    wave = annotations.get(annotation+'sync-wave')
    try:
        current = int(wave) if wave is not None else None
    except (ValueError, TypeError):
        current = None
        print(f'FAIL {label} invalid sync-wave -- set an integer wave')
        failed = True
    proposed, cls = classes.get(kind, (None, 'unclassified'))
    hooks = str(annotations.get(annotation+'hook', '')).split(',')
    if kind == 'Job' and 'PreSync' in hooks:
        proposed, cls = 30, 'pre-sync-hook'
        print(f'WAIT {label} PreSync phase precedes Sync resources: review config/PVC phase dependencies')
    elif kind == 'Job' and 'PostSync' in hooks:
        proposed, cls = 60, 'post-sync-hook'
    if kind == 'Secret':
        print(f'FAIL {label} plaintext Secret -- use seal-secret; never track plaintext')
        failed = True
    if wave is None:
        print(f'WAIT {label} has no wave -- review and annotate the proposed dependency wave')
    if proposed is None:
        print(f'WAIT {label} unknown dependency class -- derive it explicitly')
    if 'BeforeHookCreation' in str(annotations.get(annotation+'hook-delete-policy', '')).split(','):
        print(f'WAIT {label} BeforeHookCreation: failed hooks replaced only on next sync; see ship force-resync')
    print(f'| {label} | {safe(ns)} | {current if current is not None else "missing"} | {proposed if proposed is not None else "review"} | {cls} |')
    resources.append((doc, current, proposed, ns, label))
    if kind == 'StatefulSet':
        for claim in doc.get('spec', {}).get('volumeClaimTemplates', []):
            cname = safe(claim.get('metadata', {}).get('name', '(unnamed)'))
            print(f'| volumeClaimTemplate/{cname} | {safe(ns)} | workload-managed | 20 | storage (created by StatefulSet) |')
        if doc.get('spec', {}).get('volumeClaimTemplates'):
            print(f'WAIT {label} volume claims are controller-created: review binding mode, not independent Argo waves')

pvcs = {(ns, doc.get('metadata', {}).get('name')): (wave, proposed, label)
        for doc, wave, proposed, ns, label in resources if doc.get('kind') == 'PersistentVolumeClaim'}
for doc, wave, proposed, ns, label in resources:
    kind = doc.get('kind')
    if kind not in ('Deployment', 'StatefulSet', 'DaemonSet', 'ReplicaSet', 'Job', 'CronJob', 'Pod'):
        continue
    spec = doc.get('spec', {})
    if kind == 'CronJob':
        spec = spec.get('jobTemplate', {}).get('spec', {})
    pod = spec if kind == 'Pod' else spec.get('template', {}).get('spec', {})
    for volume in pod.get('volumes', []):
        claim = volume.get('persistentVolumeClaim', {}).get('claimName')
        if not claim:
            continue
        pvc = pvcs.get((ns, claim))
        if not pvc:
            print(f'WAIT {label} PVC reference unresolved -- confirm external claim exists in namespace')
            continue
        storage_wave, storage_proposed, storage_label = pvc
        if storage_wave is not None and wave is not None and storage_wave > wave:
            print(f'FAIL deadlock {storage_label} wave {storage_wave} later than {label} wave {wave} -- move PVC before its workload')
            failed = True
        elif storage_wave is not None and wave is not None and storage_wave == wave:
            print(f'WAIT {label} PVC shares workload wave -- review ordering and binding mode')

# Comparison is local and read-only. Infer manifest root from the service/overlay path.
comparison = os.environ.get('ROX_MANIFEST_DIR')
manifest = Path(comparison).resolve() if comparison else next(
    (p for p in [root] + list(root.parents) if (p/'services').is_dir() and (p/'clusters/rum').is_dir()), None)
print('| Existing service comparison (read-only) | Wave |')
print('| --- | --- |')
count = 0
if manifest:
    for area in (manifest/'services', manifest/'clusters/rum'):
        for path in sorted(area.rglob('*.yaml')):
            if root == path.parent or root in path.parents:
                continue
            try:
                for doc in load(path):
                    meta = doc.get('metadata', {}) or {}
                    wave = (meta.get('annotations', {}) or {}).get(annotation+'sync-wave')
                    if wave is not None:
                        print(f'| {safe(str(path.relative_to(manifest)))}/{safe(doc.get("kind", ""))}/{safe(meta.get("name", ""))} | {safe(wave)} |')
                        count += 1
            except Exception:
                print('SKIP comparison YAML unreadable: values suppressed')
    if not count:
        print('SKIP existing comparison: no annotated waves found')
else:
    print('SKIP existing comparison: manifest root not found; set ROX_MANIFEST_DIR')
if not docs:
    print('FAIL no resources -- supply a service base or overlay')
    failed = True
print('FAIL wave plan -- resolve flags before scaffold approval' if failed else
      'OK wave plan has no deadlock; resolve WAIT/SKIP items before commit')
sys.exit(1 if failed else 0)
PY
