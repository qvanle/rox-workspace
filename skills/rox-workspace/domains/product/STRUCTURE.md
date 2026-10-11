# Product domain: structure

Product = the thing the company sells. Wiki collection `RotexAI production` (the roxctl default, so no `--collection` needed
until roxctl R0 exists). pma root project `Product`. Specs live in the **code repo**, never in the wiki.

Fill a template by replacing every `<placeholder>` and deleting every `(guidance)` line. Wiki bodies are Markdown; pma notes are HTML.

## Chain

`pillar -> strategy -> tactic -> plan -> cycle`, then `requirement (pma task) <- spec (repo) <- implementation`.

Every wiki document is a child of the one before it in the chain, in the Outline tree and in its `realizes:` line. There is no other
kind of wiki document: **a decision is a section of its tactic, a reference is a section of the document that uses it.** No
`Decisions`, `Cycles` or `References` folder, no document at the collection root except a pillar (and the one `Product Vision`, which
a pillar names in `realizes:` and which has no parent).

## Wiki documents (collection `RotexAI production`)

| Level | Title (the prefix is mandatory) | Parent | Template | Review (`end`) | Stale after |
| --- | --- | --- | --- | --- | --- |
| vision | `Product Vision: <title>` (one active, the only unprefixed document) | none | `vision.md` | yearly | 400 days |
| pillar | `Pillar <id>: <name>` | none (root) | `pillar.md` | half-yearly | `end` only |
| strategy | `Strategy <id>: <name>` | a pillar | `strategy.md` | half-yearly | 200 days |
| tactical | `Tactic <id>: <initiative>` | a strategy | `tactical.md` | initiative end | 100 days |
| plan | `Plan <id>: <name>` | a tactic | `plan.md` | plan end | `end` only |
| cycle | `Cycle <id>: <YYMMDD-name>` | a plan | `cycle.md` | sprint end | 14 days |

`<id>` is a whole number, one sequence per level, never reused (an archived document keeps its id). The next free id comes from
`bash <skill base dir>/scripts/wiki-guard.sh next <level>`. `<YYMMDD-name>` is the cycle's start date and a kebab-case name; the pma
sprint project has exactly that name. The header `level:` values are `vision`, `pillar`, `strategy`, `tactical`, `plan`, `cycle`.

A plan is the sequence of cycles that delivers one tactic (its goal, the order of the cycles, the exit test). A tactic may have more
than one plan over time; a cycle belongs to exactly one plan, and so to one tactic.

## Which level is this?

1. A reason to exist or a future state: **vision**.
2. A durable direction the company holds for years: **pillar**.
3. A condition, or a choice among ways to serve a pillar, lasting months: **strategy**.
4. One initiative with a start, an end and a way to know it worked: **tactic**.
5. The order of sprints that delivers a tactic: **plan**. One sprint's commitment and result: **cycle**.
6. Something to be built: **requirement** (pma task). How to build it: **spec** (repo).
7. A choice made, or a fact someone must look up: **not a document**. Write it into the section below, in the tactic or cycle that needs it.

### Decisions and references live inside a document

| Thing | Where | How |
| --- | --- | --- |
| Decision | `## 🧭 Decisions` in the **tactic** it serves | One dated entry per decision (format in `tactical.md`). A changed decision is a new entry; the old one is marked `superseded`, never edited away. A decision two tactics need lives in one and the other links to its heading |
| Reference (a fact, a diagram, a lookup table) | `## 📚 References` in the **document that uses it** (any level) | Written in that document. A second document that needs it links to the section, never copies it |

Nothing is written when there is no tactic to hold it: ask `po` or `pm` which tactic it belongs to, or propose a new one.

## Header block (first lines of every wiki document)

```
> level: <vision|pillar|strategy|tactical|plan|cycle> · status: <draft|active|closed|superseded> · owner: <user>
> realizes: <[parent title](url)|none> · depends-on: <links|none>
> start: YYYY-MM-DD · end: YYYY-MM-DD · updated: YYYY-MM-DD
```

