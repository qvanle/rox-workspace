---
description: "Start a rox-workspace session as one or more team roles (po, pm, des, sr-se, jr-se, sa, qa, qc): preflight, role brief, role card"
argument-hint: "[role...] [--domain <domain>]"
allowed-tools: Bash, Read, AskUserQuestion, Agent, SendMessage
---

Bootstrap a role for this session. Arguments: `$ARGUMENTS`. Roles are advisory; read `domains/<domain>/roles/_common.md` for the rules.
The skill's base directory is `${CLAUDE_PLUGIN_ROOT}/skills/rox-workspace` (call it SKILL_DIR below).

Do these steps in order, without extra commentary:

1. **Domain.** Take `--domain` from the arguments, default `product`. Read `SKILL_DIR/domains/README.md`. If the domain is unknown, or its Roles column is `planned`, say it is not defined yet and stop. Do not reuse another domain's roles.
2. **Roles.** Read `SKILL_DIR/domains/<domain>/roles/README.md`. Match each remaining argument (split on spaces and commas) against role ids and aliases, case-insensitive. If there is no argument, or any argument does not match, call `AskUserQuestion` (multi-select) offering every role: label = id, description = its mission. Never map an unknown word to a role by guess (`tester` is not `qa`).
3. **Conflicts.** `sr-se` together with `jr-se` or `entry-se`: keep `sr-se`, drop the other, and say so. `jr-se` with `entry-se` is allowed.
4. **Preflight.** Run `bash "SKILL_DIR/scripts/preflight.sh" all`. On FAIL, print the line and follow the skill's rule: stop that tool, continue with what still works.
5. **Load.** Read `roles/_common.md` and each active role's file (`sr-se`, `jr-se` and `entry-se` all use `se.md`; apply the matching tier).
6. **Brief.** Run `bash "SKILL_DIR/scripts/brief.sh" <ids comma-separated> --domain <domain>`. Show its tables as printed.
7. **Role card.** Print, in under ~25 lines besides the brief: `Active:` ids and domain and mode; `Owns:`; `Hands off (I will warn and ask):` role -> target role pairs; `Next:` one or two actions the brief suggests. Then wait for the user's request.
8. **jr-se / entry-se / qc.** If any is active, from now on act as the relay described in `_common.md` ("Relay mode"), never reading or writing code yourself. `jr-se`: dispatch `Agent` with `subagent_type: "rox-workspace:jr-se"` per task and continue the same agent with `SendMessage` after a `NEEDS-INPUT` answer. `entry-se`: run the Codex job with `scripts/entry-se-run.sh` (start, wait, result, resume) as `_common.md` describes. `qc`: dispatch `rox-workspace:qc` per task as `roles/qc.md` describes (brief from `templates/qc-brief.md`, no executor claims), re-run one plan command yourself, then move the task.

A second bootstrap replaces the active set. Until a bootstrap has run, no role is active and the skill behaves without role rules.
