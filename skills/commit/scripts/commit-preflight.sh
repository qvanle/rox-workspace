#!/usr/bin/env bash
# Read-only preflight (manifest's existing npm check is also run). No fetch/stage/commit.
# Overrides for tests: GIT_BIN, NPM_BIN.
set -uo pipefail
usage() { echo 'usage: commit-preflight.sh [--repo PATH]' >&2; exit 2; }
repo=.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) [ "$#" -ge 2 ] && [ -n "$2" ] || usage; repo=$2; shift 2 ;;
    *) usage ;;
  esac
done
git_bin=${GIT_BIN:-git}
npm_bin=${NPM_BIN:-npm}
rc=0
fail() { printf 'FAIL %s: %s -- %s\n' "$1" "$2" "$3"; rc=1; }
command -v "$git_bin" >/dev/null 2>&1 || { fail git 'not found' 'install git'; exit 1; }
g() { "$git_bin" -C "$repo" "$@"; }
top=$(g rev-parse --show-toplevel 2>/dev/null) || { fail repo 'not a working repository' 'pass --repo PATH'; exit 1; }
repo=$top
branch=$(g symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=DETACHED
printf '| repo | branch |\n| --- | --- |\n| %s | %s |\n' "$top" "$branch"
echo '| remote | ahead | behind (cached refs; no fetch) |'
echo '| --- | --- | --- |'
behind_failed=0
while IFS= read -r remote; do
  [ -n "$remote" ] || continue
  ref="refs/remotes/$remote/main"
  upstream=$(g rev-parse --symbolic-full-name '@{upstream}' 2>/dev/null) || upstream=
  case "$upstream" in "refs/remotes/$remote/"*) ref=$upstream ;; esac
  if counts=$(g rev-list --left-right --count "HEAD...$ref" 2>/dev/null); then
    read -r ahead behind <<< "$counts"
    printf '| %s | %s | %s |\n' "$remote" "$ahead" "$behind"
    if [ "$behind" -gt 0 ]; then
      fail behind "$remote has $behind unseen commit(s)" 'review and pull/rebase explicitly before committing'
      behind_failed=1
    fi
  else
    printf '| %s | unknown | unknown |\n' "$remote"
  fi
done < <(g remote)
echo '| index/worktree status | path |'
echo '| --- | --- |'
while IFS= read -r -d '' entry; do
  printf '| %s | %s |\n' "${entry:0:2}" "${entry:3}"
  # --no-renames below keeps each porcelain entry one NUL-terminated record.
done < <(g -c status.relativePaths=false status --porcelain=v1 --no-renames -z)
subjects=$(g log -8 --format=%s 2>/dev/null) || subjects=
total=0; conventional=0
echo '| last 8 subjects |'
echo '| --- |'
while IFS= read -r subject; do
  [ -n "$subject" ] || continue
  total=$((total + 1))
  if [[ "$subject" =~ ^(feat|fix|chore|docs|ci|refactor|test)(\(.+\))?: ]]; then
    conventional=$((conventional + 1))
  fi
  # Legacy subjects can themselves contain credentials; redact the whole subject.
  if printf '%s\n' "$subject" | LC_ALL=C grep -Eiq '(ghp_|glpat-|AKIA|password[[:space:]]*=|PRIVATE KEY)'; then
    echo '| [redacted credential-like subject] |'
  else
    printf '| %s |\n' "$subject"
  fi
done <<< "$subjects"
if [ "$conventional" -gt $((total / 2)) ]; then echo 'STYLE conventional'; else echo 'STYLE plain'; fi
if [ "$branch" = main ]; then echo 'OK branch main'; else fail branch "$branch is not main; work stays local" 'ask how to move the work to main; pushes are main only'; fi

secret_failed=0
scan() { # stdin contains additions or a new file; never emit its contents.
  local path=$1 content rule pattern
  content=$(LC_ALL=C tr -d '\000')
  case "${path##*/}" in
    .env|.env.*|*.env) fail secrets "$path [env-file]" 'remove from the index and store secrets outside git'; secret_failed=1 ;;
  esac
  while IFS='|' read -r rule pattern; do
    if printf '%s\n' "$content" | LC_ALL=C grep -Eq -- "$pattern"; then
      fail secrets "$path [$rule]" 'remove plaintext secrets; use SealedSecrets or an external secret store'
      secret_failed=1
    fi
  done <<'RULES'
plaintext-secret|^[[:space:]]*kind:[[:space:]]*["']?Secret["']?([[:space:]]|#|$)
private-key|-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY-----
github-token|ghp_[A-Za-z0-9]+
gitlab-token|glpat-[A-Za-z0-9_-]+
aws-access-key|AKIA[A-Z0-9]{16}
password-assignment|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][[:space:]]*=
RULES
}
# Added lines only for text edits: removing a secret is allowed. Scan new blobs whole,
# including files Git considers binary; binary edits also need a whole-blob scan.
while IFS= read -r -d '' path; do
  # Gitlinks and deletions have no blob to scan.
  mode=$(g ls-files --stage -- "$path")
  case "$mode" in 160000*|'') continue ;; esac
  change=$(g diff --cached --no-renames --name-status -- "$path")
  diff_content=$(g diff --cached --no-ext-diff --no-textconv --no-renames --unified=0 -- "$path")
  if [[ "$change" = A$'\t'* ]] || [[ "$diff_content" = *$'\nBinary files '* ]]; then
    scan "$path" < <(g cat-file blob ":$path")
  else
    # Only lines inside hunks are additions; the file header (+++ b/path) comes before the first @@.
    scan "$path" < <(printf '%s\n' "$diff_content" | awk '/^diff --git/ {h=0; next} /^@@/ {h=1; next} h && /^\+/ {print substr($0, 2)}')
  fi
done < <(g diff --cached --no-renames --name-only --diff-filter=ACMRT -z)
while IFS= read -r -d '' path; do
  if [ -f "$repo/$path" ]; then scan "$path" < "$repo/$path"; fi
done < <(g ls-files --others --exclude-standard -z)

if [ "${top##*/}" = manifest ]; then
  hook_path=$(g config --get core.hooksPath) || hook_path=$(g rev-parse --git-path hooks)
  case "$hook_path" in /*) ;; *) hook_path="$repo/$hook_path" ;; esac
  if [ -x "$hook_path/pre-commit" ] && [ -x "$hook_path/pre-push" ]; then
    echo 'OK hooks manifest pre-commit and pre-push'
  else
    fail hooks 'manifest Husky hooks absent or not executable' 'run npm install in manifest to install Husky hooks'
  fi
  if ! command -v "$npm_bin" >/dev/null 2>&1; then
    fail secrets 'manifest npm check unavailable' 'install npm and run npm install in manifest'
    secret_failed=1
  elif ! (cd "$repo" && "$npm_bin" run check:unsealed-secrets >/dev/null 2>&1); then
    fail secrets 'manifest check:unsealed-secrets failed (output suppressed)' 'run the check privately and remove unsealed secrets'
    secret_failed=1
  fi
else
  echo 'OK hooks not required outside manifest'
fi
[ "$secret_failed" -ne 0 ] || echo 'OK secrets'
[ "$behind_failed" -ne 0 ] || echo 'OK behind cached remote refs (unknown refs require an explicit fetch before review)'
if [ -z "$(g status --porcelain=v1)" ]; then fail nothing 'nothing to commit' 'make or stage the intended change'; else echo 'OK nothing changes available'; fi
exit "$rc"
