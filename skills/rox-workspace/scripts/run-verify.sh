#!/usr/bin/env bash
# Checks that a run return block reports the command file's exact command list.
set -u
export LC_ALL=C

usage() {
  echo 'usage: run-verify.sh <result-file> <command-file>' >&2
  exit 2
}
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; exit 1; }
trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

[ $# -eq 2 ] || usage
result_file="$1"
command_file="$2"
[ -f "$result_file" ] && [ -r "$result_file" ] || fail result 'result file is missing or unreadable'
[ -f "$command_file" ] && [ -r "$command_file" ] || fail commands 'command file is missing or unreadable'

expected=()
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue
  if [[ "$line" =~ ^[[:space:]]*(id|repo|mode|question): ]]; then continue; fi
  expected+=("$(trim "$line")")
done < "$command_file"

result=''
log=''
verdict=''
verdict_seen=0
run_seen=0
key_lines_seen=0
not_run_seen=0
cmd_texts=()
cmd_exits=()
cmd_numbers=()
line_number=0
while IFS= read -r line || [ -n "$line" ]; do
  line_number=$((line_number + 1))
  line="${line%$'\r'}"
  if [[ "$line" =~ ^[[:space:]]*RESULT:[[:space:]]*(DONE|PARTIAL|BLOCKED)[[:space:]]*$ ]]; then
    result="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]*RESULT: ]]; then
    result='INVALID'
  fi
  [[ "$line" =~ ^[[:space:]]*RUN:[[:space:]]*[^[:space:]].*$ ]] && run_seen=1
  if [[ "$line" =~ ^[[:space:]]*LOG:[[:space:]]*(.*)$ ]]; then
    [ -n "$(trim "${BASH_REMATCH[1]}")" ] && log="${BASH_REMATCH[1]}"
  fi
  if [[ "$line" =~ ^[[:space:]]*VERDICT:[[:space:]]*(.*)$ ]]; then
    verdict="${BASH_REMATCH[1]}"
    verdict_seen=1
  fi
  [[ "$line" =~ ^[[:space:]]*KEY[[:space:]]+LINES:[[:space:]]*$ ]] && key_lines_seen=1
  [[ "$line" =~ ^[[:space:]]*NOT[[:space:]]+RUN:[[:space:]]*.*$ ]] && not_run_seen=1

  if [[ "$line" =~ ^[[:space:]]*CMD[[:space:]]+([0-9]+):[[:space:]](.*)[[:space:]]-\>[[:space:]]exit[[:space:]](-?[0-9]+)[[:space:]]\(([0-9]+([.][0-9]+)?)s\)[[:space:]]*$ ]]; then
    cmd_numbers+=("${BASH_REMATCH[1]}")
    cmd_texts+=("$(trim "${BASH_REMATCH[2]}")")
    cmd_exits+=("${BASH_REMATCH[3]}")
  elif [[ "$line" =~ ^[[:space:]]*CMD([[:space:]]|[0-9]) ]]; then
    fail "CMD line $line_number" 'malformed command record'
  fi
done < "$result_file"

[ "$result" != '' ] || fail RESULT 'missing RESULT line'
[ "$result" != INVALID ] || fail RESULT 'must be DONE, PARTIAL, or BLOCKED'
[ "$run_seen" -eq 1 ] || fail RUN 'missing RUN line'
[ -n "$log" ] || fail LOG 'missing LOG line'
[ "$verdict_seen" -eq 1 ] && [ -n "$(trim "$verdict")" ] || fail VERDICT 'missing VERDICT line'
[ "$key_lines_seen" -eq 1 ] || fail 'KEY LINES' 'missing KEY LINES section'
[ "$not_run_seen" -eq 1 ] || fail 'NOT RUN' 'missing NOT RUN line'

[ "${#cmd_texts[@]}" -eq "${#expected[@]}" ] || \
  fail CMD "reported ${#cmd_texts[@]} commands; command file has ${#expected[@]}"

for i in "${!cmd_texts[@]}"; do
  wanted_number=$((i + 1))
  [ "${cmd_numbers[$i]}" -eq "$wanted_number" ] || fail CMD 'command records are not numbered in order'
  [ "${cmd_texts[$i]}" = "${expected[$i]}" ] || fail CMD 'command text is not the command file command in that position'
done

lower_verdict="${verdict,,}"
if [[ "$lower_verdict" == *passed* ]]; then
  for exit_code in "${cmd_exits[@]}"; do
    [ "$exit_code" -eq 0 ] || fail VERDICT 'says passed while a command exited non-zero'
  done
fi

printf 'OK run-verify: RESULT %s, %s commands\n' "$result" "${#cmd_texts[@]}"
