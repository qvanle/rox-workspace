#!/usr/bin/env bash
# Entry.SE executor. wait/result must run from the job's repo (companion state is repo-local).
# Overrides: CODEX_COMPANION (script path), NODE_BIN, JQ_BIN, ENTRY_SE_POLL (seconds).
# Exit: 0 success/job ended, 1 operational failure, 2 usage, 3 wait ceiling.
# Default wait ceiling: 3600s. Prompts go through stdin, never through printed output.
set -u

usage() {
  echo 'usage: entry-se-run.sh start <repo> <brief-file> [--read-only] | wait <job-id> [--max SEC] | result <job-id> | resume <repo> <answer-file> [--read-only]' >&2
  exit 2
}
fail() { printf 'FAIL %s: %s -- %s\n' "$1" "$2" "$3" >&2; exit 1; }
valid_id() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; }
command_name="${1:-}"
max=3600
poll="${ENTRY_SE_POLL:-15}"
case "$command_name" in
  start | resume)
    { [ $# -eq 3 ] || { [ $# -eq 4 ] && [ "$4" = --read-only ]; }; } && [ -n "$2" ] && [ -n "$3" ] || usage ;;
  wait)
    [ $# -eq 2 ] || [ $# -eq 4 ] || usage
    valid_id "$2" || usage
    if [ $# -eq 4 ]; then
      [ "$3" = --max ] && [[ "$4" =~ ^[0-9]{1,9}$ ]] || usage
      max=$((10#$4))
    fi
    [[ "$poll" =~ ^[0-9]+([.][0-9]+)?$ ]] || usage
    awk -v p="$poll" 'BEGIN {exit !(p > 0)}' || usage
    ;;
  result) [ $# -eq 2 ] && valid_id "$2" || usage ;;
  *) usage ;;
esac

companion="${CODEX_COMPANION:-$HOME/.claude/plugins/marketplaces/openai-codex/plugins/codex/scripts/codex-companion.mjs}"
node_bin="${NODE_BIN:-node}"
jq_bin="${JQ_BIN:-jq}"
case "$companion" in
  *.mjs | *.js)
    [ -r "$companion" ] || fail companion 'script not readable' 'set CODEX_COMPANION to codex-companion.mjs'
    companion="$(cd -- "$(dirname -- "$companion")" && pwd)/$(basename -- "$companion")"
    command -v "$node_bin" >/dev/null 2>&1 || fail node 'not on PATH' 'install Node.js'
    companion_cmd=("$node_bin" "$companion")
    ;;
  *)
    companion="$(command -v "$companion")" || fail companion 'not executable' 'set CODEX_COMPANION to an executable script'
    # Resolve relative override paths before changing to the target repo.
    case "$companion" in /*) ;; *) companion="$PWD/$companion" ;; esac
    companion_cmd=("$companion")
    ;;
esac
if [ "$command_name" != result ]; then
  command -v "$jq_bin" >/dev/null 2>&1 || fail jq 'not on PATH' 'install jq'
fi
run_companion() { "${companion_cmd[@]}" "$@" 2>/dev/null; }

launch() {
  local repo="$1" input="$2" output busy job
  # --read-only: a collect job (no --write, Codex sandbox stays read-only); default: a build job.
  local write_flag=(--write)
  [ "${3:-}" = --read-only ] && write_flag=()
  [ -d "$repo" ] || fail repo 'directory missing' 'provide the code repo directory'
  [ -f "$input" ] && [ -r "$input" ] && [ -s "$input" ] || fail prompt 'file missing, unreadable or empty' 'provide a nonempty brief or answer file'
  case "$input" in /*) ;; *) input="$PWD/$input" ;; esac
  cd -- "$repo" || fail repo 'cannot enter directory' 'check directory permissions'
  # --all alone still filters by Claude session; remove the filter for the busy check only.
  output="$(unset CODEX_COMPANION_SESSION_ID; run_companion status --all --json)" || fail status 'cannot check active jobs' 'check Codex setup/auth and retry; no job launched'
  busy="$(printf '%s' "$output" | "$jq_bin" -er '
    if (.running | type) == "array" then (.running | length)
    else error("missing running array") end' 2>/dev/null)" || fail status 'invalid job listing' 'check the companion version; no job launched'
  [ "$busy" -eq 0 ] || fail busy 'another Codex job is active in this repo' 'wait for it to finish before starting or resuming'
  if [ "$command_name" = resume ]; then
    output="$(run_companion task --background ${write_flag[@]+"${write_flag[@]}"} --resume-last < "$input")" || fail resume 'Codex launch failed' 'check Codex setup/auth/quota; do not fall back to inline work'
  else
    output="$(run_companion task --background ${write_flag[@]+"${write_flag[@]}"} < "$input")" || fail start 'Codex launch failed' 'check Codex setup/auth/quota; do not fall back to inline work'
  fi
  job="$(printf '%s\n' "$output" | sed -nE 's/^Codex (Task|Resume) started in the background as ([A-Za-z0-9_-]+)\..*$/\2/p')"
  valid_id "$job" || fail "$command_name" 'launch returned no unique job id' 'inspect Codex status in this repo before retrying'
  printf '%s\n' "$job"
}

case "$command_name" in
  start | resume) launch "$2" "$3" "${4:-}" ;;
  wait)
    started=$SECONDS
    next_progress=0
    while :; do
      output="$(run_companion status "$2" --json)" || fail status 'job lookup failed' 'run wait from the job repo; check Codex setup'
      state="$(printf '%s' "$output" | "$jq_bin" -er '.job.status | select(type == "string")' 2>/dev/null)" || fail status 'invalid job status' 'check the companion version'
      case "$state" in
        completed | failed | cancelled) printf 'OK wait: %s %s\n' "$2" "$state"; exit 0 ;;
        queued | running) ;;
        *) fail status 'unrecognized job status' 'inspect Codex status before retrying' ;;
      esac
      elapsed=$((SECONDS - started))
      if [ "$elapsed" -ge "$max" ]; then
        printf 'WAIT %s: ceiling of %ss reached; job remains active\n' "$2" "$max"
        exit 3
      fi
      if [ "$elapsed" -ge "$next_progress" ]; then
        printf 'WAIT %s: %s (%ss elapsed)\n' "$2" "$state" "$elapsed"
        next_progress=$((elapsed + 60))
      fi
      delay="$(awk -v p="$poll" -v remaining="$((max - elapsed))" 'BEGIN {print (p < remaining ? p : remaining)}')"
      sleep "$delay" || fail wait 'sleep failed' 'check ENTRY_SE_POLL and retry'
    done
    ;;
  result)
    output="$(run_companion result "$2")" || fail result 'job result unavailable' 'run result from the job repo after it finishes'
    printf '%s\n' "$output"
    verdict="$(printf '%s\n' "$output" | awk '
      {sub(/\r$/, "")}
      /^[[:space:]]*RESULT:[[:space:]]*(DONE|NEEDS-INPUT|BLOCKED)[[:space:]]*$/ {
        line=$0; sub(/^[[:space:]]*RESULT:[[:space:]]*/, "", line)
        sub(/[[:space:]]*$/, "", line); verdict=line
      }
      END {print verdict}')"
    if [ -n "$verdict" ]; then printf 'RESULT: %s\n' "$verdict"
    else echo 'SKIP result: no return block'; fi
    ;;
esac
