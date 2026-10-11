<!-- Title: "Tactic 3: Execution Trace", path "Pillar 1: Radical Accessibility/Strategy 2: Owner-readable execution/Tactic 3: Execution Trace". ILLUSTRATIVE, not a real plan. -->
> level: tactical · status: active · owner: qvanle
> realizes: [Strategy 2: Owner-readable execution](url) · depends-on: none
> start: 2026-10-12 · end: 2026-12-18 · updated: 2026-10-08

:::info
**Goal** By 18 December an owner can open any finished workflow run and ==read what each step received and returned==.
:::

## ⏱️ Why now
Strategy 2 says transparency is a read experience: the owner watches logic run. Today a run shows its final state but not each
step's input and output, which is the vision's differentiator. This initiative closes that gap first.

## 🎯 Outcomes

| # | Outcome | Measure | Owner |
| --- | --- | --- | --- |
| O1 | Every run keeps per-step input, output, timing and status | 100% of new runs have a trace | qvanle |
| O2 | An owner can read a trace without help | 3 of 3 test users find a failed step in under a minute | qvanle |

## 🗺️ Approach and order
1. 🧱 Capture the per-step data in the worker and store it (unlocks everything else).
2. 👀 A read-only trace view in the portal, linked from the run list.
3. 🗣️ Plain-language step labels, so the view needs no knowledge of the engine.

---

## ⚠️ Risks

| Risk | Signal | Response |
| --- | --- | --- |
| 🔐 Traces hold sensitive data | Personal data appears in a trace | Redact by field type; see the decision below |
| 💾 Storage grows with runs | Trace storage passes its monthly budget | Expire traces after a set number of days |

:::tip
**Decision needed:** where traces are stored and for how long, before the first cycle ends.
:::

## 🚫 Not doing
- Editing a workflow from the trace view.

## 🧭 Decisions

### 261014 Store traces in Postgres · status: active
:::success
**Decision** ==We will store workflow step traces in the platform's Postgres, in a `step_trace` table, and expire them after 90 days.==
:::

- **Context:** the viewer needs each step's input and output after the run ends; the engine's own history drops outputs early and is not customer-facing; traces can hold business data, so storage must be tenant-isolated.
- **Options:** ✅ Postgres table, 90-day expiry (same isolation and backup, no new service / needs a cleanup job) · ❌ engine history (nothing to build / outputs expire early) · ❌ object storage per run (cheap for large payloads / harder to query one step).
- **Consequences:** one query serves the viewer; a cleanup job and a size cap per payload are needed.
- **Reopen if:** trace storage passes its monthly budget, or owners ask for traces older than 90 days.

## 📚 References

| Item | Value |
| --- | --- |
| Trace table | `step_trace` (run id, step id, input, output, status) |
| Retention | 90 days |

## 📝 Review notes

| Date | Change | Why |
| --- | --- | --- |
| 2026-10-08 | Created | Example for the rox-workspace templates |
