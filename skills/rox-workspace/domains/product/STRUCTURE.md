# Product domain: structure

Product = the thing the company sells. Wiki collection `RotexAI production` (the roxctl default, so no `--collection` needed
until roxctl R0 exists). pma root project `Product`. Specs live in the **code repo**, never in the wiki.

Fill a template by replacing every `<placeholder>` and deleting every `(guidance)` line. Wiki bodies are Markdown; pma notes are HTML.

## Chain

`vision <- strategy <- tactical <- cycle <- requirement (pma task) <- spec (repo) <- implementation`

Each wiki doc below vision has `realizes:` naming its parent. Link, never copy.

## Which level is this?

1. A reason to exist or a future state: **vision**.
2. A condition, or a choice among ways to get there, lasting months: **strategy**.
3. One initiative with a start, an end and a way to know it worked: **tactical**.
4. A commitment for one sprint, or its result: **cycle**.
5. Something to be built: **requirement** (pma task). How to build it: **spec** (repo). A choice made: **decision**. A fact: **reference**.

## Wiki documents (collection `RotexAI production`)

| Level | Title | Template | Review (`end`) | Stale after |
| --- | --- | --- | --- | --- |
| vision | `Product Vision: <title>` (one active) | `vision.md` | yearly | 400 days |
| strategy | `Production Strategy`, `Pillar <n>: <name>` | `strategy.md` | half-yearly | 200 days |
| tactical | `Tactic: <initiative>` | `tactical.md` | initiative end | 100 days |
| cycle | `Cycles/<YYMMDD-name>` (index doc `Cycles`) | `cycle.md` | sprint end | 14 days |
| decision | `Decisions/<YYMMDD-name>` (index doc `Decisions`) | `decision.md` | none | none |
| reference | any other title | free; first line says what it is for | none | none |

Existing documents keep their titles. Add the header the next time one is edited. Never rename to hide history; move or archive.
`YYMMDD` is the start date (cycle) or the day written (decision, spec). Names are kebab-case.

## Header block (first lines of every wiki doc)

```
> level: <vision|strategy|tactical|cycle|decision|reference> · status: <draft|active|closed|superseded> · owner: <user>
> realizes: <[parent title](url)|none> · depends-on: <links|none>
> start: YYYY-MM-DD · end: YYYY-MM-DD · updated: YYYY-MM-DD
```

Never hand-write `updated`: roxctl stamps it. Pass `--start` and `--end`. A replaced strategy/tactic becomes `superseded`; a
cycle or tactic is `closed` when its outcome is written.

## Create commands

```
roxctl workspace wiki search "<words>" --limit 5          # always first: no duplicates
roxctl workspace wiki create "Tactic: <initiative>" --file F --start D --end D
roxctl workspace wiki create "Cycles/<YYMMDD-name>" --file F --start D --end D
roxctl workspace wiki create "Decisions/<YYMMDD-name>" --file F
```

`create` makes missing parents (stubs) and fails if the leaf exists. Read a doc with `get <id> --raw` before `update`.

## Sprint (pma, Vikunja)

```
Product                  root, no tasks          Backlog      buckets Idea, Refining, Ready
  Backlog                the Product Backlog     <YYMMDD-name> one child project per sprint = the cycle doc title
```

Sprint board buckets: `To do`, `Specifying`, `Implementing`, `Review`, `Done` (Done completes the task). Sprint goal = the sprint
project description (goal + wiki cycle link). Archive the sprint project when it closes.

| Step | Wiki | pma | Role |
| --- | --- | --- | --- |
| Refine | | write requirement tasks into `Backlog`: `Idea`, `Refining`, `Ready` (Ready = note complete) | pm (`Idea` to `Refining`), po (`Ready`) |
| Plan | create `Cycles/<name>` with start/end, goal, scope | create the sprint project, set goal, buckets; move `Ready` tasks in to `To do` | pm |
| Specify | | move to `Specifying`; the spec is written in the code repo by the spec-writing skill (see Spec below). **Never edit the task's note** | sr-se |
| Implement | | `Implementing`, `Review`; the agent implements against R1..Rn and the spec | sr-se, jr-se |
| Done | | move to `Done` (this completes it); the commit or PR goes in the spec file, not the note | qc |
| Close | write Outcome and Retro, `status: closed` | unfinished tasks back to `Backlog` or next sprint; archive the sprint project | pm |

The Role column is advisory (see `roles/README.md`); with no role active nothing changes.

## Requirement task (pma note is HTML, see `templates/requirement.html`)

