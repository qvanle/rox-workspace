# Run mode brief

Repo: <REPO>

Execute only the command lines from the command file below, verbatim and in order. Do not improvise, fix commands, probe, or retry unless a comment in the file says `retry: 1`. A line beginning with `#` is a comment; the `id`, `repo`, `mode`, and `question` lines are metadata, not commands. Never print secrets.

Run each command with a maximum time limit of 15 minutes per job. Stop a command at its time limit and report `TIMEOUT`; do not retry it. Create `.codex-runs/` if needed. Save the full output in `<REPO>/.codex-runs/<job-id>.log`, including each exact command, its exit code, and its full output. In a `read-only` run, write nothing except that log.

If any command contains a refused word or path, do not run any commands; return `RESULT: BLOCKED`. Refused items: `git commit`, `git push`, `git reset`, `git checkout --`, `rm -rf`, `kubectl`, `kubeseal`, `ansible-playbook`, `ssh`, `curl` with `-X POST|PUT|DELETE` or `--request POST|PUT|DELETE`, `roxctl` with any write verb (`add`, `edit`, `delete`, `toggle`, `create`, `update`, `move`, `archive`, `unarchive`, `seal`, `sync`, `rollback`, `terminate-op`, `apply`, `patch`), any token containing `env/`, or any token containing `.sealedsecret`.

Command file (metadata and commands, supplied verbatim):

<COMMANDS>

Answer the file's `question` using only the command output. Use the command-file `id` for `RUN`. End with exactly this return block, with one `CMD` line per command that ran:

```text
RESULT: DONE | PARTIAL | BLOCKED
RUN: <id>
LOG: <repo-relative path of the raw log>
CMD 1: <command> -> exit <code> (<seconds>s)
VERDICT: <one line: all passed | n failed | could not run>
KEY LINES:
  <at most 15 lines copied verbatim from the log: failures, error messages, counts>
NOT RUN: <commands skipped and why>
```
