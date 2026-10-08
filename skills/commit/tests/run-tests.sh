#!/usr/bin/env bash
# Local-only integration tests. All staging/commits/pushes are in disposable repos.
set -uo pipefail
[ "$#" -eq 0 ] || { echo 'usage: run-tests.sh' >&2; exit 2; }
base=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_TERMINAL_PROMPT=0
git_bin=$(command -v git) || { echo 'FAIL prerequisite: git missing'; exit 1; }
export GIT_ALLOW_PROTOCOL=file
passed=0; failed=0; output=; result=0
ok() { echo "OK test: $1"; passed=$((passed + 1)); }
bad() { echo "FAIL test: $1"; failed=$((failed + 1)); }
run() { output=$("$@" 2>&1); result=$?; }
code() { if [ "$result" -eq "$2" ]; then ok "$1"; else bad "$1 (exit $result, expected $2)"; fi; }
contains() { if printf '%s\n' "$output" | grep -Eq -- "$2"; then ok "$1"; else bad "$1"; fi; }
absent() { if printf '%s\n' "$output" | grep -Fq -- "$2"; then bad "$1"; else ok "$1"; fi; }
init_repo() {
  "$git_bin" init -q -b main "$1" &&
    "$git_bin" -C "$1" config user.name 'Commit tests' &&
    "$git_bin" -C "$1" config user.email 'tests@example.invalid' &&
    "$git_bin" -C "$1" config commit.gpgSign false &&
    "$git_bin" -C "$1" config core.hooksPath "$tmp/no-hooks" &&
    "$git_bin" -C "$1" commit -q --allow-empty -m 'Initial fixture'
}
fixture() { "$@" >/dev/null 2>&1 || { echo 'FAIL fixture setup'; exit 1; }; }
repo="$tmp/repo"
fixture init_repo "$repo"
secret='fixture-sensitive-value-never-print'
printf 'kind: Secret\ndata:\n  token: %s\n' "$secret" > "$repo/secret.yaml"
fixture "$git_bin" -C "$repo" add -- secret.yaml
run bash "$base/scripts/commit-preflight.sh" --repo "$repo"
code 'staged plaintext Secret rejected' 1
contains 'secret file and rule identified' 'FAIL secrets: secret.yaml \[plaintext-secret\]'
absent 'secret value never printed' "$secret"
fixture "$git_bin" -C "$repo" reset -q -- secret.yaml
rm "$repo/secret.yaml"
printf 'kind: SealedSecret\n' > "$repo/sealed.yaml"
fixture "$git_bin" -C "$repo" add -- sealed.yaml
run bash "$base/scripts/commit-preflight.sh" --repo "$repo"
code 'SealedSecret allowed' 0
fixture "$git_bin" -C "$repo" commit -q -m 'feat(test): add sealed fixture'
fixture "$git_bin" -C "$repo" commit -q --allow-empty -m 'fix(test): improve fixture'
printf 'safe\n' > "$repo/change.txt"
run bash "$base/scripts/commit-preflight.sh" --repo "$repo"
contains 'majority of available eight subjects detects conventional' '^STYLE conventional$'
fixture "$git_bin" -C "$repo" switch -q -c feat/x
run bash "$base/scripts/commit-preflight.sh" --repo "$repo"
code 'preflight rejects non-main branch' 1
contains 'branch failure explained' '^FAIL branch:'
run bash "$base/scripts/push-all.sh" --repo "$repo"
code 'push-all rejects non-main branch' 1
fixture "$git_bin" -C "$repo" switch -q main
run bash "$base/scripts/push-all.sh" --repo "$repo"
code 'no remote succeeds' 0
contains 'no remote exact skip' '^SKIP push: no remote$'
rm "$repo/change.txt"
run bash "$base/scripts/commit-preflight.sh" --repo "$repo"
code 'clean repository fails nothing check' 1
contains 'nothing failure' '^FAIL nothing:'