Never hand-write `updated`: roxctl stamps it. Pass `--start` and `--end`. A replaced pillar, strategy or tactic becomes `superseded`; a
plan, cycle or tactic is `closed` when its outcome is written. `realizes:` names the **parent in the tree** (a pillar names the vision).

## Create commands

Never create a document that does not follow the chain. `roxctl workspace wiki create` accepts any `/` path and silently makes
missing ancestors as stubs, so the guard runs first and must pass:

```
roxctl workspace wiki search "<words>" --limit 5          # always first: no duplicates
bash <skill base dir>/scripts/wiki-guard.sh next tactic   # next free id for a level
bash <skill base dir>/scripts/wiki-guard.sh check "Pillar 1: Radical Accessibility/Strategy 2: <name>/Tactic 5: <initiative>"
roxctl workspace wiki create "Pillar 1: Radical Accessibility/Strategy 2: <name>/Tactic 5: <initiative>" --file F --start D --end D
```

The path is the full chain down to the new document, each segment the exact title of an existing ancestor. The guard fails (exit 1,
nothing is created) when a title lacks its prefix, a level is skipped or out of order, an ancestor does not exist, the id is already
used at that level, or the leaf exists. A pillar is `create "Pillar <id>: <name>"` alone. The same rules apply to `update --title`
and `move --parent`: the new title keeps its prefix, the new parent is the level above.

## Sprint (pma, Vikunja)

```
<Domain>                       root per domain (Product), no tasks of its own
  Backlog                      the domain Backlog = the STRATEGY backlog: requirements that serve a strategy
                               (a `Strategy <id>:` document) and have no tactic yet; buckets Idea, Refining, Ready
  <Tactic name>                one project per tactic, the wiki title without "Tactic <id>: ", no tasks
    Backlog                    that tactic's backlog; buckets Idea, Refining, Ready
    <YYMMDD-name>              one project per sprint of that tactic = the cycle doc title without "Cycle <id>: " (the plan has no pma project)
```

The tree is `<domain>/{Backlog, <tactic>/{Backlog, <YYMMDD-sprint>}}`. The level of the backlog is the level of the wiki document it serves: `<domain>/Backlog` serves the strategy, `<domain>/<tactic>/Backlog` serves that tactic. A requirement that serves a tactic belongs to exactly one tactic, so it is written into that tactic's
`Backlog` and later moved into one of that tactic's sprints. Create the tactic project (`pma project add "<Tactic name>" --parent Product`) and its
`Backlog` (`--parent <tactic id>`, pass the id because many projects are named `Backlog`) when the tactic's first requirement is written.
When a strategy requirement gets a tactic, move it (`pma edit <id> --project <tactic backlog id>`). A sprint serves one tactic; work for two tactics is two sprints.

Sprint board buckets: `To do`, `Specifying`, `Implementing`, `Review`, `Done` (Done completes the task). Sprint goal = the sprint
project description (goal + wiki cycle link). Archive the sprint project when it closes.

| Step | Wiki | pma | Role |
| --- | --- | --- | --- |
| Refine | | write requirement tasks into the tactic's `Backlog`: `Idea`, `Refining`, `Ready` (Ready = note complete) | pm (`Idea` to `Refining`), po (`Ready`) |
| Plan sprint | create `Cycle <id>: <name>` under the tactic's plan (create the plan first if none) with start/end, goal, scope | create the sprint project under the tactic, set goal, buckets; move `Ready` tasks in to `To do` | pm |
| Specify | | move to `Specifying`; the spec is written in the code repo by the spec-writing skill (see Spec below). **Never edit the task's note** | sr-se |
| Implement | | `Implementing`, `Review`; the agent implements against R1..Rn and the spec | sr-se, jr-se |
| Done | | move to `Done` (this completes it); the commit or PR goes in the spec file, not the note | qc |
| Close | write Outcome and Retro, `status: closed` | unfinished tasks back to the tactic's `Backlog` or its next sprint; archive the sprint project | pm |

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
