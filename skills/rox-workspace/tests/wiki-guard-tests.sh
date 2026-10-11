#!/usr/bin/env bash
set -u
[ $# -eq 0 ] || { echo 'usage: wiki-guard-tests.sh' >&2; exit 2; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
guard="$script_dir/../scripts/wiki-guard.sh"
tmp="$(mktemp -d)" || exit 1
trap 'rm -rf -- "$tmp"' EXIT
cat > "$tmp/titles" <<'T'
Product Vision: Beyond the Black-Box Backend
Pillar 1: Radical Accessibility
Pillar 2: Cost Leadership
Strategy 1: Owner-readable execution
Tactic 3: Execution Trace
Plan 2: Trace viewer v1
Decisions
Cycles
T
export ROX_GUARD_TITLES="$tmp/titles"
passed=0; failed=0
expect() { # expect <exit> <label> <args...>
  local want="$1" label="$2"; shift 2
  bash "$guard" "$@" > "$tmp/out" 2>&1; local got=$?
  if [ "$got" -eq "$want" ]; then echo "OK $label"; passed=$((passed+1)); else echo "FAIL $label (exit $got, wanted $want): $(cat "$tmp/out")"; failed=$((failed+1)); fi
}
P="Pillar 1: Radical Accessibility/Strategy 1: Owner-readable execution"
expect 0 "new pillar" check "Pillar 3: Fault Tolerance"
expect 0 "new strategy under existing pillar" check "Pillar 1: Radical Accessibility/Strategy 2: Fast feedback"
expect 0 "new cycle full chain" check "$P/Tactic 3: Execution Trace/Plan 2: Trace viewer v1/Cycle 7: 261012-trace-viewer"
expect 0 "lone vision" check "Product Vision: Another"
expect 1 "existing vision refused" check "Product Vision: Beyond the Black-Box Backend"
expect 1 "unprefixed title" check "Cycles/261012-trace-viewer"
expect 1 "decision as a document" check "$P/Tactic 3: Execution Trace/Decisions/261014-store"
expect 1 "missing prefix on leaf" check "Pillar 1: Radical Accessibility/Owner-readable"
expect 1 "level skipped" check "Pillar 1: Radical Accessibility/Tactic 9: Skip"
expect 1 "missing ancestor would be stubbed" check "Pillar 1: Radical Accessibility/Strategy 5: Nope/Tactic 9: X"
expect 1 "leaf exists" check "Pillar 1: Radical Accessibility"
expect 1 "id reused at the level" check "Pillar 1: Radical Accessibility/Strategy 1: Different name"
expect 1 "too deep" check "$P/Tactic 3: Execution Trace/Plan 2: Trace viewer v1/Cycle 7: a/Cycle 8: b"
expect 1 "empty segment" check "Pillar 1: Radical Accessibility//Strategy 2: X"
expect 1 "id missing" check "Pillar x: Name"
expect 1 "vision with a parent" check "Pillar 1: Radical Accessibility/Product Vision: X"
for pair in "pillar:3" "strategy:2" "tactic:4" "tactical:4" "plan:3" "cycle:1"; do
  lvl="${pair%%:*}"; want="${pair##*:}"
  bash "$guard" next "$lvl" > "$tmp/out" 2>&1
  if [ "$(cat "$tmp/out")" = "$want" ]; then echo "OK next $lvl = $want"; passed=$((passed+1)); else echo "FAIL next $lvl: $(cat "$tmp/out")"; failed=$((failed+1)); fi
done
expect 1 "next unknown level" next decision
expect 2 "usage" check
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
