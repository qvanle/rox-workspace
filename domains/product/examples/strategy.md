<!-- Title: "Production Strategy". Restates the existing wiki doc (four pillars), shortened. -->
> level: strategy · status: active · owner: qvanle
> realizes: [Product Vision: Beyond the Black-Box Backend](url) · depends-on: none
> start: 2026-09-16 · end: 2027-03-16 · updated: 2026-10-08

:::info
**TL;DR** Backend transparency only becomes a sellable product if ==four conditions hold at the same time==; drop any one and the wedge collapses.
:::

## 🧭 Context
The vision claims backend transparency beats Lovable, Base44 and v0. Each condition has its own `Pillar n:` document.

## 🏛️ Conditions

| # | Condition | Why required | How we would know | Risk |
| --- | --- | --- | --- | --- |
| 1️⃣ | **Radical accessibility** | Transparency must reach a non-technical owner | Changes made with no developer or agency | Seeing logic ever requires reading code |
| 2️⃣ | **Cost leadership under profitability** | An unaffordable product never reaches its customer | Lowest viable price, margin never negative | Per-tenant work grows with tenant count |
| 3️⃣ | **High fault tolerance** | A transparent workflow that fails silently destroys trust | Failures are visible and recoverable | Hidden retries or swallowed errors |
| 4️⃣ | **Development and agent workflow governance** | None of the above survives release after release without it | Every change auditable, people and AI agents alike | Ad-hoc changes outside the process |

:::warning
**Weakest condition right now:** the metrics for conditions 1 and 3 are not yet measured.
:::

---

## 📊 Metrics to track
- [ ] Share of logic and schema changes with zero developer involvement (not yet measured).
- [ ] Time from "I want to change X" to live (not yet measured).
- [ ] Conversation turns for a routine change (not yet measured).

## 🚫 Not doing
- Out-designing competitors' frontends; the frontend stays conventional on purpose.

## ❓ Open questions
- Where is the line between conversational simplicity and over-simplifying real business nuance?

## 📝 Review notes

| Date | Change | Why |
| --- | --- | --- |
| 2026-10-08 | Header added; layout refreshed | Alignment with the rox-workspace structure |
