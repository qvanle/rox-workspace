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

# --- pma layout: Product / <tactic> / {Backlog, <YYMMDD-sprint>} (fake pma, two tactics) ---
fake="$tmp/pma-roxctl"
cat > "$fake" <<'EOF2'
#!/usr/bin/env bash
case "$*" in
  *"pma project list"*) echo '[{"id":3,"title":"Product","parent_project_id":0,"is_archived":false},{"id":4,"title":"Backlog","parent_project_id":3,"is_archived":false},{"id":5,"title":"Alpha","parent_project_id":3,"is_archived":false},{"id":6,"title":"Backlog","parent_project_id":5,"is_archived":false},{"id":7,"title":"261012-alpha-sprint","parent_project_id":5,"is_archived":false},{"id":8,"title":"Beta","parent_project_id":3,"is_archived":false},{"id":9,"title":"Backlog","parent_project_id":8,"is_archived":false},{"id":10,"title":"261005-old","parent_project_id":8,"is_archived":true}]' ;;
  *"pma 6 bucket ls"* | *"pma 7 bucket ls"* | *"pma 9 bucket ls"*) echo '[{"id":1,"title":"Idea"},{"id":2,"title":"Review"}]' ;;
  *"pma 4 bucket ls"*) echo '[{"id":1,"title":"Idea"}]' ;;
  *"pma 4 list"*) echo '[{"id":13,"title":"strategy item","done":false,"bucket_id":1,"labels":[]}]' ;;
  *"pma 6 list"*) echo '[{"id":11,"title":"alpha task","done":false,"bucket_id":1,"labels":[{"title":"needs-info"}]}]' ;;
  *"pma 7 list"*) echo '[{"id":12,"title":"in review","done":false,"bucket_id":2,"labels":[]}]' ;;
  *"pma 9 list"*) echo '[]' ;;
  *) exit 1 ;;
esac
EOF2
chmod +x "$fake"
out="$(ROXCTL_BIN="$fake" bash "$brief" po 2>&1)"
check "backlog names the tactic" "$(printf '%s' "$out" | grep -q 'Backlog: Alpha (project #6)' && echo ok)"
check "strategy backlog lists first" "$(printf '%s' "$out" | grep -n 'Backlog:' | head -1 | grep -q 'Strategy' && echo ok)"
check "backlog lists the task" "$(printf '%s' "$out" | grep -q 'alpha task' && echo ok)"
check "domain Backlog is the strategy backlog" "$(printf '%s' "$out" | grep -q 'Backlog: Strategy (project #4)' && echo ok)"
check "empty backlog is not printed" "$(printf '%s' "$out" | grep -q 'Beta' && echo no || echo ok)"
check "label filter spans backlogs" "$(printf '%s' "$out" | sed -n '/## label:needs-info/,/## /p' | grep -q 'alpha task' && echo ok)"
out="$(ROXCTL_BIN="$fake" bash "$brief" pm 2>&1)"
check "cycle names sprint and tactic" "$(printf '%s' "$out" | grep -q 'Sprint: 261012-alpha-sprint, tactic Alpha (project #7)' && echo ok)"
check "archived sprint is skipped" "$(printf '%s' "$out" | grep -q '261005-old' && echo no || echo ok)"
out="$(ROXCTL_BIN="$fake" bash "$brief" qc 2>&1)"
check "bucket item reads open sprints" "$(printf '%s' "$out" | grep -q 'in review' && echo ok)"

echo "brief tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
