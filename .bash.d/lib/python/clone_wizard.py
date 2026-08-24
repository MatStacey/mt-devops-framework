"""
Fetches repository lists from source-control providers for mt-clone,
applying any --type/--lang/--from-date/--year/--age filters client-side
against the full fetched list rather than a provider-specific query
DSL. Only ever prints repo metadata for the bash orchestrator
(mt-clone, .bash.d/20-vcs/54-clone.sh) to act on -- never clones
anything and never touches credentials on disk itself.

PROVIDERS is the extension point for future providers (e.g. GitHub):
add a provider name -> fetch function entry here. Each fetch function
owns its own provider-specific auth (reading the relevant secret env
vars) and pagination, and returns plain repo dicts -- filtering is
applied uniformly afterward regardless of provider.

Usage:
    python clone_wizard.py fetch <provider> <workspace> <project>
        [--type private|public] [--lang LANGUAGE]
        [--from-date DATE] [--year YYYY] [--age DAYS]
"""

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

BITBUCKET_API = "https://api.bitbucket.org/2.0"


def _today():
    return datetime.now(tz=timezone.utc).date()


def _bitbucket_auth_header():
    email = os.environ.get("BITBUCKET_EMAIL", "")
    token = os.environ.get("BITBUCKET_API_KEY", "")
    if not email or not token:
        print(
            "clone_wizard.py: BITBUCKET_EMAIL/BITBUCKET_API_KEY not set -- run 'mt-add-bitbucket-secret'",
            file=sys.stderr,
        )
        sys.exit(1)
    creds = base64.b64encode(f"{email}:{token}".encode()).decode()
    return f"Basic {creds}"


