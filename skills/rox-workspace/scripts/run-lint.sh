#!/usr/bin/env bash
# Strict, line-oriented validator for a run-mode command file.
# Refused words are scanned conservatively, even inside quoted grep patterns.
set -u
export LC_ALL=C

usage() {
  echo 'usage: run-lint.sh <command-file>' >&2
  exit 2
}
fail_line() {
  printf 'FAIL line %s: %s\n' "$1" "$2"
  exit 1
}
trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

[ $# -eq 1 ] || usage
command_file="$1"
[ -f "$command_file" ] && [ -r "$command_file" ] || {
  echo 'FAIL line 1: command file is missing or unreadable'
  exit 1
}
if ! LC_ALL=C tr -d '\000' < "$command_file" | cmp -s - "$command_file"; then
  fail_line 1 'NUL byte in command file'
fi

# Validate syntax without evaluating any part of the command line.
simple_command_line() {
  local value="$1" quote='' escaped=0 ampersands=0 i=0 c next segment=''
  local length=${#value} left=''
  while [ "$i" -lt "$length" ]; do
    c="${value:i:1}"
    next=''
    [ $((i + 1)) -lt "$length" ] && next="${value:i+1:1}"

    if [ "$escaped" -eq 1 ]; then
      escaped=0
      segment+="$c"
      i=$((i + 1))
      continue
    fi

    if [ "$quote" = "'" ]; then
      [ "$c" = "'" ] && quote=''
      segment+="$c"
      i=$((i + 1))
      continue
    fi

    if [ "$quote" = '"' ]; then
      if [ "$c" = $'\\' ]; then
        escaped=1
      elif [ "$c" = '"' ]; then
        quote=''
      elif [ "$c" = '$' ] && [ "$next" = '(' ]; then
        return 1
      elif [ "$c" = '`' ]; then
        return 1
      fi
      segment+="$c"
      i=$((i + 1))
      continue
    fi

    case "$c" in
      "'") quote="'" ;;
      '"') quote='"' ;;
      $'\\') escaped=1 ;;
      '`' | ';' | '|' | '>' | '<') return 1 ;;
      '$')
        if [ "$next" = '(' ] || [ "$next" = "'" ]; then return 1; fi
        segment+="$c"
        ;;
      '&')
        if [ "$next" != '&' ] || [ "$ampersands" -ne 0 ]; then return 1; fi
        if [ $((i + 2)) -lt "$length" ] && [ "${value:i+2:1}" = '&' ]; then return 1; fi
        left="$(trim "$segment")"
        [ -n "$left" ] || return 1
        segment=''
        ampersands=1
        i=$((i + 1))
        ;;
      *) segment+="$c" ;;
    esac
    i=$((i + 1))
  done

  [ -z "$quote" ] && [ "$escaped" -eq 0 ] || return 1
  [ -n "$(trim "$segment")" ] || return 1
  return 0
}

refused_command() {
  local value="${1,,}" normalized verb
  # Removing quote marks catches spellings such as git "commit" too.
  normalized="${value//\'/}"
  normalized="${normalized//\"/}"

  for verb in 'git commit' 'git push' 'git reset' 'git checkout --' 'rm -rf' \
    kubectl kubeseal ansible-playbook; do
    [[ "$normalized" == *"$verb"* ]] && return 0
  done
  [[ "$normalized" == *'ssh '* ]] && return 0
  [[ "$normalized" == *'env/'* || "$normalized" == *'.sealedsecret'* ]] && return 0

  if [[ "$normalized" =~ (^|[[:space:]])curl([[:space:]]|$) ]] &&
     [[ "$normalized" =~ [[:space:]](-x|--request)(=|[[:space:]]*)(post|put|delete)([[:space:]]|$) ]]; then
    return 0
  fi

  if [[ "$normalized" == *roxctl* ]]; then
    for verb in add edit delete toggle create update move archive unarchive seal sync rollback terminate-op apply patch; do
      [[ "$normalized" == *"$verb"* ]] && return 0
    done
  fi
  return 1
}

id_seen=0
mode_seen=0
repo_seen=0
question_seen=0
mode=''
command_count=0
line_number=0

while IFS= read -r line || [ -n "$line" ]; do
  line_number=$((line_number + 1))
  # Accept CRLF files while rejecting embedded control characters below.
  line="${line%$'\r'}"
  if [[ "$line" == *$'\r'* ]]; then
    fail_line "$line_number" 'control character in line'
  fi
  [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue

  if [[ "$line" =~ ^[[:space:]]*id: ]]; then
    [ "$id_seen" -eq 0 ] || fail_line "$line_number" 'duplicate id header'
    value="$(trim "${line#*id:}")"
    [[ "$value" =~ ^[[:alnum:]][[:alnum:]_-]*$ ]] || fail_line "$line_number" 'invalid id header'
    id_seen=1
    continue
  fi
  if [[ "$line" =~ ^[[:space:]]*mode: ]]; then
    [ "$mode_seen" -eq 0 ] || fail_line "$line_number" 'duplicate mode header'
    mode="$(trim "${line#*mode:}")"
    [[ "$mode" = read-only || "$mode" = write ]] || fail_line "$line_number" 'mode must be read-only or write'
    mode_seen=1
    continue
  fi
  if [[ "$line" =~ ^[[:space:]]*repo: ]]; then
    [ "$repo_seen" -eq 0 ] || fail_line "$line_number" 'duplicate repo header'
    value="$(trim "${line#*repo:}")"
    [[ "$value" = /* ]] || fail_line "$line_number" 'repo must be an absolute path'
    repo_seen=1
    continue
  fi
  if [[ "$line" =~ ^[[:space:]]*question: ]]; then
    [ "$question_seen" -eq 0 ] || fail_line "$line_number" 'duplicate question header'
    value="$(trim "${line#*question:}")"
    [ -n "$value" ] || fail_line "$line_number" 'question must not be empty'
    question_seen=1
    continue
  fi

  if refused_command "$line"; then
    fail_line "$line_number" 'refused command or path'
  fi
  simple_command_line "$line" || fail_line "$line_number" 'shell metacharacter, continuation, or invalid quoting'
  command_count=$((command_count + 1))
  [ "$command_count" -le 10 ] || fail_line "$line_number" 'more than 10 commands'
done < "$command_file"

[ "$id_seen" -eq 1 ] || fail_line "$((line_number + 1))" 'missing id header'
[ "$mode_seen" -eq 1 ] || fail_line "$((line_number + 1))" 'missing mode header'
printf 'OK %s commands, mode %s\n' "$command_count" "$mode"
