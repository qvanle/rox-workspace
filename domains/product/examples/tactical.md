<!-- Title: "Tactic: Execution Trace". ILLUSTRATIVE, not a real plan. -->
> level: tactical · status: active · owner: qvanle
> realizes: [Pillar 1: Radical Accessibility](url) · depends-on: none
> start: 2026-10-12 · end: 2026-12-18 · updated: 2026-10-08

:::info
**Goal** By 18 December an owner can open any finished workflow run and ==read what each step received and returned==.
:::

## ⏱️ Why now
Pillar 1 says transparency is a read experience: the owner watches logic run. Today a run shows its final state but not each
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
| 🔐 Traces hold sensitive data | Personal data appears in a trace | Redact by field type; record the decision in `Decisions` |
| 💾 Storage grows with runs | Trace storage passes its monthly budget | Expire traces after a set number of days |

:::tip
**Decision needed:** where traces are stored and for how long, before the first cycle ends.
:::

## 🚫 Not doing
- Editing a workflow from the trace view.

## 📝 Review notes

| Date | Change | Why |
| --- | --- | --- |
| 2026-10-08 | Created | Example for the rox-workspace templates |
