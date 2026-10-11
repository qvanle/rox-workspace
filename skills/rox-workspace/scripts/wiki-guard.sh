#!/usr/bin/env bash
# Guard for wiki creation: a document must follow pillar -> strategy -> tactic -> plan -> cycle.
#   wiki-guard.sh check "<path>" [--collection C]   exit 0 = safe to `wiki create`, exit 1 = refuse (reason on stderr)
#   wiki-guard.sh next <level> [--collection C]     print the next free id for pillar|strategy|tactic|plan|cycle
# Titles come from `roxctl workspace wiki list`; ROX_GUARD_TITLES=<file> (one title per line) replaces that for tests.
set -u
levels=(Pillar Strategy Tactic Plan Cycle)
usage() { echo 'usage: wiki-guard.sh check "<path>" | next <level> [--collection C]' >&2; exit 2; }
[ $# -ge 2 ] || usage
cmd="$1"; arg="$2"; shift 2
col=()
if [ $# -ge 2 ] && [ "$1" = "--collection" ]; then col=(--collection "$2"); shift 2; fi
[ $# -eq 0 ] || usage
fail() { echo "REFUSED: $*" >&2; exit 1; }

titles() {
  if [ -n "${ROX_GUARD_TITLES:-}" ]; then cat -- "$ROX_GUARD_TITLES"; return; fi
  command -v roxctl >/dev/null || fail "roxctl not found; cannot list existing documents"
  command -v jq >/dev/null || fail "jq not found; cannot read the document list"
  local off=0 page n
  while [ "$off" -lt 5000 ]; do
    # roxctl appends a "(more results ...)" footer after the JSON; drop it
    page="$(roxctl --json workspace wiki ${col[@]+"${col[@]}"} list --limit 100 --offset "$off" 2>/dev/null | sed '/^(more results/d')" \
      || fail "roxctl could not list documents; fix it, do not create blind"
    n="$(printf '%s' "$page" | jq 'length' 2>/dev/null)" || fail "unreadable document list"
    [ "$n" -gt 0 ] || return 0
    printf '%s' "$page" | jq -r '.[].title'
    off=$((off + n))
  done
}

level_index() { # prints 0-4 for pillar..cycle (tactical = tactic), or nothing
  local want; want="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  [ "$want" = tactical ] && want=tactic
  local i
  for i in 0 1 2 3 4; do
    [ "$(printf '%s' "${levels[$i]}" | tr '[:upper:]' '[:lower:]')" = "$want" ] && { echo "$i"; return; }
  done
}

case "$cmd" in
  next)
    idx="$(level_index "$arg")"; [ -n "$idx" ] || fail "unknown level '$arg' (pillar, strategy, tactic, plan, cycle)"
    prefix="${levels[$idx]}"
    max="$(titles | sed -n "s/^$prefix \([0-9][0-9]*\): .*/\1/p" | sort -n | tail -1)"
    echo $(( ${max:-0} + 1 ))
    ;;
  check)
    path="$arg"
    [ -n "$path" ] || fail "empty path"
    all="$(titles)" || exit 1
    # a lone vision title is the one allowed unprefixed root
    case "$path" in
      "Product Vision: "*) case "$path" in */*) fail "the vision is a root document, no parent path" ;; esac
        printf '%s\n' "$all" | grep -Fxq -- "$path" && fail "'$path' already exists"; exit 0 ;;
    esac
    IFS='/' read -r -a segs <<< "$path"
    [ "${#segs[@]}" -le 5 ] || fail "too deep: the chain is pillar, strategy, tactic, plan, cycle"
    leaf=$(( ${#segs[@]} - 1 ))
    for i in "${!segs[@]}"; do
      seg="${segs[$i]}"
      [ -n "$seg" ] || fail "empty segment in '$path'"
      want="${levels[$i]}"
      printf '%s' "$seg" | grep -Eq "^$want [0-9]+: .+" \
        || fail "segment $((i+1)) '$seg' must be '$want <id>: <name>' ($want is level $((i+1)) of the chain; a decision or reference is a section, not a document)"
      if [ "$i" -lt "$leaf" ]; then
        printf '%s\n' "$all" | grep -Fxq -- "$seg" \
          || fail "ancestor '$seg' does not exist; create the chain top-down, roxctl would invent a stub"
      fi
    done
    leaf_title="${segs[$leaf]}"
    printf '%s\n' "$all" | grep -Fxq -- "$leaf_title" && fail "'$leaf_title' already exists"
    id="$(printf '%s' "$leaf_title" | sed -n "s/^${levels[$leaf]} \([0-9][0-9]*\): .*/\1/p")"
    printf '%s\n' "$all" | grep -Eq "^${levels[$leaf]} $id: " && fail "${levels[$leaf]} id $id is already used; take 'next ${levels[$leaf]}'"
    echo "OK $path"
    ;;
  *) usage ;;
esac
