#!/usr/bin/env bash
# Verify every cited playbook against a local checkout; never runs a playbook.
# Usage: run-tests.sh; override AOS_ROOT to test another checkout.
[ $# -eq 0 ] || { echo 'usage: run-tests.sh' >&2; exit 2; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
aos_root="${AOS_ROOT:-/Users/qvanle/projects/personal/rotexai/v3.0.0/aos}"
if [ ! -d "$aos_root/IaC/playbooks" ]; then
  echo 'SKIP diagnose paths: AOS_ROOT checkout absent -- set AOS_ROOT to a local aos checkout'
  exit 0
fi
# Extract each complete path, including several paths in one table cell.
paths="$(awk '{line=$0; while (match(line, /IaC\/playbooks\/[A-Za-z0-9_.\/-]+\.yml/)) {print substr(line,RSTART,RLENGTH); line=substr(line,RSTART+RLENGTH)}}' "$script_dir/../references/symptoms.md" | sort -u)"
[ -n "$paths" ] || { echo 'FAIL diagnose paths: no playbook claims -- restore the symptom table'; exit 1; }
passed=0
failed=0
while IFS= read -r path; do
  if [ -f "$aos_root/$path" ]; then
    echo "OK $path"
    passed=$((passed + 1))
  else
    echo "FAIL $path: missing -- correct the symptom reference or AOS_ROOT"
    failed=$((failed + 1))
  fi
done <<< "$paths"
echo "diagnose tests: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
