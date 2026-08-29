"""
Tracks metadata for the framework's "supported secrets" registry (Gemini,
Claude, Bitbucket, ...) -- system, description, created/expiry/last-used
dates only. NEVER the secret values themselves, which live exclusively in
~/secrets/secrets.sh and are never read or printed by this script.

The registry of supported secret types is a static, framework-defined
constant (SUPPORTED_SECRETS) -- extend it here to add a new supported
secret type, paired with a real `mt-add-<x>-key`/`mt-add-<x>-secret`
function (see .bash.d/00-system/01-secrets.sh) that writes the value via
__mt_write_secret and then calls this script's `register` subcommand.

Metadata is persisted to ~/.bash.d/config/secrets_metadata.yaml, keyed by
secret name.

Usage:
    python secrets_manager.py list
    python secrets_manager.py describe <NAME>
    python secrets_manager.py register <NAME> [expiry_date]
    python secrets_manager.py unregister <NAME>
    python secrets_manager.py touch <NAME>
"""

import os
import sys
from datetime import datetime, timezone

import yaml

METADATA_FILE = os.path.expanduser("~/.bash.d/config/secrets_metadata.yaml")
SECRETS_FILE = os.path.expanduser("~/secrets/secrets.sh")
EXPIRY_WARNING_DAYS = 30

SUPPORTED_SECRETS = {
    "GEMINI_API_KEY": {
        "system": "Google Gemini",
        "description": "AI queries (ai, git-ai-push-all, README summarization, mt-ai-debug)",
        "add_command": "mt-add-gemini-key",
        "paired_with": None,
    },
    "CLAUDE_API_KEY": {
        "system": "Anthropic Claude",
        "description": "AI queries (ai, git-ai-push-all, README summarization, mt-ai-debug)",
        "add_command": "mt-add-claude-key",
        "paired_with": None,
    },
    "BITBUCKET_API_KEY": {
        "system": "Atlassian Bitbucket",
        "description": "Repository cloning and workspace operations (mt-bitbucket-clone)",
        "add_command": "mt-add-bitbucket-secret",
        "paired_with": "BITBUCKET_EMAIL",
    },
    "DOCKERHUB_TOKEN": {
        "system": "Docker Hub",
        "description": "Image pushes (docker-push, docker-release, docker-deploy)",
        "add_command": "mt-add-dockerhub-secret",
        "paired_with": "DOCKERHUB_USERNAME",
    },
}


def _load_metadata():
    if not os.path.exists(METADATA_FILE):
        return {}
    with open(METADATA_FILE, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def _save_metadata(data):
    os.makedirs(os.path.dirname(METADATA_FILE), exist_ok=True)
    with open(METADATA_FILE, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False, default_flow_style=False)
    os.chmod(METADATA_FILE, 0o600)


def _today():
    """Today's calendar date in UTC -- expiry/created/last-used are all
    plain dates (no time-of-day meaning), so UTC just gives a single,
    deterministic reference point rather than depending on the host's
    local timezone."""
    return datetime.now(tz=timezone.utc).date()


def _is_configured(name):
    """Whether `name` has a real value set in secrets.sh -- read only for
    line presence, the value itself is never inspected or returned."""
    if not os.path.exists(SECRETS_FILE):
        return False
    with open(SECRETS_FILE, "r", encoding="utf-8") as f:
        return any(line.startswith(f"export {name}=") for line in f)


def _expiry_status(expiry_str):
    """Classifies an expiry date string against today. Returns
    (status, days_remaining) where status is one of 'expired', 'expiring'
    (<= EXPIRY_WARNING_DAYS away), 'ok', or 'none' (unset/unparseable)."""
    if not expiry_str:
        return "none", None
    try:
        expiry = datetime.strptime(expiry_str, "%Y-%m-%d").replace(tzinfo=timezone.utc).date()
    except ValueError:
        return "none", None
    days = (expiry - _today()).days
    if days < 0:
        return "expired", days
    if days <= EXPIRY_WARNING_DAYS:
        return "expiring", days
    return "ok", days


def cmd_list():
    """Prints one pipe-delimited line per registered secret type:
    name|system|description|configured|created|expiry|status|days|last_used"""
    metadata = _load_metadata()
    for name, spec in SUPPORTED_SECRETS.items():
        configured = _is_configured(name)
        meta = metadata.get(name, {}) if configured else {}
        created = meta.get("created", "")
        expiry = meta.get("expiry", "")
        last_used = meta.get("last_used", "")
        status, days = _expiry_status(expiry)
        print(
            "|".join(
                [
                    name,
                    spec["system"],
                    spec["description"],
                    "true" if configured else "false",
                    created,
                    expiry,
                    status,
                    str(days) if days is not None else "",
                    last_used,
                ]
            )
        )


def cmd_describe(name):
    """Prints add_command|paired_with for one registered secret type, so
    bash callers (the mt-secrets menu) don't need their own copy of the
    registry to know which command adds it or what its paired var is."""
    spec = SUPPORTED_SECRETS.get(name)
    if not spec:
        sys.exit(1)
    print(f"{spec['add_command']}|{spec['paired_with'] or ''}")


def cmd_register(name, expiry=None):
    """Records (or preserves) a secret's created date and optionally sets
    its expiry -- called right after __mt_write_secret writes the value."""
    if name not in SUPPORTED_SECRETS:
        print(f"secrets_manager.py: '{name}' is not a supported secret", file=sys.stderr)
        sys.exit(1)
    metadata = _load_metadata()
    entry = metadata.get(name, {})
    if "created" not in entry:
        entry["created"] = _today().isoformat()
    if expiry:
        entry["expiry"] = expiry
    metadata[name] = entry
    _save_metadata(metadata)


def cmd_unregister(name):
    """Clears a secret's tracked metadata -- called when its value is
    deleted, so a later re-add starts a fresh created/expiry history."""
    metadata = _load_metadata()
    if name in metadata:
        del metadata[name]
        _save_metadata(metadata)


def cmd_touch(name):
    """Records today as the secret's last-used date."""
    if name not in SUPPORTED_SECRETS:
        return
    metadata = _load_metadata()
    entry = metadata.get(name, {})
    entry["last_used"] = _today().isoformat()
    metadata[name] = entry
    _save_metadata(metadata)


def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "list":
        cmd_list()
    elif cmd == "describe" and len(sys.argv) >= 3:
        cmd_describe(sys.argv[2])
    elif cmd == "register" and len(sys.argv) >= 3:
        cmd_register(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    elif cmd == "unregister" and len(sys.argv) >= 3:
        cmd_unregister(sys.argv[2])
    elif cmd == "touch" and len(sys.argv) >= 3:
        cmd_touch(sys.argv[2])
    else:
        print(
            "Usage: secrets_manager.py <list|describe|register|unregister|touch> [args]",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
