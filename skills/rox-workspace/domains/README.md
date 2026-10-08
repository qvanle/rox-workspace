# Domains

One folder per domain: `STRUCTURE.md` (read first), `templates/`, `examples/`, `roles/` (see `roles/README.md`). Load only the domain you are working in.

| Domain | Wiki collection | pma root project | Status | Roles |
| --- | --- | --- | --- | --- |
| `product` | `RotexAI production` (the default collection of `roxctl workspace wiki`) | `Product` | ready: `product/` | ready: `product/roles/` |
| juridical | none yet (create `RotexAI juridical`) | `Juridical` | planned | planned |
| marketing | `RotexAI market` | `Marketing` | planned | planned |
| delivery | `RotexAI delivery` | `Delivery` | planned | planned |
| financial | `RotexAI financial` | `Financial` | planned | planned |
| brand | `RotexAI identity` | `Brand` | planned | planned |

`RotexAI legacy` is not a domain; do not write there. A planned domain has no folder yet: tell the user it is not defined and
stop, rather than reusing the `product` structure by guess.
