#!/usr/bin/env bash
# Key names only. Values stay in process memory, never argv or output.
set -euo pipefail
if [ "$#" -ne 2 ]; then
  echo 'usage: seal-diff.sh <env-file> <sealedsecret.yaml>' >&2
  exit 2
fi
command -v python3 >/dev/null 2>&1 || { echo 'FAIL python3 missing -- install Python 3'; exit 1; }
python3 - "$@" <<'PY'
import sys, re
from pathlib import Path
try:
    import yaml
except ImportError:
    print('FAIL PyYAML missing -- install PyYAML for Python 3')
    sys.exit(1)

def fail(what):
    print('FAIL ' + what + ' -- fix the source before sealing; values are suppressed')
    sys.exit(1)

source, target = map(Path, sys.argv[1:])
try:
    lines = source.read_text().splitlines()
except (OSError, UnicodeError):
    fail('env file unreadable')
keys = set()
for number, line in enumerate(lines, 1):
    if not line.strip() or line.lstrip().startswith('#'):
        continue
    if line.startswith('export '):
        line = line[7:]
    if '=' not in line:
        fail(f'env line {number} has no assignment')
    key, value = line.split('=', 1)
    if re.search(r'\s', key):
        fail(f'env line {number} has whitespace in key')
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', key):
        fail(f'env line {number} has an invalid key')
    if key in keys:
        fail(f'duplicate key {key}')
    # Dotenv-style literal quotes/comments; never evaluate shell expansion.
    value = '' if re.match(r'^\s+#', value) else value.strip()
    if value.startswith(('"', "'")):
        quote = value[0]
        end = -1
        escaped = False
        for index, char in enumerate(value[1:], 1):
            if char == quote and not escaped:
                end = index
                break
            escaped = char == '\\' and not escaped
        if end < 0 or (value[end+1:].strip() and not value[end+1:].lstrip().startswith('#')):
            fail(f'env line {number} has unsupported quoting')
        value = value[1:end]
    else:
        value = re.split(r'\s+#', value, maxsplit=1)[0].strip()
    if not value.strip():
        fail(f'empty value for key {key}')
    keys.add(key)
if not keys:
    fail('env file has no keys')

# Reject duplicate YAML mapping keys; parser exceptions can include values, so suppress them.
class UniqueLoader(yaml.SafeLoader):
    pass

def mapping(loader, node, deep=False):
    result = {}
    for k, v in node.value:
        key = loader.construct_object(k, deep=deep)
        if key in result:
            raise ValueError('duplicate mapping')
        result[key] = loader.construct_object(v, deep=deep)
    return result
UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)
old = set()
if target.exists():
    try:
        docs = list(yaml.load_all(target.read_text(), Loader=UniqueLoader))
        if len(docs) != 1 or not isinstance(docs[0], dict) or docs[0].get('kind') != 'SealedSecret':
            raise ValueError('wrong kind')
        encrypted = docs[0].get('spec', {}).get('encryptedData', {})
        if not isinstance(encrypted, dict):
            raise ValueError('wrong encryptedData')
        if any(not isinstance(k, str) or not re.fullmatch(r'[A-Za-z0-9_.-]+', k) for k in encrypted):
            raise ValueError('invalid key')
        old = set(encrypted)
    except Exception:
        fail('sealed file malformed, duplicate mapping or not a SealedSecret')
else:
    print('SKIP existing sealed file absent: first seal')
for label, names in [('Env keys', keys), ('Existing sealed keys', old),
                     ('Added', keys-old), ('Removed (orphan cleanup: confirm)', old-keys),
                     ('Unchanged', keys & old)]:
    print(f'| {label} |')
    print('| --- |')
    for name in sorted(names):
        print(f'| {name} |')
    if not names:
        print('| (none) |')
print('OK key-name diff; no values emitted')
PY
