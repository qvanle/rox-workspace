# Wiki (Outline) through `roxctl workspace wiki`

Read before any wiki write. Bodies are Markdown; callouts are `:::info`, `:::warning`, `:::success`, `:::tip` blocks.

## Make it readable

Documents are read by people at a glance, so use Outline's full Markdown and fill the domain template as given: emoji in headings,
`---` between parts, tables, callouts (`:::info`, `:::warning`, `:::success`, `:::tip` on its own line, the text, then `:::` alone on the closing line), `==highlight==` on the one phrase that matters, `- [ ]` checklists, 👍/🔧/🗑️ style markers in
tables. One callout per idea; never wrap a whole section. Do not flatten a template into plain paragraphs.

## Collections

One collection per domain (`domains/README.md` maps them). With no flag the default is `RotexAI production`. Select another
with `--collection "<name or id>"` (before or after the action). An unknown or ambiguous name is an error, never a fallback.

```
roxctl workspace wiki collection list
roxctl workspace wiki collection create "RotexAI juridical" --description "Legal"   # one-time, per new domain
```

## Read

```
roxctl workspace wiki search "<words>" --limit 5       # titles and ids; add --collection for another domain
roxctl workspace wiki list --limit 20                  # never dump a whole collection into context
roxctl workspace wiki get <id|url|title> --raw         # the Markdown body
```

Search first, then `get` the one hit. Report the title and the link; do not paste whole documents back.

## Create

```
P="Pillar 1: Radical Accessibility/Strategy 2: Owner-readable execution/Tactic 3: Execution Trace/Plan 2: Trace viewer v1/Cycle 7: 261012-trace-viewer"
bash <skill base dir>/scripts/wiki-guard.sh check "$P"     # must print OK; REFUSED = do not create
roxctl workspace wiki create "$P" --file /path/doc.md --start 2026-10-12 --end 2026-10-16
```

- The path is `/`-separated titles, the whole chain `Pillar -> Strategy -> Tactic -> Plan -> Cycle` down to the new document, each
  title with its prefix and id (`domains/product/STRUCTURE.md`). roxctl would create missing ancestors as stubs and accept any title,
  so `scripts/wiki-guard.sh check` is mandatory first; it refuses a missing prefix, a skipped level, a missing ancestor, a reused id
  and an existing leaf. The first segment is matched by title anywhere in the collection, later ones under the parent just found.
  A title that matches two documents is an error. `wiki-guard.sh next <level>` gives the next free id.
- It **fails if the leaf already exists**: that is your duplicate guard, never work around it with a variant title.
- `--text` or `--file` set the body. `--start` and `--end` are taken by roxctl (not passed to `ol`) and written into the
  metadata block together with `updated`. Everything is published at once.
- Write the file with the header block first (`references/header.md`); roxctl fills the dates.

## Update

```
roxctl workspace wiki get <id> --raw          # read first: update replaces the body
roxctl workspace wiki update <id> --file /path/doc.md [--end 2026-11-01]
roxctl workspace wiki update <id> --title "New title"
```

Every update sets `updated`. With no body given, roxctl reads the current text, rewrites the block and writes it back, so
`--end D` alone extends a document's period. It is not atomic: a concurrent edit in between is lost.

## Move, archive, delete

```
roxctl workspace wiki move <id> --parent <parent-id>
roxctl workspace wiki archive <id>            # prefer this; unarchive undoes it
roxctl workspace wiki delete <id> --confirm   # permanent; only after the user names the document
```

## Stale check

```
roxctl workspace wiki stale                   # every collection
roxctl workspace wiki stale --collection "RotexAI production" --level cycle
roxctl workspace wiki stale --all             # also lists documents with no metadata block
roxctl workspace wiki stale --today 2026-12-01   # what will be stale on that day
```

Stale = status `active` and (`end` passed, or `updated` older than the limit for its level). It reports and exits 0.
Documents with no block are counted, not listed; they gain a block the next time they are updated.

## Gotchas

- roxctl's own flags (`--json`, `--sudo`) go before the tool: `roxctl --json workspace wiki stale`, not after the action.
- Do not pass `--title`, `--parent` to `create`; the path decides them.
- `update --title` and `move --parent` are guarded by the same rules: the title keeps its `Level <id>:` prefix and the new parent is the level above (the guard cannot check a move: read the new parent's `level:` header yourself and refuse a parent that is not exactly one level up).
- A decision or a reference is never created as a document: it is an edit (`get --raw`, add the entry, `update`) to its tactic or using document.
- Do not re-`get` a document after writing it. A write that exits 0 is done.
- Legacy documents (no header, free-form titles, `Decisions`/`Cycles` indexes) are not created again and are migrated only on request; leave their titles alone otherwise.