One task = one requirement. Title is a short imperative. Each requirement is one testable statement with an id (R1..); the note
never says *how*. **The note is the source of truth: after the task is created, no agent edits it** (moving it between buckets or
projects is fine; that is progress, not content). Labels: see below. Priority is urgency; order is drag position.

## Labels: flexible, coloured, never `--force-create`

Labels describe a task at a glance, and **the set is open, not a fixed list**. Read the task, then give it the 3 to 5 labels that
describe it best; when a good label does not exist yet, **create it** (a topic, a customer, a risk, a technology: `payments`,
`onboarding`, `migration`...). Do not squeeze a task into the closest existing label.

Conventions (they keep the board readable; the names below are a starter set, not a limit):

- Most tasks carry a **type**, a **size** and one or two **areas**; add **flags** and **topic** tags as the task needs.
- Prefix a family when it has many values (`size:`, `area:`), leave one-off tags bare (`perf`, `payments`).
- Reuse an existing label when it says the same thing (check `pma label list` first); create a new one only for a new idea.
- When planning or refining, add missing labels to tasks that lack them.

Every label has a colour; `vja --force-create` makes one with **no colour**, which is never accepted. Always:
`roxctl workspace pma label add <title> --color HEX`, then attach. **Choosing the colour of a new label:** keep a family's hue
(areas stay cool, flags warm, sizes amber); for any other new tag take the next vivid hue from the spare list that is not used by an
existing label (`pma label list --json` shows the colours), never grey, white or black.

| Family | Starter set (hex) |
| --- | --- |
| Type | `feature` #2F9E6E · `bug` #E5484D · `chore` #64748B · `research` #8B5CF6 · `docs` #3B82F6 |
| Size | `size:XS` #FCD34D · `size:S` #FBBF24 · `size:M` #F59E0B · `size:L` #EA7C0A · `size:XL` #C2410C |
| Flags | `blocked` #B91C1C · `needs-decision` #F97316 · `needs-info` #EAB308 · `needs-design` #D946EF · `tech-debt` #92400E · `security` #BE185D · `perf` #E11D48 · `breaking` #9F1239 · `quick-win` #84CC16 |
| Executor | `exec:sr` #A855F7 · `exec:jr` #22C55E · `exec:entry` #2DD4BF; set by `sr-se` when a `Ready` task enters a sprint (see `roles/README.md`) |
| Area | `area:<component>`; cool hues #0EA5E9 #14B8A6 #6366F1 #06B6D4 #0284C7 #4F46E5 #0D9488 |
| Spare hues for new topic tags | #F43F5E #A855F7 #22C55E #EAB308 #0EA5E9 #F97316 #EC4899 #14B8A6 #8B5CF6 #65A30D #FB7185 #2DD4BF |

## Spec (code repo)

The wiki and pma are the **source of data** for a spec, not the place it is written or described. To specify a requirement: read the
task (`pma show <id>`), and the tactic and cycle it links; then write the spec with **`superpowers:brainstorming`** (github.com/obra/superpowers): hand it the task note and the tactic and cycle
it links, and tell it the spec location below (its default is `docs/superpowers/specs/`; a stated location overrides it). It is a dialogue
with the user, who approves the written spec; `superpowers:writing-plans` is the step after that, and is not part of this skill. Do not
duplicate their method here. If superpowers is not installed, say so (`/plugin install superpowers@claude-plugins-official`) and fall
back to `templates/spec.md`.
Path `docs/specs/<YYMMDD-name>.md` (or the repo's own specs directory). First line `Requirement: <pma project> #<id>`: the link
runs one way, from the spec to the task. Second line `Status: draft | approved YYYY-MM-DD (<user>, sr-se) | superseded`: `jr-se`
implements only an approved spec; a spec with no Status line counts as not approved. Sections cite R-ids; the test plan maps tests to them.

## Formatting wiki documents

Wiki bodies use Outline's full Markdown so they read at a glance; the templates already do. Use: emoji in section headings, `---`
between parts, tables for anything with columns, `:::info` (summary), `:::warning` (gap, risk), `:::success` (decision, belief),
`:::tip` (needed decision) callouts, `==highlight==` for the one phrase that matters, `- [ ]` checklists for things that get ticked,
and 👍/🔧/🗑️ style markers in tables. One callout per idea; do not wrap whole sections in them.

## Do not

Put tasks in the wiki; put designs in pma; edit a task's note after it is created; write secrets anywhere; say "tenant" (say "project"); delete when archive will do;
edit a doc without reading it first.
