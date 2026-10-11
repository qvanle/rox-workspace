<!-- Title: "Strategy 2: Owner-readable execution", child of "Pillar 1: Radical Accessibility". ILLUSTRATIVE. -->
> level: strategy · status: active · owner: qvanle
> realizes: [Pillar 1: Radical Accessibility](url) · depends-on: none
> start: 2026-09-16 · end: 2027-03-16 · updated: 2026-10-08

:::info
**TL;DR** Transparency reaches a non-technical owner only if ==they can watch their own logic run==, not read about it afterwards.
:::

## 🧭 Context
The pillar says seeing logic must never require reading code. Today a run shows its final state, not what each step did.

## 🏛️ Conditions

| # | Condition | Why required | How we would know | Risk |
| --- | --- | --- | --- | --- |
| 1️⃣ | **Every step's input and output is visible** | An owner cannot trust what they cannot see | Any finished run can be opened step by step | Outputs are dropped by the engine |
| 2️⃣ | **A failure explains itself** | A silent failure destroys trust | The failed step is marked and shows its error | Errors swallowed by retries |

:::warning
**Weakest condition right now:** condition 1; the engine does not keep step outputs.
:::

---

## 📊 Metrics to track
- [ ] Share of runs an owner can open step by step (not yet measured).

## 🚫 Not doing
- Editing a workflow from the run view.

## ❓ Open questions
- How long should a run stay readable?

## 📚 References
Engine retention limits: see [Tactic 3: Execution Trace](url), section References.

## 📝 Review notes

| Date | Change | Why |
| --- | --- | --- |
| 2026-10-08 | Created | Example for the rox-workspace templates |
