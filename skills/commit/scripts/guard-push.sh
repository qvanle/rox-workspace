#!/usr/bin/env bash
# Heuristic PreToolUse guard; parses text, never evaluates the command.
# Overrides for tests: JQ_BIN, GIT_BIN, ROX_GUARD_SCOPE (glob; default: the aos workspace and its nested repos). Fail open if jq is unavailable.
# Plugin hooks run for every Bash call in every project, so the guard only acts inside the aos workspace.
set -uo pipefail
jq_bin=${JQ_BIN:-jq}
command -v "$jq_bin" >/dev/null 2>&1 || exit 0
payload=$(cat)
command_text=$(printf '%s' "$payload" | "$jq_bin" -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$command_text" ] || exit 0
hook_cwd=$(printf '%s' "$payload" | "$jq_bin" -r '.cwd // empty' 2>/dev/null) || hook_cwd=
hook_cwd=${hook_cwd:-$PWD}
block() { echo 'Blocked git push: only main is permitted; no force, mirror or tags. Use the commit skill push-all.sh after approval.' >&2; exit 2; }
# Shell punctuation becomes a boundary. Quotes are stripped only for comparison.
command_text=${command_text//$'\n'/ ; }
command_text=${command_text//;/ ; }
command_text=${command_text//&/ ; }
command_text=${command_text//|/ ; }
read -r -a words <<< "$command_text"
clean() { token=${1//\"/}; token=${token//\'/}; }
curdir=$hook_cwd
for ((i=0; i<${#words[@]}; i++)); do
  clean "${words[i]}"
  case "$token" in
    git|*/git) ;;
    cd) # an in-command cd changes where a later git push runs (treated as persistent: conservative)
      if [ $((i + 1)) -lt "${#words[@]}" ]; then
        clean "${words[i+1]}"
        case "$token" in /*) curdir=$token ;; ''|-|\;) ;; *) curdir="$curdir/$token" ;; esac
      fi
      continue ;;
    *) continue ;;
  esac
  dir=$curdir
  j=$((i + 1))
  in_scope() { # $1 = path of the repo the push runs in
    local p=$1 top
    top=$("${GIT_BIN:-git}" -C "$p" rev-parse --show-toplevel 2>/dev/null) && p=$top
    if [ -n "${ROX_GUARD_SCOPE:-}" ]; then [[ $p == $ROX_GUARD_SCOPE ]]; return; fi
    case "$p" in */aos|*/aos/*) return 0 ;; *) return 1 ;; esac
  }
  # Support the common git global options before push.
  while [ "$j" -lt "${#words[@]}" ]; do
    clean "${words[j]}"
    case "$token" in
      -C)
        j=$((j + 1)); [ "$j" -lt "${#words[@]}" ] || break
        clean "${words[j]}"
        case "$token" in /*) dir=$token ;; *) dir="$dir/$token" ;; esac
        ;;
      -c|--git-dir|--work-tree) j=$((j + 1)) ;;
      --git-dir=*|--work-tree=*|--no-pager|--no-optional-locks) ;;
      *) break ;;
    esac
    j=$((j + 1))
  done
  [ "$j" -lt "${#words[@]}" ] || continue
  clean "${words[j]}"; [ "$token" = push ] || continue
  in_scope "$dir" || continue
  positional=0
  for ((j=j+1; j<${#words[@]}; j++)); do
    clean "${words[j]}"
    case "$token" in
      ';'|'<'|'>'|2\>*|1\>*) break ;;
      --force*|--mirror*|--tags*|--all|--branches|--delete|-d) block ;;
      --repo=*) positional=1; continue ;;
      --repo) positional=1; j=$((j + 1)); continue ;;
      --receive-pack|--exec|--push-option|-o) j=$((j + 1)); continue ;;
      --) continue ;;
      -*)
        # Compact flags such as -uf are force too; -f is always blocked.
        [[ "$token" =~ ^-[^-]*f ]] && block
        continue ;;
    esac
    positional=$((positional + 1))
    [ "$positional" -gt 1 ] || continue # first positional argument is a remote
    case "$token" in
      main|refs/heads/main|main:main|main:refs/heads/main|refs/heads/main:main|refs/heads/main:refs/heads/main) ;;
      *) block ;;
    esac
  done
  git_bin=${GIT_BIN:-git}
  if command -v "$git_bin" >/dev/null 2>&1; then
    top=$("$git_bin" -C "$dir" rev-parse --show-toplevel 2>/dev/null) || top=
    parent=$("$git_bin" -C "$dir" rev-parse --show-superproject-working-tree 2>/dev/null) || parent=
    # Every in-scope push needs the current branch to be main: an implicit push sends the current branch, and
    # work on another branch stays local even when the refspec names main.
    if [ -n "$top" ]; then
      branch=$("$git_bin" -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=DETACHED
      [ "$branch" = main ] || block
    fi
  fi
done
exit 0
