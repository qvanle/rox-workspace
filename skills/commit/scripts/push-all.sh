#!/usr/bin/env bash
# Push exactly main to each remote; caller obtains approval. Overrides: GIT_BIN.
set -uo pipefail
usage() { echo 'usage: push-all.sh [--repo PATH] [--dry-run]' >&2; exit 2; }
repo=.; dry_run=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) [ "$#" -ge 2 ] && [ -n "$2" ] || usage; repo=$2; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    *) usage ;;
  esac
done
git_bin=${GIT_BIN:-git}
command -v "$git_bin" >/dev/null 2>&1 || { echo 'FAIL git: not found -- install git'; exit 1; }
g() { "$git_bin" -C "$repo" "$@"; }
g rev-parse --show-toplevel >/dev/null 2>&1 || { echo 'FAIL repo: not a working repository -- pass --repo PATH'; exit 1; }
branch=$(g symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=DETACHED
[ "$branch" = main ] || { echo 'FAIL branch: pushes are main only -- keep work local until it is on main'; exit 1; }
remotes=$(g remote)
[ -n "$remotes" ] || { echo 'SKIP push: no remote'; exit 0; }
new=$(g rev-parse --verify refs/heads/main 2>/dev/null) || { echo 'FAIL main: no commit -- commit the intended change first'; exit 1; }
tracked=$(g config --get branch.main.remote) || tracked=
ordered=()
while IFS= read -r remote; do
  [ "$remote" != "$tracked" ] || ordered+=("$remote")
done <<< "$remotes"
while IFS= read -r remote; do
  [ "$remote" = "$tracked" ] || [ "$remote" = internal ] || ordered+=("$remote")
done <<< "$remotes"
if [ "$tracked" != internal ] && printf '%s\n' "$remotes" | grep -qx internal; then ordered+=(internal); fi
rc=0; succeeded=0
for remote in "${ordered[@]}"; do
  reason=; olds=; destinations=()
  # Check the actual push URLs, including multiple pushurls, rather than the fetch URL.
  while IFS= read -r destination; do
    [ -z "$destination" ] || destinations+=("$destination")
  done < <(g remote get-url --push --all "$remote" 2>/dev/null)
  if [ "${#destinations[@]}" -eq 0 ]; then reason='no push destination'; fi
  for destination in "${destinations[@]}"; do
    if ! listing=$(g ls-remote --refs "$destination" refs/heads/main 2>/dev/null); then
      reason='cannot read remote main'; break
    fi
    old=${listing%%$'\t'*}; old=${old:-new-branch}
    olds="${olds:+$olds,}$old"
    # Explicit URL avoids remote mirror/default refspec config; disable implicit tags.
    if ! g -c push.followTags=false push --porcelain --dry-run -- "$destination" refs/heads/main:refs/heads/main >/dev/null 2>&1; then
      reason='fast-forward dry-run rejected or remote unavailable'; break
    fi
  done
  if [ -z "$reason" ] && [ "$dry_run" -eq 0 ]; then
    for destination in "${destinations[@]}"; do
      if ! g -c push.followTags=false push --porcelain -- "$destination" refs/heads/main:refs/heads/main >/dev/null 2>&1; then
        reason='push rejected; remote may remain behind (some push destinations may have succeeded)'; break
      fi
    done
  fi
  if [ -n "$reason" ]; then
    printf 'FAIL %s: %s -- inspect this remote before retrying\n' "$remote" "$reason"; rc=1
  else
    suffix=; [ "$dry_run" -eq 0 ] || suffix=' (dry-run)'
    printf 'OK %s %s..%s%s\n' "$remote" "$olds" "$new" "$suffix"
    succeeded=$((succeeded + 1))
  fi
done
if [ "$rc" -ne 0 ] && [ "$succeeded" -gt 0 ]; then echo 'WAIT push: partial failure; inspect the FAIL remote(s) before retrying'; fi
echo 'SKIP CI: run ship to follow the pipeline after an approved push'
exit "$rc"
