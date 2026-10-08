# Product roles (index)

Read by `/rox-workspace:bootstrap` to resolve names. Match id or alias, case-insensitive. `qa` and `qc` are never aliases of each other.
Gates (who may do what) are advisory; the gate tables are in `docs/specs/rox-workspace-roles-product.md` of the aos repo and summarised in each role file.

| id | Aliases | Role | Mission | Mode | Model | File |
| --- | --- | --- | --- | --- | --- | --- |
| `po` | product-owner | Product owner | Decide why and what: outcomes, priorities, acceptance | inline | inherit | `po.md` |
| `pm` | project-manager | Project manager | Keep the cadence: refinement flow, cycles, carry-over | inline | inherit | `pm.md` |
| `des` | designer, ui, ux, ui-ux | UI/UX designer | Decide how it looks and flows (UI and UX), before it is built | inline | inherit | `des.md` |
| `sr-se` | senior, senior-engineer | Senior software engineer | Decide how it is built: specs, technical decisions, review | inline | inherit | `se.md` (tier sr) |
| `jr-se` | junior, junior-engineer | Junior software engineer | Build one task against an approved spec | subagent | haiku | `se.md` (tier jr) |
| `entry-se` | entry | Entry-level software engineer | Same duties as jr-se; executed by Codex | codex | Codex | `se.md` (tier entry) |
| `sa` | sysadmin, system-admin | System administrator | Keep it running: deploy, cluster, secrets, runbooks | inline | inherit | `sa.md` |
| `qa` | quality-assurance | Quality assurance | Make it testable before it is built: criteria and test plan | inline | inherit | `qa.md` |
| `qc` | quality-control | Quality control | Prove it works after it is built: verify and move to Done | subagent | sonnet | `qc.md` |

## Gates in one table

| Gate | Owner |
| --- | --- |
| Ratify vision, strategy, tactic (`draft` to `active`) | po |
| Ratify cycle; close cycle or tactic; plan and close sprint | pm |
| `Idea` to `Refining`; sprint planning moves | pm |
| `Refining` to `Ready`; Backlog order | po |
| `To do` to `Specifying`; spec approval (warn if qa has not reviewed the test plan); technical decisions | sr-se |
| `Specifying` to `Implementing` to `Review` | sr-se, jr-se or entry-se (spec must be approved; for entry-se the relay makes the moves) |
| Test plan section of a spec | qa |
| `Review` to `Done` (or back to `Implementing`) | qc |
| Design decisions; clear `needs-design` | des |
| Infra, deploy, secrets, runbooks | sa |
| Decision docs | the deciding role (po product, sr-se technical, des design, sa infra) |

Read-only collection (search, read, probe, summarise) is delegated to `jr-se` (roxctl reads) and `entry-se` (code and docs, Codex read-only); see `collect.md`. Long commands whose output needs judging can be run by Codex from a command file (run mode, same file).

Separation of duties (warn once per task): the implementer is not its `qc`; the drafter of a vision, strategy or tactic is not its ratifier.
