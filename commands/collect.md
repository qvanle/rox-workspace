---
description: "Answer a read-only question by splitting it between Codex (code) and Haiku jr-se (roxctl reads), with sources"
argument-hint: "\"<question>\" [--tier light|standard|complex]"
allowed-tools: Bash, Read, AskUserQuestion, Agent, SendMessage
---

Collect information. Arguments: `$ARGUMENTS`. SKILL_DIR is `${CLAUDE_PLUGIN_ROOT}/skills/rox-workspace`. Read `SKILL_DIR/domains/product/roles/collect.md` and use `SKILL_DIR/domains/product/templates/collect-brief.md`. Everything is read-only; do not read the sources yourself.

1. **Question** required; ask if missing.
2. **Preflight** `bash "SKILL_DIR/scripts/preflight.sh" all`; a FAIL drops the pieces that need that tool, say so.
3. **Break down** into at most 6 pieces over at most 3 repos (tell the user what was left out). Table: piece, target, executor. Show it before dispatch if more than 3 pieces.
4. **Route.** Code in a repo -> `entry`: merge pieces of one repo into one job, run from inside it `scripts/entry-se-run.sh --tier T start <repo> <brief> --read-only` (one job per repo, different repos in parallel). roxctl reads -> `Agent` `rox-workspace:jr-se` with `MODE: collect`. Codex unavailable: code pieces go to jr-se; if nothing is available ask before reading inline. Refuse pieces that read `env/` or secrets (point at the seal-secret skill).
5. **Wait** with `entry-se-run.sh wait <job>`, then `result`. A read-only job whose result reports changes is a violation: discard it and say so.
6. **Check** one cited `file:line` per code result against the file.
7. **Merge** into one table: finding, source (`file:line` or roxctl command). Drop or label unsourced claims; list gaps and PARTIAL/BLOCKED pieces. No executor chatter.
