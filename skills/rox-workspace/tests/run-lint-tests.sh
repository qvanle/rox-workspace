#!/usr/bin/env bash
set -u
[ $# -eq 0 ] || { echo 'usage: run-lint-tests.sh' >&2; exit 2; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
lint="$script_dir/../scripts/run-lint.sh"
test_tmp="$(mktemp -d)" || exit 1
trap 'rm -rf -- "$test_tmp"' EXIT

passed=0
failed=0
write_file() {
  local mode="${1:-read-only}"
  [ $# -eq 0 ] || shift
  {
    printf 'id: run-1\nrepo: /tmp/fixture\nmode: %s\nquestion: check it\n' "$mode"
    cat
  } > "$test_tmp/commands"
}
run_lint() {
  local expected="$1"
  shift
  bash "$lint" "$@" > "$test_tmp/output" 2>&1
  [ "$?" -eq "$expected" ]
}
contains() { rg -q -- "$1" "$test_tmp/output"; }
check() {
  local label="$1"
  shift
  if "$@"; then
    echo "OK $label"
    passed=$((passed + 1))
  else
    echo "FAIL $label -- inspect run-lint.sh"
    failed=$((failed + 1))
  fi
}

write_file <<'COMMANDS'
printf '%s\n' 'safe | text; > < &'
echo first && echo second
COMMANDS
check 'accepts clean commands, quoted metacharacters and one &&' run_lint 0 "$test_tmp/commands"
check 'clean summary includes count and mode' contains '^OK 2 commands, mode read-only$'

for refused in \
  'git commit -m message' \
  'git push origin main' \
  'git reset --hard' \
  'git checkout -- file' \
  'rm -rf target' \
  'kubectl get pods' \
  'kubeseal --version' \
  'ansible-playbook play.yml' \
  'ssh host.example' \
  'curl -X POST https://example.invalid' \
  'curl --request PUT https://example.invalid' \
  'curl --request=DELETE https://example.invalid' \
  'roxctl workspace pma add item' \
  'roxctl workspace pma edit item' \
  'roxctl workspace pma delete item' \
  'roxctl workspace pma toggle item' \
  'roxctl workspace pma create item' \
  'roxctl workspace pma update item' \
  'roxctl workspace pma move item' \
  'roxctl workspace pma archive item' \
  'roxctl workspace pma unarchive item' \
  'roxctl workspace seal item' \
  'roxctl workspace sync item' \
  'roxctl workspace rollback item' \
  'roxctl workspace terminate-op item' \
  'roxctl workspace apply item' \
  'roxctl workspace patch item' \
  'cat env/config' \
  'cat values.sealedsecret.yaml'; do
  printf '%s\n' "$refused" | write_file
  check "refuses: ${refused%% *}" run_lint 1 "$test_tmp/commands"
  check 'refusal reports line and rule without command text' contains '^FAIL line 5: refused command or path$'
done

for meta in \
  'echo one; echo two' \
  'echo one | cat' \
  'echo `whoami`' \
  'echo $(whoami)' \
  'echo one > out' \
  'cat < input' \
  'echo one &'; do
  printf '%s\n' "$meta" | write_file
  check "rejects shell metacharacter: ${meta%% *}" run_lint 1 "$test_tmp/commands"
  check 'metacharacter failure identifies its line' contains '^FAIL line 5:'
done

printf 'id: run-1\nrepo: /tmp/fixture\nmode: read-only\nquestion: check it\necho one\\\necho two\n' > "$test_tmp/commands"
check 'rejects backslash newline continuation' run_lint 1 "$test_tmp/commands"

printf '%s\n' "echo unmatched 'quote" | write_file
check 'rejects an unclosed quote' run_lint 1 "$test_tmp/commands"

printf 'id: run-1\nmode: read-only\necho safe\000echo hidden\n' > "$test_tmp/nul-command"
check 'rejects NUL bytes instead of allowing line truncation' run_lint 1 "$test_tmp/nul-command"
check 'NUL refusal is reported by line' contains '^FAIL line 1: NUL byte in command file$'

write_file <<'COMMANDS'
echo 1
echo 2
echo 3
echo 4
echo 5
echo 6
echo 7
echo 8
echo 9
echo 10
echo 11
COMMANDS
check 'rejects 11 commands' run_lint 1 "$test_tmp/commands"
check 'command cap identifies line 15' contains '^FAIL line 15: more than 10 commands$'

write_file read-anything <<'COMMANDS'
echo one
COMMANDS
check 'rejects invalid mode' run_lint 1 "$test_tmp/commands"
check 'invalid mode names the rule' contains '^FAIL line 3: mode must be read-only or write$'

cat > "$test_tmp/missing-mode" <<'COMMANDS'
id: run-1
echo one
COMMANDS
check 'rejects missing mode' run_lint 1 "$test_tmp/missing-mode"
check 'missing mode is reported' contains 'missing mode header'

cat > "$test_tmp/missing-id" <<'COMMANDS'
mode: write
echo one
COMMANDS
check 'rejects missing id' run_lint 1 "$test_tmp/missing-id"
check 'missing id is reported' contains 'missing id header'

check 'usage error exits 2' run_lint 2

printf 'run-lint tests: %s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
