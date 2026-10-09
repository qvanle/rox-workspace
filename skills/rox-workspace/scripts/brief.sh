#!/usr/bin/env bash
# rox-workspace role brief. Usage: brief.sh <role[,role...]> [--domain product]
# Prints the starting view for the given roles as small tables: at most 15 rows per item, "nothing waiting" for an empty item,
# "SKIP <item>: <why>" for an item that cannot run. Each item runs once even if several roles use it. Exit 2 on bad usage, else 0.
# Overrides (also used by tests with fake binaries): ROXCTL_BIN.
# Needs: roxctl, jq.

domain=product
roles=""
while [ $# -gt 0 ]; do
  case "$1" in
    --domain) [ $# -ge 2 ] || { echo "usage: brief.sh <role[,role...]> [--domain product]" >&2; exit 2; }; domain="$2"; shift 2 ;;
    -*) echo "usage: brief.sh <role[,role...]> [--domain product]" >&2; exit 2 ;;
    *) roles="$roles ${1//,/ }"; shift ;;
  esac
done
[ -n "$roles" ] || { echo "usage: brief.sh <role[,role...]> [--domain product]" >&2; exit 2; }
[ "$domain" = product ] || { echo "SKIP domain: only 'product' has roles ($domain is planned)"; exit 0; }

roxctl_bin="${ROXCTL_BIN:-roxctl}"
command -v "$roxctl_bin" >/dev/null 2>&1 || { echo "SKIP brief: roxctl not on PATH"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "SKIP brief: jq not found -- brew install jq"; exit 0; }

max=15
rx() { "$roxctl_bin" workspace "$@" 2>/dev/null; }

items_for() {
  case "$1" in
    po) echo "stale drafts backlog label:needs-decision label:needs-info" ;;
    pm) echo "cycle backlog label:blocked stale" ;;
    des) echo "label:needs-design stale" ;;
    sr-se) echo "bucket:To_do bucket:Specifying bucket:Implementing bucket:Review" ;;
    jr-se | entry-se) echo "bucket:Specifying bucket:Implementing" ;;  # Jr: spec-approved/own-task filtering is the agent's job (se.md tier jr); the brief lists candidates
    ba) echo "" ;;  # ba works only on the questions it is handed
    sa) echo "label:area:infra label:blocked stale" ;;
    qa) echo "specs-no-test-plan bucket:Specifying" ;;
    qc) echo "bucket:Review" ;;
    *) echo "" ;;
  esac
}

items=""
for r in $roles; do
  case "$r" in
    po | pm | ba | des | sr-se | jr-se | entry-se | sa | qa | qc) ;;
    *) echo "SKIP role: unknown id '$r'" ; continue ;;
  esac
  for i in $(items_for "$r"); do
    case " $items " in *" $i "*) ;; *) items="$items $i" ;; esac
  done
done

