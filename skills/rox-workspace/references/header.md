# Metadata block (header of every wiki document)

The first lines of a document, as quote lines. `wiki stale` reads them; roxctl writes the dates.

```
> level: cycle · status: active · owner: qvanle
> realizes: [Tactic: Execution Trace](url) · depends-on: none
> start: 2026-10-12 · end: 2026-10-16 · updated: 2026-10-08
```

- Each line is `key: value` pairs joined by ` · ` (space, middle dot, space). Keys are only: `level`, `status`, `owner`,
  `realizes`, `depends-on`, `concerns`, `start`, `end`, `updated`. A quote line with any other key is just a quote.
- **You write**: `level`, `status`, `owner`, `realizes`, `depends-on`, `concerns`. **roxctl writes**: `updated` always, and
  `start` / `end` from `--start` / `--end`. Leave those three out of your file, or put any value there; roxctl overwrites it.
- `level`: `vision`, `strategy`, `tactical`, `cycle`, `decision`, `reference`.
- `status`: `draft`, `active`, `closed`, `superseded`. Only `active` documents can be stale. Set a replaced document
  `superseded` and a finished cycle or tactic `closed`.
- `realizes`: a link to the parent document (cycle -> tactic -> strategy -> vision); `none` for a vision, decision or reference.
- Dates are `YYYY-MM-DD`, local day. `end` is the end of the period the document governs; for a vision or strategy it is the next review.
- A document with no block still works. roxctl adds a block holding only `updated` on the next update; add the rest by hand.
