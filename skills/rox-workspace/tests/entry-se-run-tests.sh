#!/usr/bin/env bash
# Fake companion only: no real Codex tasks, git mutations or cluster access.
set -u
[ $# -eq 0 ] || { echo 'usage: entry-se-run-tests.sh' >&2; exit 2; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
runner="$script_dir/../scripts/entry-se-run.sh"
command -v node >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || {
  echo 'FAIL test dependencies: node and jq required -- install both'; exit 1;
}
test_tmp="$(mktemp -d)" || exit 1
test_tmp="$(cd -- "$test_tmp" && pwd -P)" || exit 1
trap 'rm -rf -- "$test_tmp"' EXIT
mkdir -p "$test_tmp/repo with spaces" "$test_tmp/other repo"
repo="$test_tmp/repo with spaces"
printf '%s\n\n' '--brief-marker: "quotes" $literal and `literal`' 'second line' > "$test_tmp/brief file"
printf '%s\n\n' '--answer-marker: choose option B' 'second line' > "$test_tmp/answer file"
export FAKE_ROOT="$test_tmp" FAKE_REPO="$repo"
export CODEX_COMPANION="$test_tmp/fake-companion.mjs" ENTRY_SE_POLL=0.05
export CODEX_COMPANION_SESSION_ID=test-session
cat > "$CODEX_COMPANION" <<'FAKE'
import fs from 'node:fs';
import path from 'node:path';
const root = process.env.FAKE_ROOT;
const [cmd, ...args] = process.argv.slice(2);
fs.appendFileSync(path.join(root, 'calls'), `${cmd}\n`);
const assert = (ok) => { if (!ok) throw new Error('fake invocation mismatch'); };
if (process.env.FAKE_FAIL === cmd) {
  console.error('--brief-marker: --answer-marker: diagnostic must stay hidden');
  process.exit(1);
}
if (cmd === 'status' && args[0] === '--all') {
  assert(args.join(' ') === '--all --json');
  assert(process.cwd() === process.env.FAKE_REPO);
  assert(!process.env.CODEX_COMPANION_SESSION_ID);
  if (process.env.FAKE_BAD_JSON) console.log('invalid listing');
  else console.log(JSON.stringify({workspaceRoot: process.cwd(), running:
    process.env.FAKE_BUSY ? [{id:'task-other',status:process.env.FAKE_BUSY,sessionId:'other-session'}] : [],
    latestFinished: null, recent: []}));
} else if (cmd === 'status') {
  assert(args.length === 2 && args[1] === '--json');
  assert(process.cwd() === process.env.FAKE_REPO);
  const counter = path.join(root, 'polls');
  const n = fs.existsSync(counter) ? Number(fs.readFileSync(counter, 'utf8')) : 0;
  fs.writeFileSync(counter, String(n + 1));
  const states = (process.env.FAKE_STATES || 'completed').split(',');
  if (process.env.FAKE_BAD_JSON) console.log('{"job":{}}');
  else console.log(JSON.stringify({workspaceRoot:process.cwd(), job:{id:args[0],
    status:states[Math.min(n, states.length - 1)], progressPreview:['--brief-marker: private progress']}}));
} else if (cmd === 'task') {
  assert(process.cwd() === process.env.FAKE_REPO);
  const resume = args.includes('--resume-last');
  const w = process.env.FAKE_READONLY ? '' : ' --write';
  assert(args.join(' ') === (resume ? '--background' + w + ' --resume-last' : '--background' + w));
  assert(process.env.CODEX_COMPANION_SESSION_ID === 'test-session');
  const expected = fs.readFileSync(path.join(root, resume ? 'answer file' : 'brief file'));
  assert(fs.readFileSync(0).equals(expected));
  fs.writeFileSync(path.join(root, 'launched'), resume ? 'resume' : 'start');
  if (process.env.FAKE_BAD_LAUNCH) console.log('--brief-marker: malformed output');
  else console.log(`Codex ${resume ? 'Resume' : 'Task'} started in the background as task-test-123. Check /codex:status task-test-123 for progress.`);
} else if (cmd === 'result') {
  assert(process.cwd() === process.env.FAKE_REPO && args.length === 1);
  console.log(fs.readFileSync(path.join(root, 'result'), 'utf8'));
} else throw new Error('unexpected command');
FAKE

passed=0
failed=0
check() {
  local label="$1"
  shift
  if "$@"; then echo "OK $label"; passed=$((passed + 1))
  else echo "FAIL $label -- inspect entry-se-run.sh"; failed=$((failed + 1)); fi
}
run() {
  local expected="$1"
  shift
  (cd -- "$repo" && bash "$runner" "$@") > "$test_tmp/output" 2>&1
  rc=$?
  [ "$rc" -eq "$expected" ]
}
contains() { rg -q -- "$1" "$test_tmp/output"; }
hidden() { ! rg -q -- '--brief-marker:|--answer-marker:' "$test_tmp/output"; }
reset_polls() { rm -f "$test_tmp/polls"; }

# Launch from outside the repo with relative paths; fake asserts cwd, stdin bytes and flags.
(cd -- "$test_tmp" && bash "$runner" start 'repo with spaces' 'brief file') > "$test_tmp/output" 2>&1
check 'start parses id, repo cwd, exact multiline prompt and flags' test "$?" -eq 0
check 'start prints only job id' test "$(cat "$test_tmp/output")" = task-test-123
check 'start hides brief' hidden
check 'resume uses same repo, exact answer and resume flags' run 0 resume "$repo" "$test_tmp/answer file"
check 'resume parses Codex Resume launch id' test "$(cat "$test_tmp/output")" = task-test-123
check 'resume hides answer' hidden

# read-only (collect) jobs drop --write; the fake asserts the exact flags
export FAKE_READONLY=1
check 'start --read-only launches without --write' run 0 start "$repo" "$test_tmp/brief file" --read-only
check 'resume --read-only launches without --write' run 0 resume "$repo" "$test_tmp/answer file" --read-only
check 'bad fourth argument is a usage error' run 2 start "$repo" "$test_tmp/brief file" --nope
unset FAKE_READONLY

for state in running queued; do
  rm -f "$test_tmp/launched"
  export FAKE_BUSY="$state"
  check "start refuses $state job from another session" run 1 start "$repo" "$test_tmp/brief file"
  check "busy $state diagnostic" contains '^FAIL busy:'
  check "busy $state never launches task" test ! -e "$test_tmp/launched"
done
check 'resume also refuses active job' run 1 resume "$repo" "$test_tmp/answer file"
unset FAKE_BUSY

reset_polls
export FAKE_STATES=queued,running,completed
check 'wait polls queued and running until completed' run 0 wait task-test-123 --max 5
check 'wait reports completed' contains '^OK wait: task-test-123 completed$'
check 'wait suppresses private progress' hidden
check 'wait limits progress to one line within a minute' test "$(rg -c '^WAIT' "$test_tmp/output")" -eq 1
check 'wait performed all three polls' test "$(cat "$test_tmp/polls")" -eq 3
for state in failed cancelled; do
  reset_polls
  export FAKE_STATES="$state"
  check "wait exits zero for ended $state job" run 0 wait task-test-123
done
export FAKE_STATES=running
reset_polls
export ENTRY_SE_POLL=15
check 'wait ceiling exits 3 (poll longer than ceiling is clipped)' run 3 wait task-test-123 --max 1
check 'timeout reports ceiling' contains 'ceiling of 1s reached'
check 'zero ceiling returns immediately for active job' run 3 wait task-test-123 --max 0
export ENTRY_SE_POLL=0.05
unset FAKE_STATES

for verdict in DONE NEEDS-INPUT BLOCKED; do
  printf 'Summary\nRESULT: %s\nTASK: Product #61\nCodex session ID: thread-id\nResume in Codex: codex resume thread-id\n' "$verdict" > "$test_tmp/result"
  check "result prints $verdict reply" run 0 result task-test-123
  check "result appends $verdict parse after companion footer" test "$(tail -n 1 "$test_tmp/output")" = "RESULT: $verdict"
  check 'result preserves original summary' contains '^Summary$'
done
printf 'RESULT: DONE\nTASK: Product #61\nLater correction\nRESULT: NEEDS-INPUT\nTASK: Product #61\nQUESTION: A or B?\n' > "$test_tmp/result"
check 'result reads last return marker' run 0 result task-test-123
check 'result last marker is NEEDS-INPUT' test "$(tail -n 1 "$test_tmp/output")" = 'RESULT: NEEDS-INPUT'
printf 'No final return block\nExample RESULT: DONE\nRESULT: DONE | NEEDS-INPUT | BLOCKED\n' > "$test_tmp/result"
check 'result missing block exits zero' run 0 result task-test-123
check 'result missing block prints SKIP' contains '^SKIP result: no return block$'

export FAKE_BAD_JSON=1
check 'start refuses malformed listing' run 1 start "$repo" "$test_tmp/brief file"
check 'wait rejects missing job status' run 1 wait task-test-123
unset FAKE_BAD_JSON
export FAKE_BAD_LAUNCH=1
check 'start rejects unparseable launch' run 1 start "$repo" "$test_tmp/brief file"
check 'malformed launch hides prompt' hidden
unset FAKE_BAD_LAUNCH
for cmd in status task result; do
  export FAKE_FAIL="$cmd"
  case "$cmd" in
    status) check 'failed busy check stops start' run 1 start "$repo" "$test_tmp/brief file" ;;
    task) check 'failed launch stops start' run 1 start "$repo" "$test_tmp/brief file" ;;
    result) check 'unavailable result fails' run 1 result task-test-123 ;;
  esac
  check 'failure diagnostics hide prompt' hidden
done
unset FAKE_FAIL
check 'missing repo fails' run 1 start "$test_tmp/missing" "$test_tmp/brief file"
check 'missing brief fails' run 1 start "$repo" "$test_tmp/missing"

check 'usage: no command' run 2
check 'usage: unknown command' run 2 unknown
check 'usage: missing start argument' run 2 start "$repo"
check 'usage: missing resume argument' run 2 resume "$repo"
check 'usage: extra result argument' run 2 result task-test-123 extra
check 'usage: missing wait id' run 2 wait
check 'usage: option used as job id' run 2 result --help
check 'usage: wait unknown flag' run 2 wait task-test-123 --wrong 1
check 'usage: missing max value' run 2 wait task-test-123 --max
check 'usage: negative max' run 2 wait task-test-123 --max -1
check 'usage: noninteger max' run 2 wait task-test-123 --max 0.5
check 'usage: excessive max' run 2 wait task-test-123 --max 999999999999999
export ENTRY_SE_POLL=0
check 'usage: invalid poll interval' run 2 wait task-test-123

printf 'entry-se-run tests: %s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
