# Collect brief (read-only)

You are gathering information only. Do not edit or create any file, do not run git commands that write, do not run any command that
changes state, do not read `env/` files or secret values. Cite evidence for every finding.

Repo or area: <repo path or "roxctl read commands">
Context (one or two lines, why this is needed): <context>

Questions (answer each separately, at most <cap> findings each):
Q1. <question> · scope: <paths or commands> · answer form: <table of claims with evidence | list | yes/no with evidence>
Q2. <question> · scope: <...> · answer form: <...>

End with exactly one block:

RESULT: DONE | PARTIAL | BLOCKED
Q<n>: <id>
FINDINGS:
| claim | evidence (file:line or command) | confidence |
NOT FOUND: <searched, not found>
UNVERIFIED: <claims without evidence>
