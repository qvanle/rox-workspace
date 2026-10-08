# rox-workspace

A Claude Code plugin for working in the RotexAI workspace through `roxctl`: the Outline wiki and the Vikunja task manager (pma),
plus team **roles**, and skills for committing, shipping, sealing secrets, scaffolding services, documenting, diagnosing and verifying.

It is written for one operator's workspace (the `aos` umbrella repo). Nothing here is generic; the rules in it come from that workspace's history.

## Install

```text
/plugin marketplace add ~/projects/personal/rox-workspace
/plugin install rox-workspace@rox-workspace
```

Requirements: `roxctl` on PATH (built from `aos/codebase/control-plane/roxctl`), `jq`, Python 3 with PyYAML (used by `ship`, `docs`,
`new-service`), and for the wiki and pma `ol` and `vja`, both already logged in. `entry-se` also needs the Codex plugin
(`openai-codex`). `bash skills/rox-workspace/scripts/preflight.sh all` checks `roxctl`, the wiki and pma tools and `jq`; Python, PyYAML and the Codex plugin are not checked yet.

Remove any old copy at `~/.claude/skills/rox-workspace` after installing; two copies would both trigger.

## What is in it

| Skill | Use it to |
| --- | --- |
| `rox-workspace` | Read, search, write and move wiki documents; create and plan pma tasks and sprints; run the daily stale check. Always through `roxctl workspace`, never a browser |
| `commit` | Commit and push in the aos workspace: repo style, secret gate, Codex review and message, root pointer commit, `main`-only pushes to every remote |
| `ship` | Follow a push through CI, the registry, the manifest bump and Argo CD to a healthy deployment, naming the known cause at each failing step |
| `seal-secret` | Turn a per-service env file into a `SealedSecret` in the right overlay, showing key names only |
| `new-service` | Scaffold a service in `manifest/` with sync-waves derived for that service, never copied |
| `docs` | Write, update, verify and explain in-repo docs; checks claims against the manifest and the list of removed things |
| `diagnose` | Investigate a cluster fault through `roxctl` probes and tracked playbooks, starting from known symptoms |
| `test-plan`, `verify` | QA writes the test plan before the build; QC proves each requirement with evidence and moves the task to Done |

Each skill is a short `SKILL.md`. Where a step is deterministic (counting, checking, polling) a script does it, so the model's tokens go to judgment: `commit`, `ship`, `seal-secret`, `new-service` and `docs` have scripts, and the role bootstrap and `entry-se` have `brief.sh` and `entry-se-run.sh`. `diagnose`, `test-plan` and `verify` are instructions only.

## Roles

`/rox-workspace:bootstrap [role...] [--domain product]` loads one or more roles, runs the preflight, prints the role's starting view and a role card.

Other commands: `build <task-id>` (pick executor, dispatch, move to Review), `verify <task-id>` (independent qc, Done or back), `collect "<q>"` (read-only fan-out), `run <file>` (Codex runs a command file), `status`, `role [role...]`, `interview [topic]` (draft requirement).
With no argument it asks. Roles are advisory: an action another role owns makes the agent warn and ask; nothing is blocked.

| Role | Mission | Executes |
| --- | --- | --- |
| `po` | Why and what: outcomes, priorities, acceptance | inline |
| `pm` | Cadence: refinement, cycles, carry-over | inline |
| `des` | How it looks and flows, before it is built | inline |
| `sr-se` | How it is built: specs, technical decisions, review | inline |
| `jr-se` | Build one task against an approved spec | Haiku subagent |
| `entry-se` | The same duties as `jr-se` | Codex job, on OpenAI credit |
| `sa` | Deploy, cluster, secrets, runbooks | inline |
| `qa` | Make it testable before the build: criteria and test plan | inline |
| `qc` | Prove it works after the build: verify, move to Done | Sonnet subagent with a fresh context (inline on request) |

**Collect work.** Read-only gathering (search, read, list, probe, summarise, check claims) is broken down and delegated to `jr-se` (for `roxctl` reads)
and `entry-se` (for files and code, Codex read-only). See `skills/rox-workspace/domains/product/roles/collect.md`.

**Choosing who builds.** `sr-se` picks `exec:sr`, `exec:jr` or `exec:entry` for a ready task: unclear, risky or infra work stays with `sr-se` (or `sa`),
tool-heavy small tasks go to `jr-se`, precise self-contained code changes go to `entry-se`. The table is in the product domain spec.

## Codex model and effort

`entry-se-run.sh` passes `--model` and `--effort` to every Codex job. Only two models are used: `gpt-6-luna` and `gpt-6.1-sol`. Effort is `medium` by default
(overriding the `xhigh` in `~/.codex/config.toml`), `low` for simple work, `high` or `xhigh` for complex work. `--tier` is a shortcut:

| `--tier` | Model | Effort | Use for |
| --- | --- | --- | --- |
| `light` | `gpt-6-luna` | `low` | Simple reads, short command runs, commit messages |
| `standard` (default) | `gpt-6-luna` | `medium` | Builds from a clear spec |
| `complex` | `gpt-6.1-sol` | `high` | Reviews of large diffs, tricky logic; ask for `--effort xhigh` explicitly for the hardest |

Defaults can be set with `ENTRY_SE_MODEL` and `ENTRY_SE_EFFORT`; any other model or effort is refused before launch.

## Safety rules the plugin carries

- Cluster access only through `roxctl` and tracked Ansible playbooks, never ad-hoc `ssh`.
- Secrets are `SealedSecret` only; no skill prints a secret value.
- Push `main` only, to every remote, fast-forward only. A `PreToolUse` hook (`hooks/hooks.json`) blocks pushes of other refs, force pushes, `--tags` and
  `--mirror`, **inside the aos workspace only**; other repositories are left alone.
- A task note is never edited after it is created; progress is the bucket, project, done state and labels.
- `jr-se` and `entry-se` never commit, push, ship, seal or scaffold, and stop with a question rather than guess.

## Layout

```text
.claude-plugin/        plugin.json, marketplace.json
commands/bootstrap.md  /rox-workspace:bootstrap
commands/{build,verify,collect,run,status,role,interview}.md  /rox-workspace:<name>
agents/jr-se.md        the Haiku subagent; agents/qc.md the verification subagent
hooks/hooks.json       the push guard
skills/<name>/         SKILL.md, scripts/, references/, templates/, evals/, tests/
skills/rox-workspace/domains/product/   structure, templates, examples and the nine role files
```

## Tests

Every skill with a script has a test runner that uses fake binaries and temporary repositories only; none touches a live cluster, a real remote or a real Codex job.

```bash
for t in skills/*/tests/run-tests.sh skills/rox-workspace/tests/entry-se-run-tests.sh; do bash "$t" | tail -1; done
claude plugin validate .
```

`evals/evals.json` in each skill lists the behaviour cases to grade a model against; they have not been model-graded yet.

## Status and known limits

First version, 0.2.0. Scripts and tests pass against fakes; the live paths are not yet exercised end to end. Open items: whether the Codex sandbox can run
language test suites (otherwise the relay's script runs them), the exact `roxctl platform` flags used by `ship` (confirmed from help at run time; some leaf
`--help` calls execute, so the scripts probe category help first), and creating the `exec:` labels in Vikunja when the first sprint starts.

The design specs live in the `aos` repository under `docs/specs/` (`rox-workspace-*.md`).
