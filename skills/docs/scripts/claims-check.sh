#!/usr/bin/env bash
# Local, deterministic doc checks; no model or cluster commands.
# Usage: claims-check.sh <file.md> [--manifest PATH]
# Overrides: AOS_ROOT (repo paths), PYTHON_BIN (Python 3, including test doubles).
# Exit 0: OK/WARN only; 1: FAIL; 2: usage. Never prints document/manifest contents.

usage() { echo 'usage: claims-check.sh <file.md> [--manifest PATH]' >&2; exit 2; }
[ $# -eq 1 ] || [ $# -eq 3 ] || usage
case "$1" in -*) usage ;; esac
manifest=""
if [ $# -eq 3 ]; then
  [ "$2" = --manifest ] && [ -n "$3" ] || usage
  manifest="$3"
fi
[ -f "$1" ] && [ -r "$1" ] || { echo 'FAIL document: missing or unreadable -- supply a readable Markdown file'; exit 1; }
python_bin="${PYTHON_BIN:-python3}"
command -v "$python_bin" >/dev/null 2>&1 || { echo 'FAIL python3: missing -- install Python 3 or set PYTHON_BIN'; exit 1; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
"$python_bin" - "$1" "$manifest" "$script_dir/../references/removed-things.md" <<'PY'
import os
import re
import sys
from pathlib import Path


def fail(what, fix):
    print(f"FAIL {what} -- {fix}")


def main():
    doc = Path(sys.argv[1]).resolve()
    override = os.environ.get("AOS_ROOT")
    if sys.argv[2]:
        manifest = Path(sys.argv[2]).resolve()
    elif override:
        manifest = Path(override).resolve() / "manifest"
    else:
        candidates = list(doc.parents) + [Path.cwd(), *Path.cwd().parents]
        manifest = next((p / "manifest" for p in candidates
                         if (p / "manifest/services").is_dir()
                         and (p / "manifest/clusters/rum").is_dir()), None)
        if manifest is None:
            fail("manifest: not found", "run from aos, set AOS_ROOT or pass --manifest PATH")
            return 1
    root = Path(override).resolve() if override else manifest.parent
    if not all((manifest / p).is_dir() for p in ("services", "clusters/rum")):
        fail("manifest: incomplete tree", "supply a manifest with services/ and clusters/rum/")
        return 1
    if not root.is_dir():
        fail("AOS_ROOT: missing", "set AOS_ROOT to the repository root")
        return 1

    content = doc.read_text(encoding="utf-8")
    removed = []
    for line in Path(sys.argv[3]).read_text(encoding="utf-8").splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if line.startswith("| ") and len(cells) == 3 and cells[0] not in ("Word", "---"):
            removed.append(cells)

    services = set()
    for tree in (manifest / "services", manifest / "clusters/rum"):
        services.update(p.name for p in tree.rglob("*") if p.is_dir() and ".git" not in p.parts)
    # Source-only components are useful candidates but do not prove deployment.
    source_names = set()
    codebase = root / "codebase"
    if codebase.is_dir():
        for category in codebase.iterdir():
            if category.is_dir() and not category.name.startswith("."):
                source_names.update(p.name for p in category.iterdir() if p.is_dir())
    retired_names = {row[0].lower() for row in removed if " " not in row[0]}
    mentioned = set(re.findall(r"(?<!`)`([a-z][a-z0-9-]*)`(?!`)", content))
    candidates = set()
    for name in mentioned:
        if name in services | source_names | retired_names or "-" in name:
            candidates.add(name)
        elif re.search(r"\b(?:service|component)\s+`" + re.escape(name) + r"`", content, re.I):
            candidates.add(name)
    for name in sorted(candidates):
        print(f"OK {name}: deployed in manifest" if name in services else f"WARN {name}: not deployed")

    # Repo-root paths in prose, inline code and Markdown links; trim line anchors.
    paths = set(re.findall(r"(?<![\w/])(?:manifest|IaC|codebase|docs)/[A-Za-z0-9_./*?@+-]+", content))
    path_claims = {(p.rstrip(".,:;"), "repo") for p in paths}
    for target in re.findall(r"\]\(<?([^\s)>]+)>?(?:\s+[^)]*)?\)", content):
        target = target.split("#", 1)[0]
        if target and not re.match(r"[a-zA-Z][\w+.-]*:", target) and not target.startswith("/"):
            if not any(target.startswith(prefix + "/") for prefix in ("manifest", "IaC", "codebase", "docs")):
                path_claims.add((target, "doc"))
    rc = 0
    for claim, location in sorted(path_claims):
        base = root if location == "repo" else doc.parent
        if claim.startswith("manifest/"):
            actual = manifest / claim[len("manifest/"):]
        else:
            actual = base / claim
        if "*" in claim or "?" in claim:
            # A glob describes a family: one match establishes existence only.
            import glob
            exists = bool(glob.glob(str(actual)))
        else:
            exists = actual.exists()
        if exists:
            print(f"OK {claim}: exists")
        else:
            fail(f"{claim}: missing", "correct the path or remove the claim")
            rc = 1

    host_pattern = r"(?<![\w.-])(?:\*|[a-z0-9-]+)(?:\.[a-z0-9-]+)*\.rotexai\.com(?![\w.-])"
    hosts = set(re.findall(host_pattern, content, re.I))
    routed_hosts = set()
    for path in sorted(manifest.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in (".yaml", ".yml") or ".git" in path.parts:
            continue
        # Read YAML text locally; never emit any resource body (especially Secrets).
        for resource in re.split(r"(?m)^---\s*$", path.read_text(encoding="utf-8")):
            resource = re.sub(r"(?m)^\s*#.*$", "", resource)
            kind = re.search(r"(?m)^kind:\s*([\w]+)\s*(?:#.*)?$", resource)
            if not kind or kind[1] not in ("Ingress", "IngressRoute", "IngressRouteTCP", "Certificate", "HTTPRoute", "Gateway"):
                continue
            fields = []
            if kind[1] in ("IngressRoute", "IngressRouteTCP"):
                fields += re.findall(r"\bHost(?:SNI)?\(([^)]*)\)", resource)
            if kind[1] == "Ingress":
                fields += re.findall(r"(?m)^\s*(?:-\s*)?host:\s*([^\n#]+)", resource)
            # Host list fields: certificate DNS, Ingress TLS, Gateway/HTTPRoute names.
            fields += [m[0] for m in re.finditer(r"(?m)^[ \t]*(?:-\s*)?(?:dnsNames|hosts|hostnames):[^\n]*(?:\n[ \t]+-\s+[^\n]*)*", resource)]
            if kind[1] == "Gateway":
                fields += re.findall(r"(?m)^\s*hostname:\s*([^\n#]+)", resource)
            for field in fields:
                routed_hosts.update(h.lower() for h in re.findall(host_pattern, field.split("#", 1)[0], re.I))
    for host in sorted(hosts):
        lower = host.lower()
        wildcard = "*." + lower.split(".", 1)[1]
        routed = lower in routed_hosts or (not lower.startswith("*.") and wildcard in routed_hosts)
        print(f"OK {host}: route or certificate" if routed else f"WARN {host}: no route")

    for word, when, replacement in removed:
        if word == "Gitea as an AI-agent feature":
            found = re.search(r"\bgitea\b[^\n]{0,100}\bAI[- ]agent\b|\bAI[- ]agent\b[^\n]{0,100}\bgitea\b", content, re.I)
        elif word == "agent-automation Postgres":
            found = re.search(r"\bagent[- ]automation\b[^\n]{0,80}\bpostgres(?:ql)?\b|\bagent automation\b[^\n]{0,80}\bpostgres(?:ql)?\b", content, re.I)
        elif word == "deeptutor":
            found = re.search(r"\bdeeptutor(?:-[\w-]+)?\b", content, re.I)
        else:
            found = re.search(r"(?<![\w-])" + re.escape(word) + r"(?![\w-])", content, re.I)
        if found:
            print(f"WARN {word}: removed ({when}, replaced by {replacement})")
    if re.search(r"(?<![\w])tenant(?![\w])", content, re.I):
        print("WARN tenant: say project")
    print("OK claims scan: completed (local claims only)")
    return rc


try:
    sys.exit(main())
except (OSError, UnicodeError):
    fail("input: unreadable", "check document, reference and manifest permissions/UTF-8 encoding")
    sys.exit(1)
PY
