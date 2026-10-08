# Removed names

Owned by docs; add a row for every removal. Dates marked “not recorded” must not be invented.
The checker reads this table. Warnings also apply to historical mentions; the author decides whether the context resolves them.

| Word | Removed when | Replaced by |
| --- | --- | --- |
| Gitea as an AI-agent feature | 2026-08-25 | rox-git (different purpose, not a restore) |
| cms | not recorded | git + CDN + SQLite-WASM for the blog; contact form remains dangling |
| deeptutor | not recorded | none recorded |
| agent-automation Postgres | 2026-09-09 | none recorded |
| jwt-validator | 2026-09-04 | iap |
| AFFiNE | mid-September 2026 | Outline |
| iap-internal | 2026-10-09 | Zot authenticates users with Keycloak OIDC |
| web-registry | 2026-10-09 | Zot UI and Keycloak OIDC |

Evidence: `aos/docs/18-history-and-decisions.md` (removals and renames) and `aos/docs/11-web-other-sites.md` (registry retirement). Active CI Gitea and rox-git are not removed; only the old AI-agent feature gets the Gitea warning.