# New untracked files and staged added lines are checked, removed secrets are allowed.
printf 'password=%s\n' "$secret" > "$repo/new.txt"
run bash "$base/scripts/commit-preflight.sh" --repo "$repo"
contains 'untracked password rejected' 'new.txt \[password-assignment\]'
absent 'untracked value suppressed' "$secret"
rm "$repo/new.txt"
printf 'plain\n' > "$repo/.env"
fixture "$git_bin" -C "$repo" add -- .env
run bash "$base/scripts/commit-preflight.sh" --repo "$repo"
contains 'staged env filename rejected' '\.env \[env-file\]'
# A modified line whose content starts with '++ ' must still be scanned (the diff header filter must not eat it).
fixture "$git_bin" -C "$repo" reset -q -- .env
printf 'base\n' > "$repo/plusplus.txt"
fixture "$git_bin" -C "$repo" add -- plusplus.txt
fixture "$git_bin" -C "$repo" -c user.name=t -c user.email=t@t commit -q -m base
printf 'base\n++ password=%s\n' "$secret" > "$repo/plusplus.txt"
fixture "$git_bin" -C "$repo" add -- plusplus.txt
run bash "$base/scripts/commit-preflight.sh" --repo "$repo"
contains 'added line starting with ++ is scanned' 'plusplus.txt \[password-assignment\]'
absent 'plusplus value suppressed' "$secret"
fixture "$git_bin" -C "$repo" reset -q --hard
fixture "$git_bin" -C "$repo" reset -q -- .env
rm "$repo/.env"
printf '%s\n' '-----BEGIN OPENSSH PRIVATE KEY-----' 'ghp_fixtureToken123' 'glpat-fixtureToken123' 'AKIA0123456789ABCDEF' > "$repo/keys.txt"
fixture "$git_bin" -C "$repo" add -- keys.txt
run bash "$base/scripts/commit-preflight.sh" --repo "$repo"
contains 'private key rejected' '\[private-key\]'
contains 'GitHub token rejected' '\[github-token\]'
contains 'GitLab token rejected' '\[gitlab-token\]'
contains 'AWS access key rejected' '\[aws-access-key\]'
absent 'token content suppressed' 'ghp_fixtureToken123'
fixture "$git_bin" -C "$repo" reset -q -- keys.txt
rm "$repo/keys.txt"
printf 'binary\000\npassword=%s\n' "$secret" > "$repo/binary.dat"
fixture "$git_bin" -C "$repo" add -- binary.dat
run bash "$base/scripts/commit-preflight.sh" --repo "$repo"
contains 'new binary blob scanned' 'binary.dat \[password-assignment\]'
absent 'binary secret value suppressed' "$secret"
fixture "$git_bin" -C "$repo" reset -q -- binary.dat
rm "$repo/binary.dat"
printf 'password=%s\n' "$secret" > "$repo/legacy.txt"
fixture "$git_bin" -C "$repo" add -- legacy.txt
fixture "$git_bin" -C "$repo" commit -q -m 'Add legacy fixture'
printf 'safe\n' > "$repo/legacy.txt"
fixture "$git_bin" -C "$repo" add -- legacy.txt
run bash "$base/scripts/commit-preflight.sh" --repo "$repo"
code 'secret deletion allowed' 0
fixture "$git_bin" -C "$repo" commit -q -m 'Remove legacy fixture'

manifest="$tmp/manifest"
fixture init_repo "$manifest"
printf 'kind: SealedSecret\n' > "$manifest/resource.yaml"
fixture "$git_bin" -C "$manifest" add -- resource.yaml
cat > "$tmp/npm-fake" <<'NPM'
#!/usr/bin/env bash
[ "$*" = 'run check:unsealed-secrets' ] || exit 2
exit "${NPM_TEST_RESULT:-0}"
NPM
chmod +x "$tmp/npm-fake"
run env NPM_BIN="$tmp/npm-fake" bash "$base/scripts/commit-preflight.sh" --repo "$manifest"
contains 'manifest missing hooks rejected' '^FAIL hooks:'
fixture mkdir -p "$manifest/.husky/_"
for hook in pre-commit pre-push; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$manifest/.husky/_/$hook"
  chmod +x "$manifest/.husky/_/$hook"
