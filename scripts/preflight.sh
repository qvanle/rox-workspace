#!/usr/bin/env bash
# rox-workspace preflight. Usage: preflight.sh [wiki|pma|all]   (default: all)
# Prints one line per tool: "OK <tool>" or "FAIL <tool>: <what> -- <fix>". Exit 1 if any line is FAIL.
# roxctl prints build chatter on stderr when it rebuilds itself, so stderr is discarded and only exit codes count.
# Overrides (also used by tests with fake binaries): ROXCTL_BIN, ROXCTL_OL_BIN, ROXCTL_VJA_BIN.

want="${1:-all}"
case "$want" in wiki | pma | all) ;; *)
  echo "usage: preflight.sh [wiki|pma|all]" >&2
  exit 2
  ;;
esac

roxctl_bin="${ROXCTL_BIN:-roxctl}"
ol_bin="${ROXCTL_OL_BIN:-ol}"
vja_bin="${ROXCTL_VJA_BIN:-vja}"
rc=0

fail() {
  echo "FAIL $1: $2 -- $3"
  rc=1
}

if ! command -v "$roxctl_bin" >/dev/null 2>&1; then
  fail roxctl "not on PATH" "build it: cd <aos>/codebase/control-plane/roxctl && cargo install --path ."
  exit 1
fi

if [ "$want" = wiki ] || [ "$want" = all ]; then
  if ! command -v "$ol_bin" >/dev/null 2>&1; then
    fail wiki "ol not found" "npm install -g @doist/outline-cli, then run: ol auth login"
  elif ! "$roxctl_bin" workspace wiki list --limit 1 >/dev/null 2>&1; then
    fail wiki "ol is not authenticated or Outline is unreachable" "run: ol auth status, then ol auth login"
  else
    echo "OK wiki"
  fi
fi

if [ "$want" = pma ] || [ "$want" = all ]; then
  if ! command -v "$vja_bin" >/dev/null 2>&1; then
    fail pma "vja not found" "install https://github.com/cernst72/vja, then log in once: vja -u <user> -p <password> ls"
  elif ! "$roxctl_bin" workspace pma project list >/dev/null 2>&1; then
    fail pma "vja token missing or expired, or Vikunja is unreachable" "renew api_token in ~/.config/vja/config.rc (log in once: vja -u <user> -p <password> ls)"
  else
    echo "OK pma"
  fi
fi

exit "$rc"
