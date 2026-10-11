<!-- Title: "Plan 2: Trace viewer v1", child of "Tactic 3: Execution Trace". ILLUSTRATIVE. -->
> level: plan · status: active · owner: qvanle
> realizes: [Tactic 3: Execution Trace](url) · depends-on: none
> start: 2026-10-12 · end: 2026-11-13 · updated: 2026-10-08

:::info
**Goal** By 13 November an owner can open any finished run and ==read each step's input, output and error==.
:::

## 🗺️ Sequence

| # | Cycle | Dates | Goal | Status |
| --- | --- | --- | --- | --- |
| 1 | [Cycle 7: 261012-trace-viewer](url) | 12 to 16 Oct | Step input and output visible | active |
| 2 | (not created yet) | 19 to 23 Oct | Failed step marked, error shown | planned |
| 3 | (not created yet) | 26 to 30 Oct | Viewer loads in under 2 seconds | planned |

## ✅ Exit test
- [ ] Outcomes O1 and O2 of the tactic are met on a real finished run.

## ⚠️ Risks

| Risk | Signal | Response |
| --- | --- | --- |
| 💾 Traces slow the run | Run time grows after capture is on | Capture asynchronously |

## 📚 References
The storage decision is in [Tactic 3: Execution Trace](url), section Decisions.

## 📝 Review notes

| Date | Change | Why |
| --- | --- | --- |
| 2026-10-08 | Created | Example for the rox-workspace templates |
