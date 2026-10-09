# pma (Vikunja) through `roxctl workspace pma`

Read before any pma write. Task notes and project descriptions are **HTML** (`<h2>`, `<p>`, `<ul>`, `<ol>`, `<table>`,
`<strong>`, `<a href>`); never Markdown. Write long HTML to a file and pass it: `--note "$(cat /path/note.html)"`.

## Addressing

`roxctl workspace pma <PROJECT> <action>`; `PROJECT` is a numeric id or a title (regex) and is needed only by `list`, `add`
and `bucket`. `show`, `edit`, `delete`, `toggle` take a task id. `edit` does **not** forward PROJECT, because `vja edit
--project` moves the task.

## Tasks

```
roxctl workspace pma <backlog id> add "Owners can see each step input and output" \
  --note "$(cat note.html)" --label feature --label size:M --label area:portal --prio 3
roxctl workspace pma <backlog id> list                  # tasks of a project
roxctl workspace pma show 42                            # includes the note, labels, project, bucket
roxctl workspace pma edit 42 --project 261012-trace-viewer   # move into a sprint (the id stays 42)
roxctl workspace pma edit 42 --bucket-id 17             # move to a bucket; ids from `bucket ls`
roxctl workspace pma toggle 42                          # flips done
```

`vja` flags that matter: `--label` (repeatable; the label must exist), `--prio 1-5`, `--start D`, `--end D`, `--due D`.

## Labels: coloured, created first

`--force-create` makes a label with **no colour**: never use it. See what exists first, create only what is missing, then attach:

```
roxctl workspace pma label list                    # id and title; --json (before the tool) also shows each colour
roxctl workspace pma label add "size:M" --color F59E0B
roxctl workspace pma label edit <id> --color F59E0B      # fix a colour later
```

The label set is open. `STRUCTURE.md` (Labels) has the conventions, a starter set with hex colours and a list of spare hues. Describe
each task with the 3 to 5 labels that fit; if none fits, create a new label with the next unused vivid hue. Keep the families'
colours (areas cool, flags warm, sizes amber) and never leave a label without a colour.

## Sprint project and buckets

```
roxctl workspace pma project add "Trace viewer" --parent Product          # the tactic project, once
roxctl workspace pma project add "Backlog" --parent <tactic id>         # its backlog, once
roxctl workspace pma project add "261012-trace-viewer" --parent <tactic id>   # a sprint of that tactic
roxctl workspace pma project edit 261012-trace-viewer --description-file goal.html   # sprint goal + wiki link, HTML
roxctl workspace pma 261012-trace-viewer bucket add "To do"      # then Specifying, Implementing, Review, Done
roxctl workspace pma 261012-trace-viewer bucket ls               # ids for --bucket-id
roxctl workspace pma project edit 261012-trace-viewer --archive  # when the sprint closes
roxctl workspace pma project list
```

The tree is `<domain>/{Backlog, <tactic>/{Backlog, <YYMMDD-sprint>}}` (`<domain>/Backlog` is the strategy backlog); many projects are called `Backlog`, so address them by id (`project list` shows ids and `--json` shows `parent_project_id`). Backlog buckets are `Idea`, `Refining`, `Ready`. `project edit` reads the project and changes only what you pass. A title that
matches two projects is an error; pass the id.

## Moving through the board

Specifying -> Implementing -> Review -> Done is `pma edit <id> --bucket-id <n>`. If a task in `Done` is not marked done,
run `pma toggle <id>` (check with `pma show`). Closing a sprint: move unfinished tasks to `Backlog` or the next sprint with
`pma edit <id> --project ...`, then archive the sprint project.

## The note is not edited

A task's note is the requirement, the source of truth. After the task is created **do not change its note or title** (no spec link,
no commit, no "clarifications"; raise questions with the user). Progress is expressed only by bucket, project, done state and
labels. If the requirement itself must change, the user changes it.

## Requirement note

Use `domains/<domain>/templates/requirement.html`. One requirement = one testable statement with an id (R1..); say what, never
how. There is no Spec section: the spec file points back at the task. A dependency is a line in the note written when the task is created
(there is no relation command yet).

## Known limits

- `vja` has a token in `~/.config/vja/config.rc`; when it expires every pma command fails with exit 3 (preflight reports it).
- `bucket ls` and `bucket add` act on the project's first Kanban view only.
- No relation command and no way to set a view's done bucket; do that once in the Vikunja UI.
- Observed 2026-10-09 (not diagnosed): after `pma edit <id> --project <p>` moves a task, `pma edit <id> --bucket-id <n>` reports "Modified" but the task stays in `To-Do`; check with `bucket ls` and move it in the Vikunja UI if so. `project edit --archive` returned `405 Method Not Allowed` on Vikunja 2.6.
- A new project starts with `To-Do`, `Doing`, `Done` buckets, which the CLI cannot delete or rename.
- Deleting a task is permanent: confirm with the user first.