# --- shared lookups, fetched lazily and once ---
projects_json=""
load_projects() {
  [ -n "$projects_json" ] && return 0
  projects_json="$(rx --json pma project list)"
  [ -n "$projects_json" ] && echo "$projects_json" | jq -e 'type=="array"' >/dev/null 2>&1
}
project_id() { # $1 = exact title, optional $2 = parent id
  echo "$projects_json" | jq -r --arg t "$1" --argjson p "${2:-null}" \
    '[.[] | select(.title==$t and (.is_archived|not) and ($p==null or .parent_project_id==$p))][0].id // empty'
}
# Layout: Product / {Backlog (strategy), <tactic> / {Backlog, <YYMMDD-sprint>}}. Both helpers print one "id<TAB>title<TAB>tactic" line per project.
open_sprints() { # non-archived non-Backlog children of every tactic project under Product, oldest first
  local prod
  prod="$(project_id Product)"
  [ -n "$prod" ] || return 1
  echo "$projects_json" | jq -r --argjson p "$prod" '
    . as $all | [$all[] | select(.parent_project_id==$p and (.is_archived|not))] as $tac
    | [ $all[] | select(.title!="Backlog" and (.is_archived|not)) as $s
        | $tac[] | select(.id==$s.parent_project_id) | {id:$s.id, title:$s.title, tactic:.title} ]
    | sort_by(.title)[] | "\(.id)\t\(.title)\t\(.tactic)"'
}
backlogs() { # the domain Backlog (the strategy backlog) first, then the Backlog project of every tactic under Product
  local prod
  prod="$(project_id Product)"
  [ -n "$prod" ] || return 1
  echo "$projects_json" | jq -r --argjson p "$prod" '
    . as $all | [$all[] | select(.parent_project_id==$p and (.is_archived|not))] as $tac
    | [ $all[] | select(.title=="Backlog" and (.is_archived|not) and .parent_project_id==$p) | {id:.id, tactic:"Strategy", k:0} ] as $strat
    | [ $all[] | select(.title=="Backlog" and (.is_archived|not)) as $b
        | $tac[] | select(.id==$b.parent_project_id) | {id:$b.id, tactic:.title, k:1} ] as $tb
    | ($strat + ($tb | sort_by(.tactic)))[] | "\(.id)\tBacklog\t\(.tactic)"'
}
# tasks of a project as TSV: id, title, done, bucket name, labels
tasks_tsv() { # $1 = project id
  local buckets tasks
  buckets="$(rx --json pma "$1" bucket ls)"
  tasks="$(rx --json pma "$1" list)"
  [ -n "$tasks" ] || return 1
  jq -r --argjson b "${buckets:-[]}" '
    ($b | map({key:(.id|tostring), value:.title}) | from_entries) as $bn
    | .[] | select(.done|not)
    | [.id, .title, (.done|tostring), ($bn[(.bucket_id // 0)|tostring] // "?"), ([.labels[]?.title] | join(","))] | @tsv' <<<"$tasks"
}
print_tasks() { # stdin TSV -> table, capped
  local rows total
  rows="$(cat)"; total="$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
  echo "| id | title | bucket | labels |"; echo "| --- | --- | --- | --- |"
  printf '%s\n' "$rows" | head -n "$max" | while IFS=$'\t' read -r id title _ bucket labels; do echo "| #$id | $title | $bucket | $labels |"; done
  [ "$total" -gt "$max" ] && echo "... and $((total - max)) more"
  return 0
}
need_projects() { load_projects || { echo "SKIP $1: pma unreachable"; return 1; }; }

item_stale() {
  local out
  out="$(rx --json wiki stale)" || true
  [ -n "$out" ] && echo "$out" | jq -e . >/dev/null 2>&1 || { echo "SKIP stale: wiki unreachable"; return; }
  local n; n="$(echo "$out" | jq '.stale | length')"
  if [ "$n" -eq 0 ]; then echo "nothing waiting"
  else
    echo "| document | level | end | updated | reason |"; echo "| --- | --- | --- | --- | --- |"
    echo "$out" | jq -r --argjson m "$max" '.stale[:$m][] | "| \(.title // .name // "?") | \(.level // "") | \(.end // "") | \(.updated // "") | \((.reasons // [] | join(", "))) |"'
    [ "$n" -gt "$max" ] && echo "... and $((n - max)) more"
  fi
  echo "(documents with no header: $(echo "$out" | jq '.no_metadata // 0'))"
}
item_drafts() { echo "SKIP drafts: needs 'roxctl workspace wiki stale --status draft' (not built yet)"; }
item_backlog() {
  need_projects backlog || return
  local bls line id tactic rows any="" failed=""
  bls="$(backlogs)" || bls=""
  [ -n "$bls" ] || { echo "SKIP backlog: no Backlog project under Product or one of its tactics"; return; }
  while IFS=$'\t' read -r id _ tactic; do
    rows="$(tasks_tsv "$id")" || { echo "SKIP backlog $tactic: cannot list tasks"; failed=1; continue; }
    [ -n "$rows" ] || continue
    any=1; echo "Backlog: $tactic (project #$id)"
    echo "$rows" | print_tasks
  done <<<"$bls"
  [ -n "$any" ] || [ -n "$failed" ] || echo "nothing waiting"
}
item_cycle() {
  need_projects cycle || return
  local sps id title tactic rows any=""
  sps="$(open_sprints)" || sps=""
  [ -n "$sps" ] || { echo "SKIP cycle: no open sprint project under a tactic of Product"; return; }
  while IFS=$'\t' read -r id title tactic; do
    echo "Sprint: $title, tactic $tactic (project #$id)"
    rows="$(tasks_tsv "$id")" || { echo "SKIP cycle $title: cannot list tasks"; continue; }
    [ -n "$rows" ] || { echo "nothing waiting"; continue; }
    echo "$rows" | print_tasks
  done <<<"$sps"
}
sprint_and_backlog_rows() {
  local ids id found="" rows
  ids="$( { backlogs; open_sprints; } 2>/dev/null | cut -f1)"
  [ -n "$ids" ] || return 1
  for id in $ids; do
    rows="$(tasks_tsv "$id")" || return 1
    [ -n "$rows" ] && printf '%s\n' "$rows"
  done
  return 0
}
item_bucket() { # $1 = bucket name (underscore for space), over every open sprint
  need_projects "bucket:$1" || return
  local name="${1//_/ }" sps id rows all=""
  sps="$(open_sprints)" || sps=""
  [ -n "$sps" ] || { echo "SKIP bucket:$name: no open sprint project under a tactic of Product"; return; }
  while IFS=$'\t' read -r id _ _; do
    rows="$(tasks_tsv "$id")" || { echo "SKIP bucket:$name: cannot list tasks"; return; }
    [ -n "$rows" ] && all="$all$rows"$'\n'
  done <<<"$sps"
  rows="$(printf '%s' "$all" | awk -F'\t' -v b="$name" '$4==b')"
  [ -n "$rows" ] || { echo "nothing waiting"; return; }
  echo "$rows" | print_tasks
}
item_label() { # $1 = label title
  need_projects "label:$1" || return
  local rows
  rows="$(sprint_and_backlog_rows)" || { echo "SKIP label:$1: cannot list tasks"; return; }
  rows="$(printf '%s\n' "$rows" | awk -F'\t' -v l="$1" '{n=split($5,a,","); for(i=1;i<=n;i++) if(a[i]==l){print; break}}')"
  [ -n "$rows" ] || { echo "nothing waiting"; return; }
  echo "$rows" | print_tasks
}
item_specs_no_test_plan() {
  [ -d docs/specs ] || { echo "SKIP specs-no-test-plan: no docs/specs in $(pwd)"; return; }
  local f any=""
  for f in docs/specs/*.md; do
    [ -e "$f" ] || continue
    grep -q '^Requirement:' "$f" || continue
    # the test plan section = from a "test plan" heading to the next heading; it must cite an R-id
    if ! awk 'tolower($0) ~ /^#+ .*test plan/ {inp=1; next} /^#+ / {inp=0} inp && /(^|[^A-Za-z0-9])R[0-9]+([^0-9]|$)/ {found=1} END {exit !found}' "$f"; then
      [ -n "$any" ] || { echo "| spec lacking a test plan that cites R-ids |"; echo "| --- |"; any=1; }
      printf '| %s |\n' "$f"
    fi
  done
  [ -n "$any" ] || echo "nothing waiting"
}

for i in $items; do
  echo "## $i"
  case "$i" in
    stale) item_stale ;;
    drafts) item_drafts ;;
    backlog) item_backlog ;;
    cycle) item_cycle ;;
    bucket:*) item_bucket "${i#bucket:}" ;;
    label:*) item_label "${i#label:}" ;;
    specs-no-test-plan) item_specs_no_test_plan ;;
  esac
done
exit 0
