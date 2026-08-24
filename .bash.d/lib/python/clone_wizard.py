"""
Fetches repository lists from source-control providers for mt-clone.
Only ever prints repo metadata for the bash orchestrator
(mt-clone, .bash.d/20-vcs/54-clone.sh) to act on -- never clones
anything and never touches credentials on disk itself.

PROVIDERS is the extension point for future providers (e.g. GitHub):
add a provider name -> fetch function entry here. Each fetch function
owns its own provider-specific auth (reading the relevant secret env
vars) and pagination.

Usage:
    python clone_wizard.py fetch <provider> <workspace> <project>
"""

import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

BITBUCKET_API = "https://api.bitbucket.org/2.0"


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


def cmd_fetch(provider, workspace, project):
    fetch_fn = PROVIDERS.get(provider)
    if not fetch_fn:
        print(
            f"clone_wizard.py: unsupported provider '{provider}' (supported: {', '.join(PROVIDERS)})",
            file=sys.stderr,
        )
        sys.exit(1)
    for r in fetch_fn(workspace, project):
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
    if len(sys.argv) < 2:
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "fetch" and len(sys.argv) == 5:
        cmd_fetch(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        print("Usage: clone_wizard.py fetch <provider> <workspace> <project>", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
