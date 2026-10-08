---
description: "Verify a task in Review with the independent qc subagent, then move it to Done or back to Implementing"
argument-hint: "<task-id> [--inline]"
allowed-tools: Bash, Read, AskUserQuestion, Agent, SendMessage
---

Verify a task. Arguments: `$ARGUMENTS`. SKILL_DIR is `${CLAUDE_PLUGIN_ROOT}/skills/rox-workspace`. Read `SKILL_DIR/domains/product/roles/qc.md`. Never edit code or tests to make a failure pass.

1. **Task id** required; ask if missing. Roles other than `qc` are out of role: warn and ask once.
2. **Preflight.** `bash "SKILL_DIR/scripts/preflight.sh" pma`; FAIL stops.
3. **Gate.** Task is in `Review`; its spec has `Status: approved` and a Test plan. Otherwise say what is missing (actual bucket if not Review), stop. Note `git rev-parse HEAD` and whether the tree is clean.
4. **Brief.** Fill `SKILL_DIR/domains/product/templates/qc-brief.md`: project, task id, repo, spec path, commit. Never include the executor's DONE block, TESTS list or any account of how it was built; if it is about to enter, rebuild the brief without it.
5. **Dispatch.** Default: `Agent` with `subagent_type: "rox-workspace:qc"`. `--inline`, or agent unavailable (say so): run the qc method yourself; if this session implemented the task, warn about separation of duties once and record `verifier == implementer` in the review notes.
6. **Sample.** Re-run one command from the plan yourself. A mismatch with the agent's result makes it untrusted: say so and ask.
7. **Move.** `PASS`: move to Done. `FAIL`: move back to `Implementing`, findings stay in the spec's Review notes, name the failing R-id. `NEEDS-INPUT`: ask the user, `SendMessage` the same agent.

Evidence goes in the spec's Review notes; never edit the task note.
