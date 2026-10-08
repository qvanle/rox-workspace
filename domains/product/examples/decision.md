<!-- Title: "Decisions/261014-store-traces-in-postgres". ILLUSTRATIVE, not a real decision. -->
> level: decision · status: active · owner: qvanle
> realizes: none · depends-on: none · concerns: [Tactic: Execution Trace](url)
> start: 2026-10-14 · end: none · updated: 2026-10-14

:::success
**Decision** ==We will store workflow step traces in the platform's Postgres, in a `step_trace` table, and expire them after 90 days.==
:::

## 🧭 Context
The trace viewer needs each step's input and output after the run ends. The workflow engine's own history drops outputs after
its retention period and is not designed to be read by customers. Traces can hold business data, so storage must be
tenant-isolated like the rest of the data.

## ⚖️ Options considered

| Option | 👍 For | 👎 Against |
| --- | --- | --- |
| ✅ Postgres table, 90-day expiry | Same isolation and backup as existing data; no new service | Table growth needs a cleanup job |
| ❌ Engine history | Nothing to build | Outputs expire early; shape not customer-facing |
| ❌ Object storage per run | Cheap for large payloads | New read path; harder to query a single step |

## 🔮 Consequences
Easier: one query serves the viewer. Harder: a cleanup job and a size cap per payload.

:::warning
**Reopen if:** trace storage passes its monthly budget, or owners ask for traces older than 90 days.
:::
