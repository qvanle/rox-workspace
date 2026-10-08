<!-- Repo file docs/specs/261012-trace-viewer.md. ILLUSTRATIVE, not a real design. -->
# Trace viewer: per-step input and output

Requirement: Product #42 · Cycle: 261012-trace-viewer
Status: approved 2026-10-12 (qvanle, sr-se)

## Requirement
Task #42 "Owners can see each step input and output": R1 (a run lists its steps in order with status), R2 (selecting a step
shows its input and output), R3 (payloads over 64 KB are truncated with a notice).

## Approach
The worker already reports each step's result to the engine. It will also write one trace row per step (run id, step name,
status, started, finished, input, output) to a `step_trace` table, in the same transaction as the result. The portal reads
the rows through the existing gateway route for the run. Rejected: reading the engine's own history, because it drops
outputs after a retention period; a separate trace service, because it adds a deployment for one table.

## Interfaces
- Table `step_trace(run_id, seq, step, status, started_at, finished_at, input jsonb, output jsonb, truncated bool)`.
- `GET /v1/runs/{id}/trace` returns the rows ordered by `seq`; payloads over 64 KB are cut and `truncated` is true.

## Test plan

| Requirement | Test | Level |
| --- | --- | --- |
| R1 | A 3-step run returns 3 rows in order with statuses | integration |
| R2 | Input and output of step 2 equal what the worker received and returned | integration |
| R3 | A 100 KB output is cut to 64 KB and flagged | unit |

## Open questions
- Should traces be redacted by field type? See `Decisions/261014-store-traces-in-postgres`.