done
fixture "$git_bin" -C "$manifest" config core.hooksPath .husky/_
run env NPM_BIN="$tmp/npm-fake" bash "$base/scripts/commit-preflight.sh" --repo "$manifest"
code 'manifest installed hooks and successful check allowed' 0
run env NPM_BIN="$tmp/npm-fake" NPM_TEST_RESULT=1 bash "$base/scripts/commit-preflight.sh" --repo "$manifest"
code 'manifest failed npm secret check rejected' 1
cat > "$tmp/npm-noisy" <<'NPM'
#!/usr/bin/env bash
echo fixture-sensitive-value-never-print
echo fixture-sensitive-value-never-print >&2
exit 1
NPM
chmod +x "$tmp/npm-noisy"
run env NPM_BIN="$tmp/npm-noisy" bash "$base/scripts/commit-preflight.sh" --repo "$manifest"
absent 'manifest npm output suppressed' "$secret"

# Bare remotes are local fixtures; file protocol is the only enabled transport.
fixture "$git_bin" init -q --bare -b main "$tmp/origin.git"
fixture "$git_bin" init -q --bare -b main "$tmp/internal.git"
fixture "$git_bin" -C "$repo" remote add origin "$tmp/origin.git"
fixture "$git_bin" -C "$repo" remote add internal "$tmp/internal.git"
fixture "$git_bin" -C "$repo" config branch.main.remote origin
fixture "$git_bin" -C "$repo" config branch.main.merge refs/heads/main
run bash "$base/scripts/push-all.sh" --repo "$repo" --dry-run
code 'dry-run succeeds for both remotes' 0
contains 'dry-run reports tracked origin' '^OK origin .*\(dry-run\)$'
contains 'dry-run reports internal' '^OK internal .*\(dry-run\)$'
if ! "$git_bin" --git-dir="$tmp/origin.git" show-ref --verify --quiet refs/heads/main &&
   ! "$git_bin" --git-dir="$tmp/internal.git" show-ref --verify --quiet refs/heads/main; then
  ok 'dry-run writes neither remote'
else bad 'dry-run writes neither remote'; fi
# Hostile default refspec/mirror/followTags config must not broaden the push.
fixture "$git_bin" -C "$repo" config remote.origin.mirror true
fixture "$git_bin" -C "$repo" config remote.origin.push refs/heads/feat/x:refs/heads/feat/x
fixture "$git_bin" -C "$repo" config push.followTags true
fixture "$git_bin" -C "$repo" -c tag.gpgSign=false tag -a fixture-tag -m 'Local fixture tag'
run bash "$base/scripts/push-all.sh" --repo "$repo"
code 'push-all pushes main to both remotes' 0
contains 'origin success line' '^OK origin '
contains 'internal success line' '^OK internal '
first=$(printf '%s\n' "$output" | sed -n '1p')
case "$first" in 'OK origin '*) ok 'tracked remote pushed first' ;; *) bad 'tracked remote pushed first' ;; esac
head=$("$git_bin" -C "$repo" rev-parse HEAD)
for remote in origin internal; do
  actual=$("$git_bin" --git-dir="$tmp/$remote.git" rev-parse refs/heads/main)
  if [ "$actual" = "$head" ]; then ok "$remote main updated"; else bad "$remote main updated"; fi
  refs=$("$git_bin" --git-dir="$tmp/$remote.git" for-each-ref --format='%(refname)')
  if [ "$refs" = refs/heads/main ]; then ok "$remote has no feature refs or tags"; else bad "$remote has no feature refs or tags"; fi
done
fixture "$git_bin" -C "$repo" config --unset remote.origin.mirror

# The actual push URL may differ from the fetch URL.
fixture "$git_bin" init -q --bare -b main "$tmp/push-only.git"
fixture "$git_bin" -C "$repo" remote set-url --push origin "$tmp/push-only.git"
run bash "$base/scripts/push-all.sh" --repo "$repo"
code 'distinct push URL handled' 0
actual=$("$git_bin" --git-dir="$tmp/push-only.git" rev-parse refs/heads/main)
if [ "$actual" = "$head" ]; then ok 'actual push URL updated'; else bad 'actual push URL updated'; fi
fixture "$git_bin" -C "$repo" remote set-url --push origin "$tmp/origin.git"