def _bitbucket_get(url):
    req = urllib.request.Request(
        url, headers={"Authorization": _bitbucket_auth_header(), "Accept": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        print(f"clone_wizard.py: Bitbucket API error {e.code}: {body[:300]}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"clone_wizard.py: failed to reach Bitbucket API: {e.reason}", file=sys.stderr)
        sys.exit(1)


def _bitbucket_resolve_project_key(workspace, project):
    """Bitbucket's repository-list query filter needs the project KEY
    (a short code), not its display name -- but users naturally think
    in display names, so match the given value case-insensitively
    against either, listing what's actually available on a miss."""
    url = f"{BITBUCKET_API}/workspaces/{workspace}/projects?pagelen=100"
    candidates = []
    while url:
        data = _bitbucket_get(url)
        for p in data.get("values", []):
            candidates.append((p["key"], p["name"]))
            if project.lower() in (p["key"].lower(), p["name"].lower()):
                return p["key"]
        url = data.get("next")
    available = ", ".join(f"{k} ({n})" for k, n in candidates) or "none found"
    print(
        f"clone_wizard.py: no project matching '{project}' in workspace '{workspace}'. Available: {available}",
        file=sys.stderr,
    )
    sys.exit(1)


def _fetch_bitbucket_repos(workspace, project):
    key = _bitbucket_resolve_project_key(workspace, project)
    query = urllib.parse.quote(f'project.key="{key}"')
    url = f"{BITBUCKET_API}/repositories/{workspace}?q={query}&pagelen=100"
    repos = []
    while url:
        data = _bitbucket_get(url)
        for r in data.get("values", []):
            clone_url = next(
                (link["href"] for link in r.get("links", {}).get("clone", []) if link["name"] == "https"),
                "",
            )
            repos.append(
                {
                    "slug": r["slug"],
                    "clone_url": clone_url,
                    "size_bytes": r.get("size", 0),
                    "language": r.get("language") or "",
                    "updated_on": r.get("updated_on", ""),
                    "is_private": r.get("is_private", True),
                }
            )
        url = data.get("next")
    return repos


PROVIDERS = {
    "bitbucket": _fetch_bitbucket_repos,
}


def _parse_from_date(value):
    """Accepts dd-mm-yyyy, dd/mm/yyyy, ddmmyyyy, or the 4-digit ddmm
    shorthand (current year assumed) -- matches mt-clone's spec."""
    cleaned = value.replace("-", "").replace("/", "")
    if len(cleaned) == 4:
        cleaned += str(_today().year)
    if len(cleaned) != 8 or not cleaned.isdigit():
        print(
            f"clone_wizard.py: invalid --from-date '{value}' -- expected dd-mm-yyyy, dd/mm/yyyy, ddmmyyyy, or ddmm",
            file=sys.stderr,
        )
        sys.exit(1)
    day, month, year = cleaned[0:2], cleaned[2:4], cleaned[4:8]
    try:
        return datetime(int(year), int(month), int(day), tzinfo=timezone.utc).date()
    except ValueError as e:
        print(f"clone_wizard.py: invalid --from-date '{value}': {e}", file=sys.stderr)
        sys.exit(1)


def _parse_year(value):
    try:
        year = int(value)
    except ValueError:
        print(f"clone_wizard.py: invalid --year '{value}' -- expected a 4-digit year", file=sys.stderr)
        sys.exit(1)
    try:
        return datetime(year, 1, 1, tzinfo=timezone.utc).date()
    except ValueError as e:
        print(f"clone_wizard.py: invalid --year '{value}': {e}", file=sys.stderr)
        sys.exit(1)


def _parse_age(value):
    try:
        days = int(value)
    except ValueError:
        print(f"clone_wizard.py: invalid --age '{value}' -- expected a whole number of days", file=sys.stderr)
        sys.exit(1)
    if days < 0:
        print("clone_wizard.py: --age must be a non-negative number of days", file=sys.stderr)
        sys.exit(1)
    return _today() - timedelta(days=days)


def _resolve_cutoff_date(args):
    """Combines --from-date/--year/--age into a single cutoff date --
    per mt-clone's spec, when more than one is given the OLDEST
    (chronologically earliest, i.e. most inclusive) cutoff wins."""
    candidates = []
    if args.from_date:
        candidates.append(_parse_from_date(args.from_date))
    if args.year:
        candidates.append(_parse_year(args.year))
    if args.age is not None:
        candidates.append(_parse_age(args.age))
    return min(candidates) if candidates else None


def _repo_updated_date(repo):
    iso = repo["updated_on"].replace("Z", "+00:00")
    return datetime.fromisoformat(iso).date()


def _apply_filters(repos, args):
    cutoff = _resolve_cutoff_date(args)
    if args.type:
        want_private = args.type == "private"
        repos = [r for r in repos if r["is_private"] == want_private]
    if args.lang:
        repos = [r for r in repos if r["language"].lower() == args.lang.lower()]
    if cutoff:
        repos = [r for r in repos if r["updated_on"] and _repo_updated_date(r) >= cutoff]
    return repos


def cmd_fetch(args):
    fetch_fn = PROVIDERS.get(args.provider)
    if not fetch_fn:
        print(
            f"clone_wizard.py: unsupported provider '{args.provider}' (supported: {', '.join(PROVIDERS)})",
            file=sys.stderr,
        )
        sys.exit(1)
    repos = _apply_filters(fetch_fn(args.workspace, args.project), args)
    for r in repos:
        print(
            "|".join(
                [
                    r["slug"],
                    r["clone_url"],
                    str(r["size_bytes"]),
                    r["language"],
                    r["updated_on"],
                    "true" if r["is_private"] else "false",
                ]
            )
        )


def main():
    parser = argparse.ArgumentParser(prog="clone_wizard.py")
    subparsers = parser.add_subparsers(dest="command", required=True)

    fetch_parser = subparsers.add_parser("fetch")
    fetch_parser.add_argument("provider")
    fetch_parser.add_argument("workspace")
    fetch_parser.add_argument("project")
    fetch_parser.add_argument("--type", choices=["private", "public"])
    fetch_parser.add_argument("--lang")
    fetch_parser.add_argument("--from-date")
    fetch_parser.add_argument("--year")
    fetch_parser.add_argument("--age")

    args = parser.parse_args()
    if args.command == "fetch":
        cmd_fetch(args)


if __name__ == "__main__":
    main()
