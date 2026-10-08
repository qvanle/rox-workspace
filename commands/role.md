---
description: "Show or switch the active roles without re-running preflight"
argument-hint: "[role...|+role|-role|none] [--domain <domain>]"
allowed-tools: Read, AskUserQuestion
---

Roles. Arguments: `$ARGUMENTS`. SKILL_DIR is `${CLAUDE_PLUGIN_ROOT}/skills/rox-workspace`. No preflight, no side effects.

- No argument: print the active roles in a table (mode, owns, gates, hand-offs) from `SKILL_DIR/domains/<domain>/roles/`, or "No role active" plus the valid roles.
- `role a b`: replace the set (union). `+x` adds, `-x` removes, `none` clears. `--domain` switches domain and clears the set.
- Match ids and aliases from `roles/README.md`. An unknown word: list the valid roles and ask with `AskUserQuestion`; never guess.
- `sr-se` with `jr-se`/`entry-se`: keep `sr-se`, say so. A separation-of-duties pair (for example `sr-se` with `qc`) is allowed with one warning.
- Switching to `jr-se`, `entry-se` or `qc` turns relay mode on (see `_common.md`): say so.
- Print the card (Active, Owns, Hands off) and one line: "active: ...". Advisory only; the set lives in the conversation.