# Remote has a divergent commit; first remote can succeed while internal refuses.
other="$tmp/other"
fixture "$git_bin" clone -q "$tmp/internal.git" "$other"
fixture "$git_bin" -C "$other" config user.name 'Commit tests'
fixture "$git_bin" -C "$other" config user.email 'tests@example.invalid'
fixture "$git_bin" -C "$other" config commit.gpgSign false
fixture "$git_bin" -C "$other" commit -q --allow-empty -m 'Remote-only change'
fixture "$git_bin" -C "$other" push -q origin main:main
remote_head=$("$git_bin" -C "$other" rev-parse HEAD)
fixture "$git_bin" -C "$repo" fetch -q internal main
printf 'next\n' > "$repo/next.txt"
run bash "$base/scripts/commit-preflight.sh" --repo "$repo"
contains 'cached remote behind rejected' '^FAIL behind: internal '
fixture "$git_bin" -C "$repo" add -- next.txt
fixture "$git_bin" -C "$repo" commit -q -m 'Add local-only change'
run bash "$base/scripts/push-all.sh" --repo "$repo"
code 'non-fast-forward push refused' 1
contains 'divergent remote named' '^FAIL internal: fast-forward dry-run rejected'
contains 'partial failure reported' '^WAIT push: partial failure'
actual=$("$git_bin" --git-dir="$tmp/internal.git" rev-parse refs/heads/main)
if [ "$actual" = "$remote_head" ]; then ok 'divergent remote untouched'; else bad 'divergent remote untouched'; fi

if command -v jq >/dev/null 2>&1; then
  guard() {
    local payload
    payload=$(jq -n --arg c "$1" --arg d "${2:-$repo}" '{tool_input:{command:$c},cwd:$d}')
    output=$(printf '%s\n' "$payload" | ROX_GUARD_SCOPE="${ROX_GUARD_SCOPE-*}" bash "$base/scripts/guard-push.sh" 2>&1); result=$?
  }
  guard 'git push origin feat/x'; code 'guard blocks named non-main ref' 2
  contains 'guard explains main-only rule' 'Blocked git push:'
  guard 'git push -f'; code 'guard blocks -f' 2
  guard 'git push origin main'; code 'guard allows main' 0
  guard 'ls'; code 'guard allows unrelated command' 0
  for command_text in 'git push --force-with-lease' 'git push --mirror' 'git push --tags' 'git push --all' 'git push origin main:feat/x' 'git push origin +main:main' 'git push -uf origin main'; do
    guard "$command_text"; code "guard blocks $command_text" 2
  done
  guard 'git push origin refs/heads/main:refs/heads/main'; code 'guard allows explicit main refspec' 0
  guard 'ls && git push origin feat/x'; code 'guard checks chained command' 2
  nested="$tmp/aos/codebase/service"
  fixture init_repo "$nested"
  fixture "$git_bin" -C "$nested" switch -q -c feat/x
  guard 'git push' "$nested"; code 'guard blocks implicit nested push from non-main' 2
  guard "cd $nested && git push"; code 'guard follows an in-command cd to a non-main repo' 2
  rootlike="$tmp/rootlike"
  fixture init_repo "$rootlike"
  fixture "$git_bin" -C "$rootlike" switch -q -c feat/y
  guard 'git push' "$rootlike"; code 'guard blocks implicit push from non-main at any in-scope repo' 2
  guard "git -C $nested push origin main"; code 'guard respects git -C branch' 2
else
  echo 'SKIP guard tests: jq missing'
  bad 'guard integration requires jq'
fi
# default scope: a push outside the aos workspace is left alone, even a feature branch
ROX_GUARD_SCOPE= guard 'git push origin feat/x'; code 'guard ignores repos outside the aos workspace' 0
mkdir -p "$tmp/aos/codebase/x" && "$git_bin" -C "$tmp/aos/codebase/x" init -q 2>/dev/null
ROX_GUARD_SCOPE= guard 'git push origin feat/x' "$tmp/aos/codebase/x"; code 'guard acts inside an aos nested repo' 2
run env JQ_BIN="$tmp/no-jq" bash "$base/scripts/guard-push.sh" <<< '{"tool_input":{"command":"git push -f"}}'
code 'guard fails open when jq missing' 0
for script in commit-preflight push-all; do
  run bash "$base/scripts/$script.sh" --unknown; code "$script bad usage exits 2" 2
done
printf 'Tests: %s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
