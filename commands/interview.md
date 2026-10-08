---
description: "Interview the developer about what they want to build: research first, one question at a time, ends in a draft requirement note"
argument-hint: "[topic]"
allowed-tools: Bash, Read, AskUserQuestion, Agent, SendMessage
---

Interview. Arguments: `$ARGUMENTS`. SKILL_DIR is `${CLAUDE_PLUGIN_ROOT}/skills/rox-workspace`. Requirement notes use `SKILL_DIR/domains/product/templates/requirement.html`. Write nothing to pma or the wiki before an explicit yes.

1. **Research** (skip with a line if there is no topic; ask for the topic first): `roxctl` wiki search and pma search for the topic; code facts only through the `collect` flow (`/rox-workspace:collect` steps), never read code inline. Show an "already known" table with sources. Preflight failures turn this into a note, not a stop.
2. **Interview.** One `AskUserQuestion` per turn, recommended option first with "(Recommended)", 2 to 4 options. Order: problem and who has it, outcome and measure, scope and non-goals, constraints, risks, priority. Skip what sources settle (state it as an assumption). "Later" becomes a non-goal. Shape questions by active role: po value and priority; pm dates and dependencies; des flows and states; sr-se boundaries and risk; qa what done looks like as a test; sa environments and rollout; none = po set. Stop when problem, outcome, scope and a non-goal exist, or after 8 questions; the rest become open questions.
3. **Draft** the requirement note in HTML (h2: Problem, Outcome, Scope, Non-goals, Constraints, Risks, Open questions, Ideas, Sources) plus suggested labels and state (`Refining` if the stop rule was met, else `Idea`), in the reply only. Volunteered solutions go under Ideas. Never copy secrets; point at the seal-secret skill.
4. **Confirm.** Ask whether to create the task. On no, stop; the draft stays in the reply.
5. **Hand off.** On yes, write the HTML to a scratch file and create the task with roxctl pma (check `--help`). Name the next step: spec flow (sr-se), a decision doc (po), or `collect` for an open code question.
