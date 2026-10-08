---
name: commit
description: Commit and push in the RotexAI aos workspace root or its nested manifest, IaC and codebase repos. Applies to aos work only; follows repo message style, secret and review gates, gitlink pointers and main-only pushes to every remote.
---

# commit

Use only in the aos workspace root and its nested `manifest`, `IaC`, `codebase/*` repositories.
Confirm the workspace from its `CLAUDE.md` and gitlinks; stop for unrelated repositories.
Scripts below are relative to this skill's base directory. They never stage or commit for you.

## 1. Locate and roles

Read the active set from the session's last bootstrap, never infer a role from the user's name.
If active, read `../rox-workspace/domains/product/roles/_common.md`, the role index and active role files.
Apply the union rule; `sr-se` supersedes `jr-se` and `entry-se`. With no active role, no role warning applies.

| Active role | Commit and push |
| --- | --- |
| sr-se | In its engineering area |
| sa | In `IaC/` and `manifest/`; warn and ask outside that area |
| jr-se, entry-se | Decline: "that is sr-se's call"; return the staged diff summary, never commit or push |
| po, pm, des, qa, qc | Own docs/specs allowed; otherwise warn and ask per `_common.md` |

Run `bash <skill base dir>/scripts/commit-preflight.sh --repo PATH`; show repo, branch, remote names and ahead/behind.
On any FAIL stop the commit, report the fix and ask how to resolve it. On non-main, explain main-only pushes;
offer to keep the work local. Never switch branches, pull or rebase silently.

## 2. Status

Inspect staged, unstaged and untracked paths. Stop when there is nothing to commit.
Agree on one logical change, stage only its named paths with `git add -- <paths>`; never `git add -A`.

## 3. Secret gate

Rerun preflight after staging. It scans staged additions and untracked files for plaintext `kind: Secret`
(not `SealedSecret`), env files, private keys, tokens and `password=`; it names only file and rule.
In `manifest`, it checks Husky hooks and runs `npm run check:unsealed-secrets` without printing its output.
Never echo secret values, raw secret diffs, or credential-bearing remote URLs. A FAIL blocks committing.

## 4. Codex review and message

Review is skipped only for docs-only changes or fewer than 10 added + deleted lines; state `skipped: <reason>`.
The message is always drafted by Codex, so Claude spends tokens checking it, not composing it. One read-only call
(`codex:codex-rescue`, no `--write`, launched from the repo root) with the brief in `references/codex-message-prompt.md`:
the staged diff (it already passed the secret gate), `STYLE`, the last eight subjects, the spec path or task id.
It returns `SUBJECT`, `BODY`, `FINDINGS` and never runs git or writes trailers. Apply or report the findings;
if `FINDINGS` says the diff mixes two changes, split it. If Codex errors (auth, quota), say so and write the message yourself.

## 5. Check and commit

Check the draft: matches `STYLE` (`type(scope): subject`, or the repo's plain form; never CI's `chore(<svc>): promote`);
subject imperative, at most 72 characters, no trailing period; body gives the why with a spec path or task id
(`Requirement: Product #42`), never pasted requirements; no secrets or private-node hostnames; describes only the staged diff.
Fix small problems; if it misdescribes the diff, re-ask Codex once with the correction, then write it yourself.
Append exactly the attribution trailer lines in this session's reminder, unchanged; none when it gives none.
Use `git commit` with hooks enabled; never bypass hooks or rewrite history.

## 6. Record

If the task has a spec whose first line starts `Requirement:`, append the new commit hash under
its `Implementation` heading (create the heading if absent). Never edit the pma task note.
This post-commit spec edit remains a working-tree change; do not silently amend to include its own hash.

## 7. Pointer

After every nested repo commit, always offer a separate root commit; never do it automatically.
Stage only that gitlink: `git add -- <nested-path>`. Message: `Update <repo> pointer`, optionally
with a meaningful clause. Run root preflight and the same gates; the root pointer stays local when no remote exists.

## 8. Push

Show commits and all remote names in a table; state the effect and ask for a yes before pushing.
On yes run `bash <skill base dir>/scripts/push-all.sh --repo PATH` (`--dry-run` previews without writing).
Tracked remote first, other remotes next, `internal` last unless it is the tracked remote; report each result.
Only `main:main`, fast-forward only. Never force, tags, mirror, other refs, PRs, merges or deploys.
On partial failure report which remote remains behind; stop and ask, never silently retry. Use `ship` to follow CI.
