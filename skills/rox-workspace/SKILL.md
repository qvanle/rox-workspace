---
name: rox-workspace
description: Work in the RotexAI workspace through roxctl - the Outline wiki (wiki.rotexai.com) and the pma project manager (Vikunja). Use this skill whenever the user wants to read, search, write, update, move, archive or delete a wiki/Outline document; write a vision, strategy, tactic, sprint/cycle doc, decision or spec; create, plan, refine or close tasks, requirements, backlog items or sprints in pma/Vikunja; or run the daily check for stale docs - even if they only say "write that up", "note this down", "add a task", "plan the sprint", "what is stale", "what did we decide". Always use it instead of browser automation, raw ol/vja, or a local file. Works in any project.
---

# rox-workspace

Keeps the wiki (why, intent, outcome) and pma (requirements, progress) consistent through `roxctl workspace` only.
A task in pma is a requirements document and the **source of truth: never edit a task's note after it is created**. The wiki and pma
are the source of data; the spec is written in the code repo with the `superpowers:brainstorming` skill (github.com/obra/superpowers).

## 1. Preflight (first, once per session)

Run `bash <skill base dir>/scripts/preflight.sh wiki|pma|all` (`<skill base dir>` is printed when this skill loads; `wiki` for wiki-only work, `pma` for tasks only,
`all` for both). It prints one line per tool: `OK ...` or `FAIL <tool>: <what> -- <fix>`.

On FAIL: tell the user the line, say what you were about to do, and **stop that tool**. Do not retry, do not use a browser,
raw `ol`/`vja`/`curl`, and do not write the content to a local file instead. A missing or unauthenticated tool is a setup
problem only the user can fix. Wiki and pma fail independently; do the part that still works, but stop before a task
that needs both.

## 2. Commands

| Intent | Command (all start `roxctl workspace`) |
| --- | --- |
| Find | `wiki search "<words>" --limit 5`, then `wiki get <id> --raw` |
| Create | `wiki create "<path/Title>" --file F --start D --end D` |
| Update | `wiki get <id> --raw`, edit, `wiki update <id> --file F` |
| Move, archive, delete | `wiki move <id> --parent <p>`, `wiki archive <id>`, `wiki delete <id> --confirm` |
| Stale | `wiki stale [--collection C] [--all]` |
| Another domain | add `--collection "<name>"` (see `domains/README.md`); default is `RotexAI production` |
| Task | `pma <PROJECT> add "<title>" --note "$(cat F.html)" --label L ...`, `pma show <id>`, `pma edit <id> ...`, `pma toggle <id>` |
| Sprint | `pma project add "<name>" --parent Product`, `pma project edit <name> --description-file F`, `--archive` |
| Buckets, labels | `pma <PROJECT> bucket ls`, `pma label list`, `pma label add "<title>" --color HEX` |

Dates are `YYYY-MM-DD`. `--json` goes before the tool. Details: `references/wiki.md` before a wiki write,
`references/pma.md` before a pma write, `references/header.md` before creating or updating a doc.

## 3. Domain and level

Read `domains/README.md` (15 lines) to find the domain. If it is `planned`, tell the user it is not defined yet and stop;
do not reuse another domain's structure. Otherwise read `domains/<domain>/STRUCTURE.md`: it has the levels (vision, strategy,
tactical, cycle, decision, reference), titles, the sprint layout, labels and the "which level is this?" rule. Fill the
matching file in `templates/`; `examples/` shows one filled in. Load an example only when you need it.

## 4. Workflows (load only what the row names)

| Workflow | Steps | Load |
| --- | --- | --- |
| Find | search, get the one best hit, answer with title and link. If nothing relevant turns up in two searches, say so and stop: do not read unrelated documents | nothing |
| Create doc | search for a duplicate, pick level, fill template with `realizes:` the parent, create with dates | wiki.md, header.md, STRUCTURE.md, one template |
| Edit doc | get raw, change only what was asked, update | wiki.md, header.md |
| Plan cycle | cycle doc `Cycles/<YYMMDD-name>`, sprint project of the same name, move **each** `Ready` task in (one `pma edit <id> --project` per task), add any missing type, size or area label to a task that lacks them, list ids in Scope | wiki.md, pma.md, STRUCTURE.md, cycle.md |
| Requirement | write the HTML note, add to `Backlog` with 3 to 5 labels that describe it (usually type, size, area; create new labels for new ideas) | pma.md, requirement.html |
| Specify | read the task and what it links (`pma show`, `wiki get`), move the task to `Specifying`, then invoke `superpowers:brainstorming` with the task note and linked tactic as its input and the location `docs/specs/<YYMMDD-name>.md` in the code repo. The spec starts with `Requirement: <project> #<id>`; the note stays untouched. If superpowers is not installed, tell the user (`/plugin install superpowers@claude-plugins-official`) and use `spec.md` meanwhile | pma.md, STRUCTURE.md |
| Implement | task to `Implementing`, `Review`, `Done`; the commit or PR is recorded in the spec file | pma.md |
| Close cycle | Outcome and Retro in the cycle doc, unfinished tasks out, archive the sprint project | wiki.md, pma.md, cycle.md |
| Daily check | preflight, `wiki stale`, table of what is overdue, offer a review task per stale doc | pma.md only if tasks are made |

## 5. Rules, and why

- `roxctl workspace` only: it is the audited route, and it stamps dates the model would get wrong.
- Wiki bodies are Markdown; pma notes are HTML (Vikunja stores HTML). Mixing them renders as junk.
- Make wiki documents easy to scan: fill the template as given (emoji headings, callouts, tables, checklists, highlights); do not flatten it to plain text.
- Tasks get 3 to 5 labels that describe them at a glance. The label set is open: when none fits, create a new one, always with a colour.
- Never edit an existing task's note or title; change only its progress (bucket, project, done, labels).
- Search before create, read before update: `update` replaces the body, near-duplicates are silent.
- Never write `updated` by hand; pass `--start`/`--end`, roxctl stamps the rest.
- Check `pma label list`, reuse a label that already says the same thing, create the missing ones with `pma label add --color`, then use them. Never `--force-create`: it makes a colourless label.
- Confirm before delete or a bulk move; prefer archive. No secrets in docs or notes. Say "project", not "tenant".
- Link, never copy, between wiki, pma and the spec file, so only one place can go stale.

## 6. Roles (only after `/rox-workspace:bootstrap`)

If a role is active, follow `domains/<domain>/roles/_common.md` and that role's file. Before an action another role owns, warn and ask;
reading is never out of role. With no role active, ignore this section.
