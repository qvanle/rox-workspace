#!/usr/bin/env bash
# Entry.SE executor. wait/result must run from the job's repo (companion state is repo-local).
# Overrides: CODEX_COMPANION (script path), NODE_BIN, JQ_BIN, ENTRY_SE_POLL (seconds).
# Exit: 0 success/job ended, 1 operational failure, 2 usage, 3 wait ceiling.
# Default wait ceiling: 3600s. Prompts go through stdin, never through printed output.
set -u

usage() {
  echo 'usage: entry-se-run.sh [--model M] [--effort E] [--tier light|standard|complex] start <repo> <brief-file> [--read-only] | run <repo> <command-file> | wait <job-id> [--max SEC] | result <job-id> [--commands <file>] | resume <repo> <answer-file> [--read-only]' >&2
  exit 2
}
fail() { printf 'FAIL %s: %s -- %s\n' "$1" "$2" "$3" >&2; exit 1; }
valid_id() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; }
trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}
# Content snapshot of every changed path outside .codex-runs/: "<status> <path> <sha>" per line, sorted. A read-only run is checked
# by comparing the snapshot taken before launch with the one taken after, so a repo that was already dirty does not look like a violation.
snapshot_repo() {
  local entry code path skip=0
  while IFS= read -r -d '' entry; do
    if [ "$skip" -eq 1 ]; then skip=0; continue; fi # origin path of a rename or copy
    code="${entry:0:2}"; path="${entry:3}"
    case "$code" in R* | C* | ?R | ?C) skip=1 ;; esac
    [[ "$path" == .codex-runs/* ]] && continue
    if [ -e "$path" ] || [ -L "$path" ]; then printf '%s\t%s\t%s\n' "$code" "$path" "$(git hash-object -- "$path" 2>/dev/null || echo -)"
    else printf '%s\t%s\tgone\n' "$code" "$path"; fi
  done < <(GIT_OPTIONAL_LOCKS=0 git status --porcelain -z --untracked-files=all) | LC_ALL=C sort
}
# Codex model and effort (operator policy 2026-10-09): only gpt-6-luna and gpt-6.1-sol; effort medium by default, low for simple
# work, high or xhigh for complex work. --tier is a shortcut: light = luna/low, standard = luna/medium, complex = sol/high.
# Defaults come from ENTRY_SE_MODEL and ENTRY_SE_EFFORT; --model/--effort override them (xhigh is only ever asked for explicitly).
model="${ENTRY_SE_MODEL:-gpt-6-luna}"
effort="${ENTRY_SE_EFFORT:-medium}"
cli_args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --model) [ $# -ge 2 ] || usage; model="$2"; shift 2 ;;
    --effort) [ $# -ge 2 ] || usage; effort="$2"; shift 2 ;;
    --tier)
      [ $# -ge 2 ] || usage
      case "$2" in
        light) model=gpt-6-luna; effort=low ;;
        standard) model=gpt-6-luna; effort=medium ;;
        complex) model=gpt-6.1-sol; effort=high ;;
        *) usage ;;
      esac
      shift 2 ;;
    *) cli_args+=("$1"); shift ;;
  esac
done
set -- ${cli_args[@]+"${cli_args[@]}"}
case "$model" in gpt-6-luna | gpt-6.1-sol) ;; *) echo "FAIL model: only gpt-6-luna and gpt-6.1-sol are allowed (got '$model')" >&2; exit 2 ;; esac
case "$effort" in low | medium | high | xhigh) ;; *) echo "FAIL effort: use low, medium, high or xhigh (got '$effort')" >&2; exit 2 ;; esac

command_name="${1:-}"
max=3600
poll="${ENTRY_SE_POLL:-15}"
case "$command_name" in
  start | resume)
    { [ $# -eq 3 ] || { [ $# -eq 4 ] && [ "$4" = --read-only ]; }; } && [ -n "$2" ] && [ -n "$3" ] || usage ;;
  run)
    [ $# -eq 3 ] && [ -n "$2" ] && [ -n "$3" ] || usage ;;
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
  result)
    if [ $# -eq 2 ]; then
      valid_id "$2" || usage
    elif [ $# -eq 4 ] && [ "$3" = --commands ] && [ -n "$4" ]; then
      valid_id "$2" || usage
    else
      usage
    fi
    ;;
  *) usage ;;
esac

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
run_repo=''
run_brief=''
run_tmp=''
if [ "$command_name" = run ]; then
  command_file="$3"
  case "$command_file" in /*) ;; *) command_file="$PWD/$command_file" ;; esac
  if lint_output="$(bash "$script_dir/run-lint.sh" "$command_file" 2>&1)"; then
    : # Keep the successful lint summary out of run-mode stdout.
  else
    lint_status=$?
    printf '%s\n' "$lint_output" >&2
    exit "$lint_status"
  fi

  [ -d "$2" ] || fail repo 'directory missing' 'provide the code repo directory'
  run_repo="$(cd -- "$2" && pwd -P)" || fail repo 'cannot enter directory' 'check directory permissions'
  command_repo=''
  while IFS= read -r command_line || [ -n "$command_line" ]; do
    if [[ "$command_line" =~ ^[[:space:]]*repo: ]]; then
      command_repo="$(trim "${command_line#*repo:}")"
    fi
  done < "$command_file"
  if [ -n "$command_repo" ]; then
    [ -d "$command_repo" ] || fail repo 'command file repo directory is missing' 'use the repo passed to run'
    command_repo="$(cd -- "$command_repo" && pwd -P)" || fail repo 'cannot enter command file repo' 'check directory permissions'
    [ "$command_repo" = "$run_repo" ] || fail repo 'command file repo does not match requested repo' 'use the same repo path in both places'
  fi
  if ! GIT_OPTIONAL_LOCKS=0 git -C "$run_repo" check-ignore -q .codex-runs/x >/dev/null 2>&1; then
    printf 'FAIL ignore: .codex-runs/ is not git-ignored in %s -- add it to .gitignore\n' "$run_repo" >&2
    exit 1
  fi

  template="$script_dir/../domains/product/templates/run-brief.md"
  [ -r "$template" ] || fail template 'run brief is missing or unreadable' 'restore templates/run-brief.md'
  run_tmp="$(mktemp -d)" || fail temp 'cannot create temporary directory' 'check temporary-directory permissions'
  trap 'rm -rf -- "$run_tmp"' EXIT
  run_brief="$run_tmp/run-brief.md"
  while IFS= read -r template_line || [ -n "$template_line" ]; do
    case "$template_line" in
      '<COMMANDS>')
        cat -- "$command_file" >> "$run_brief" || fail prompt 'cannot read command file' 'check file permissions'
        printf '\n' >> "$run_brief"
        ;;
      *)
        template_line="${template_line//<REPO>/$run_repo}"
        printf '%s\n' "$template_line" >> "$run_brief"
        ;;
    esac
  done < "$template"
fi

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
  base_tmp=''
  if [ "$command_name" = run ]; then
    base_tmp="$(mktemp)" || fail temp 'cannot create snapshot file' 'check temporary-directory permissions'
    snapshot_repo > "$base_tmp" || { rm -f -- "$base_tmp"; fail snapshot 'could not read repo status' 'run inside a git repository'; }
  fi
  if [ "$command_name" = resume ]; then
    output="$(run_companion task --background ${write_flag[@]+"${write_flag[@]}"} --resume-last --model "$model" --effort "$effort" < "$input")" || fail resume 'Codex launch failed' 'check Codex setup/auth/quota; do not fall back to inline work'
  else
    output="$(run_companion task --background ${write_flag[@]+"${write_flag[@]}"} --model "$model" --effort "$effort" < "$input")" || fail start 'Codex launch failed' 'check Codex setup/auth/quota; do not fall back to inline work'
  fi
  job="$(printf '%s\n' "$output" | sed -nE 's/^Codex (Task|Resume) started in the background as ([A-Za-z0-9_-]+)\..*$/\2/p')"
  valid_id "$job" || fail "$command_name" 'launch returned no unique job id' 'inspect Codex status in this repo before retrying'
  if [ -n "$base_tmp" ]; then mkdir -p .codex-runs && mv -f -- "$base_tmp" ".codex-runs/$job.base"; fi
  printf '%s\n' "$job"
}

case "$command_name" in
  start | resume) launch "$2" "$3" "${4:-}" ;;
  run) launch "$run_repo" "$run_brief" ;;
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
      /^[[:space:]]*RESULT:[[:space:]]*(DONE|PARTIAL|NEEDS-INPUT|BLOCKED)[[:space:]]*$/ {
        line=$0; sub(/^[[:space:]]*RESULT:[[:space:]]*/, "", line)
        sub(/[[:space:]]*$/, "", line); verdict=line
      }
      END {print verdict}')"
    if [ -n "$verdict" ]; then printf 'RESULT: %s\n' "$verdict"
    else echo 'SKIP result: no return block'; fi

    if printf '%s\n' "$output" | grep -Eq '^[[:space:]]*RUN:[[:space:]]*[^[:space:]]'; then
      result_rc=0
      if [ "$#" -eq 4 ]; then
        commands_file="$4"
        case "$commands_file" in /*) ;; *) commands_file="$PWD/$commands_file" ;; esac
        result_tmp="$(mktemp)" || fail temp 'cannot create result file' 'check temporary-directory permissions'
        printf '%s\n' "$output" > "$result_tmp"
        if ! bash "$script_dir/run-verify.sh" "$result_tmp" "$commands_file"; then result_rc=1; fi

        command_mode=''
        if [ -r "$commands_file" ]; then
          while IFS= read -r command_line || [ -n "$command_line" ]; do
            if [[ "$command_line" =~ ^[[:space:]]*mode:[[:space:]]*(read-only|write)[[:space:]]*$ ]]; then
              command_mode="${BASH_REMATCH[1]}"
            fi
          done < "$commands_file"
        fi
        if [ "$command_mode" = read-only ]; then
          base_file=".codex-runs/$2.base"
          if [ ! -r "$base_file" ]; then
            printf 'SKIP baseline: %s is missing, so a read-only violation cannot be checked\n' "$base_file"
          else
            now_tmp="$(mktemp)" || fail temp 'cannot create snapshot file' 'check temporary-directory permissions'
            if ! snapshot_repo > "$now_tmp"; then
              rm -f -- "$now_tmp" "$result_tmp"
              printf 'FAIL status: could not inspect repo changes\n' >&2
              exit 1
            fi
            changed="$(LC_ALL=C diff <(cut -f2,3 "$base_file") <(cut -f2,3 "$now_tmp") | awk -F'\t' '/^[<>] / {sub(/^[<>] /, "", $1); print $1}' | LC_ALL=C sort -u)"
            rm -f -- "$now_tmp"
            if [ -n "$changed" ]; then
              printf 'FAIL violation: changed outside .codex-runs/: %s\n' "$(printf '%s\n' "$changed" | head -n 10 | paste -sd ' ' -)"
              result_rc=1
            fi
          fi
        fi
        rm -f -- "$result_tmp"
      else
        printf 'FAIL verify: --commands <file> required for run result\n'
        result_rc=1
      fi
      exit "$result_rc"
    fi
    ;;
esac
