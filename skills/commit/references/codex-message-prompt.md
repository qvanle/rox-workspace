# Codex commit-message brief

Paste this into the Codex call, filling the placeholders. Run it read-only (no `--write`) from the repository root.

```text
You draft one git commit message and review the staged change. Do not run git, do not edit files, do not print secrets.

Repo style: <conventional|plain>. Last 8 subjects:
<subjects>
Spec or task: <path or "Product #42" or none>

Staged diff:
<git diff --cached output>

Rules:
- conventional repos: type(scope): subject, scope = the service or area; plain repos: match the last subjects.
- Subject: imperative, at most 72 characters, no trailing period. Never imitate CI messages (chore(<svc>): promote ...).
- Body: why, not what. If a spec or task is given, add "Requirement: <ref>". Never paste requirement text.
- No secrets, tokens, or private node hostnames. Do not add attribution or Co-Authored-By lines.
- If the diff holds two unrelated changes, say so in FINDINGS and propose the split; do not write one muddled message.
- Review the diff for correctness bugs, leaked secrets, and missing tests; list them in FINDINGS (or "skipped: <reason>" / "none").

Answer with exactly:
SUBJECT: <one line>
BODY:
<lines>
FINDINGS:
<lines>
```
