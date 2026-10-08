#!/usr/bin/env bash
# Fake roxctl only: no pma, wiki or cluster access.
set -u
[ $# -eq 0 ] || { echo 'usage: brief-tests.sh' >&2; exit 2; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
brief="$script_dir/../scripts/brief.sh"
command -v jq >/dev/null 2>&1 || { echo 'FAIL test dependencies: jq required -- brew install jq'; exit 1; }
tmp="$(mktemp -d)" || exit 1
trap 'rm -rf -- "$tmp"' EXIT
printf '#!/usr/bin/env bash\necho called >> "%s/calls"\nexit 1\n' "$tmp" > "$tmp/roxctl"; chmod +x "$tmp/roxctl"
export ROXCTL_BIN="$tmp/roxctl"
pass=0; fail=0
check() { # name, condition result
  if [ "$2" = ok ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1"; fi
}

out="$(bash "$brief" ba 2>&1)"; rc=$?
check "ba exits 0" "$([ "$rc" -eq 0 ] && echo ok)"
check "ba is a known role" "$(printf '%s' "$out" | grep -q "unknown id" && echo no || echo ok)"
check "ba has no items" "$([ -z "$out" ] && echo ok)"
check "ba never calls roxctl" "$([ ! -e "$tmp/calls" ] && echo ok)"

po="$(bash "$brief" po 2>&1)"
both="$(bash "$brief" po,ba 2>&1)"
check "po,ba prints the same as po" "$([ "$po" = "$both" ] && echo ok)"

out="$(bash "$brief" nobody 2>&1)"
check "unknown role is reported" "$(printf '%s' "$out" | grep -q "unknown id 'nobody'" && echo ok)"

echo "brief tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
