#!/usr/bin/env python3
"""
Configuration Manager for the MT DevOps Framework.
"""

import contextlib
import os
import shlex
import sys


def get_config_path():
    return os.path.expanduser(
        os.environ.get("CONFIG_FILE", "~/.bash.d/config/config.yaml"))


def _export(var_name, value, home_dir, to_lower=False, resolve_home=False):
    val_str = str(value) if value is not None else ""
    if to_lower:
        val_str = val_str.lower()
    if resolve_home and val_str.startswith("~/"):
        val_str = val_str.replace("~", home_dir, 1)
    print(f"export {var_name}={shlex.quote(val_str)}")


def _read_yaml_config(path):
    """Reads config.yaml, falling back to {} (never None) on any failure so
    callers can still apply their own sensible defaults instead of losing
    every exported variable over one bad value or a missing dependency."""
    try:
        import yaml
    except ImportError:
        print(
            "echo -e '\033[01;31m🚨 Error: PyYAML is missing. Run bootstrap to install it.\033[0m' >&2"
        )
        return {}

    if not os.path.exists(path):
        return {}

    try:
        with open(path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    except (yaml.YAMLError, OSError) as e:
        print(f"echo -e '\033[01;31m🚨 Error parsing config.yaml: {e}\033[0m' >&2")
        return {}


def load_env():
    path = get_config_path()
    home = os.environ.get("HOME", "")

    d = _read_yaml_config(path)

    def export(var_name, value, to_lower=False, resolve_home=False):
        _export(var_name, value, home, to_lower, resolve_home)

    core_cfg = d.get("core") or d.get("system") or {}
    paths_cfg = d.get("paths") or {}
    ai_cfg = d.get("ai") or {}
    prov_cfg = ai_cfg.get("providers") or {}
    git_cfg = d.get("git") or {}
    exp_cfg = d.get("llm_exports") or d.get("exports") or {}
    dock_cfg = d.get("docker") or {}
    srv_cfg = d.get("server") or {}
    cicd_cfg = d.get("cicd") or {}

    # CI/CD
    export(
        "CICD_PROVIDER",
        cicd_cfg.get("default_provider", cicd_cfg.get("provider", "github")),
        to_lower=True,
    )

    # Core
    export("DEFAULT_IDE", core_cfg.get("default_ide", "vscode"), to_lower=True)
    export("BASH_THEME", core_cfg.get("theme", "default"), to_lower=True)
    export("UPDATE_CHECK_TTL_SEC", core_cfg.get("update_check_ttl_sec", 43200))
    export(
        "CONFIRM_UPDATE_DIVERGENCE",
        core_cfg.get("confirm_update_divergence", False),
        to_lower=True,
    )
    export("MAX_PARALLEL_THREADS", core_cfg.get("max_parallel_threads", 8))
    export("BACKUP_WARNING_MB", core_cfg.get("backup_warning_mb", 500))
    export("LOG_ROTATE_BYTES", core_cfg.get("log_rotate_bytes", 1048576))

    # AI
    export(
        "AI_ENABLED",
        ai_cfg.get("enable_ai", ai_cfg.get("enabled", True)),
        to_lower=True,
    )
    export("DEFAULT_AI", ai_cfg.get("default_provider", "gemini"), to_lower=True)
    export(
        "AI_MAX_DIFF_BYTES",
        ai_cfg.get("max_context_bytes", git_cfg.get("ai_max_diff_bytes", 150000)),
    )
    export("AI_MAX_RETRIES", ai_cfg.get("max_retries", 3))
    export("AI_MAX_CONTEXT_FILES", ai_cfg.get("max_context_files", 1000))

    sys_prompt_file = ai_cfg.get("system_prompt_file", "")
    sys_prompt = ""
    if sys_prompt_file:
        with (
                contextlib.suppress(OSError, TypeError),
                open(os.path.expanduser(sys_prompt_file), "r", encoding="utf-8") as f,
        ):
            sys_prompt = f.read().strip()
    export("AI_SYSTEM_PROMPT", sys_prompt)

    # Providers
    gem_cfg = prov_cfg.get("gemini") or ai_cfg.get("gemini") or {}
    export(
        "GEMINI_VERSION",
        gem_cfg.get("model", gem_cfg.get("version", "gemini-3.6-flash")),
    )
    export(
        "GEMINI_EXTENDED",
        gem_cfg.get("enable_extended_reasoning", gem_cfg.get("extended", False)),
        to_lower=True,
    )

    cla_cfg = prov_cfg.get("claude") or ai_cfg.get("claude") or {}
    export(
        "CLAUDE_VERSION",
        cla_cfg.get("model", cla_cfg.get("version", "claude-3-7-sonnet-latest")),
    )

    loc_cfg = prov_cfg.get("local") or ai_cfg.get("local") or {}
    export("LOCAL_AI_BASE_URL", loc_cfg.get("base_url", "http://localhost:11434/v1"))
    export("LOCAL_AI_MODEL", loc_cfg.get("model", "llama3.2"))

    # Exports
    export(
        "AUTO_CLEANUP_EXPORTS",
        exp_cfg.get("enable_auto_cleanup", exp_cfg.get("auto_cleanup", True)),
        to_lower=True,
    )
    export("AUTO_CLEANUP_DAYS", exp_cfg.get("auto_cleanup_days", 7))
    export(
        "EXPORT_BLOCKLIST",
        exp_cfg.get("file_blocklist_regex", exp_cfg.get("blocklist", "")),
    )
    export(
        "EXPORT_IGNORE_DIRS",
        exp_cfg.get("dir_ignore_glob", exp_cfg.get("ignore_dirs", "")),
    )
    export("EXPORT_WARN_FILE_THRESHOLD", exp_cfg.get("warn_file_threshold", 500))
    export("EXPORT_MAX_FILE_THRESHOLD", exp_cfg.get("max_file_threshold", 2000))

    # Git
    # NOTE: UPSTREAM_REPO_PATH is intentionally NOT sourced from config.yaml --
    # it's a hardcoded constant in 00-config.sh (the framework's
    # source-of-truth repo never changes per-user, unlike SYNC_REPO_URL).
    export("SYNC_REPO_URL", git_cfg.get("sync_repo_url", ""))
    export(
        "GIT_FEATURE_PREFIX",
        git_cfg.get("feature_branch_prefix", git_cfg.get("feature_prefix", "feature/")),
    )
    export(
        "GIT_FORMAT_ON_PUSH",
        git_cfg.get("enable_format_on_push", git_cfg.get("format_on_push", True)),
        to_lower=True,
    )

    # Paths
    export(
        "VCS_ROOT",
        paths_cfg.get("vcs_root_dir", paths_cfg.get("vcs_root", "~/vcs")),
        resolve_home=True,
    )
    export(
        "VCS_PERSONAL",
        paths_cfg.get("vcs_personal_dir", paths_cfg.get("vcs_personal",
                                                        "~/vcs/personal")),
        resolve_home=True,
    )
    export(
        "VCS_EXPORTS",
        paths_cfg.get("vcs_exports_dir",
                      paths_cfg.get("vcs_exports", "~/vcs/personal/exports")),
        resolve_home=True,
    )
    export(
        "DOTFILES_DIR",
        paths_cfg.get("dotfiles_dir", "~/vcs/personal/mt-devops-framework"),
        resolve_home=True,
    )
    export(
        "SYNC_REPO_DIR",
        paths_cfg.get(
            "sync_repo_dir",
            paths_cfg.get("sync_repo", "~/vcs/personal/mt-devops-framework"),
        ),
        resolve_home=True,
    )
    export(
        "AI_WORKSPACE_DIR",
        paths_cfg.get("ai_workspace_dir",
                      paths_cfg.get("ai_workspace", "~/workspaces/ai")),
        resolve_home=True,
    )
    export(
        "SCRIPTS_IAM_DIR",
        paths_cfg.get("iam_scripts_dir",
                      paths_cfg.get("scripts_iam", "/tmp/scripts/iam")),
        resolve_home=True,
    )
    export(
        "BACKUP_DIR",
        paths_cfg.get("backup_dir", "~/backups"),
        resolve_home=True,
    )
    export(
        "EXPORT_DIR",
        paths_cfg.get("export_dir", "/tmp/exports"),
        resolve_home=True,
    )
    export(
        "DOCKER_ROOT_DIR",
        paths_cfg.get("docker_root_dir", paths_cfg.get("docker_root", "~/.docker")),
        resolve_home=True,
    )
    export("THEMES_DIR", f"{home}/.bash.d/config/themes")

    # Docker
    export(
        "DOCKER_BLOCKLIST",
        dock_cfg.get("restart_blocklist_csv", dock_cfg.get("restart_blocklist", "")),
    )

    # HTTP Server (mt-http-server)
    export("HTTP_SERVER_DEFAULT_PORT", srv_cfg.get("default_port", 8000))
    export("HTTP_SERVER_ENABLE_AUTH", srv_cfg.get("enable_auth", False), to_lower=True)
    export(
        "HTTP_SERVER_ENABLE_LAN_BRIDGE",
        srv_cfg.get("enable_lan_bridge", False),
        to_lower=True,
    )
    export("HTTP_SERVER_IDLE_TIMEOUT_SEC", srv_cfg.get("idle_timeout_sec", 1800))


_MISSING = object()

# Every (old_path, new_path) leaf rename this framework's schema has gone
# through, expressed as dot-separated paths into the parsed config dict.
# This list is derived directly from the fallback chains in load_env()
# above (e.g. paths_cfg.get("vcs_root_dir", paths_cfg.get("vcs_root", ...)))
# -- each fallback pair there is proof a rename happened and is mirrored
# here so migrate_config() can retire the legacy side instead of letting
# it sit in config.yaml forever alongside the new one.
LEAF_RENAMES = [
    ("paths.vcs_root", "paths.vcs_root_dir"),
    ("paths.vcs_personal", "paths.vcs_personal_dir"),
    ("paths.vcs_exports", "paths.vcs_exports_dir"),
    ("paths.sync_repo", "paths.sync_repo_dir"),
    ("paths.ai_workspace", "paths.ai_workspace_dir"),
    ("paths.scripts_iam", "paths.iam_scripts_dir"),
    ("paths.docker_root", "paths.docker_root_dir"),
    ("git.feature_prefix", "git.feature_branch_prefix"),
    ("git.format_on_push", "git.enable_format_on_push"),
    ("git.ai_max_diff_bytes", "ai.max_context_bytes"),
    ("llm_exports.auto_cleanup", "llm_exports.enable_auto_cleanup"),
    ("llm_exports.blocklist", "llm_exports.file_blocklist_regex"),
    ("llm_exports.ignore_dirs", "llm_exports.dir_ignore_glob"),
    ("ai.enabled", "ai.enable_ai"),
    ("cicd.provider", "cicd.default_provider"),
    ("docker.restart_blocklist", "docker.restart_blocklist_csv"),
    # Provider config used to live flat under ai.<provider>.*; it now lives
    # nested under ai.providers.<provider>.*, with gemini/claude's old
    # "version" key renamed to "model" to match. Both the fully-legacy
    # (old location + old key) and half-migrated (old location + new key)
    # shapes are covered, since load_env()'s fallback tolerates both.
    ("ai.gemini.version", "ai.providers.gemini.model"),
    ("ai.gemini.model", "ai.providers.gemini.model"),
    ("ai.gemini.extended", "ai.providers.gemini.enable_extended_reasoning"),
    (
        "ai.gemini.enable_extended_reasoning",
        "ai.providers.gemini.enable_extended_reasoning",
    ),
    ("ai.claude.version", "ai.providers.claude.model"),
    ("ai.claude.model", "ai.providers.claude.model"),
    ("ai.local.base_url", "ai.providers.local.base_url"),
    ("ai.local.model", "ai.providers.local.model"),
]

# Whole top-level sections that were renamed outright (every child key
# under the old name means the same thing under the new one -- no
# per-key rename needed, just a merge).
SECTION_RENAMES = [
    ("system", "core"),
    ("exports", "llm_exports"),
]


def _get_path(d, path):
    """Walk a dot-separated path (e.g. "ai.gemini.version") through nested
    dicts.

    Arguments:
        d: The root dict to walk.
        path: Dot-separated key path.

    Returns:
        The value at that path, or the _MISSING sentinel if any segment
        along the way is absent or not itself a dict.
    """
    current = d
    for key in path.split("."):
        if not isinstance(current, dict) or key not in current:
            return _MISSING
        current = current[key]
    return current


def _set_path(d, path, value):
    """Write `value` at a dot-separated path, creating any missing (or
    wrongly-typed) intermediate dicts along the way."""
    keys = path.split(".")
    current = d
    for key in keys[:-1]:
        if key not in current or not isinstance(current[key], dict):
            current[key] = {}
        current = current[key]
    current[keys[-1]] = value


def _del_path(d, path):
    """Remove the value at a dot-separated path, if present. Leaves any
    now-empty parent dicts behind for _prune_empty_dicts to clean up."""
    keys = path.split(".")
    current = d
    for key in keys[:-1]:
        if not isinstance(current, dict) or key not in current:
            return
        current = current[key]
    if isinstance(current, dict):
        current.pop(keys[-1], None)


def _prune_empty_dicts(d):
    """Recursively delete dict values that ended up empty once migration
    moved their only contents elsewhere (e.g. a legacy `ai.gemini:` block
    left behind once both its keys migrated to `ai.providers.gemini`)."""
    for key in list(d.keys()):
        val = d[key]
        if isinstance(val, dict):
            _prune_empty_dicts(val)
            if not val:
                del d[key]


def _apply_section_renames(d, report):
    """Merge each legacy top-level section into its canonical replacement
    (e.g. `system:` -> `core:`), preferring whatever value the canonical
    section already holds on a key collision, then drop the legacy
    section. Appends a human-readable line per key to `report`."""
    for old_section, new_section in SECTION_RENAMES:
        old_block = d.get(old_section)
        if not isinstance(old_block, dict) or not old_block:
            if old_section in d:
                del d[old_section]
            continue
        new_block = d.setdefault(new_section, {})
        for key, val in old_block.items():
            if key not in new_block:
                new_block[key] = val
                report.append(f"moved {old_section}.{key} -> {new_section}.{key}")
            elif new_block[key] != val:
                report.append(
                    f"kept {new_section}.{key}={new_block[key]!r}, discarded "
                    f"conflicting legacy {old_section}.{key}={val!r}"
                )
            else:
                report.append(f"removed duplicate legacy key {old_section}.{key}")
        del d[old_section]


def _apply_leaf_renames(d, report):
    """Apply every (old_path, new_path) rule in LEAF_RENAMES: move the
    value forward if the canonical key is missing, otherwise keep the
    canonical value and report (rather than silently discard) any legacy
    value that disagrees with it. Appends a human-readable line per
    change to `report`."""
    for old_path, new_path in LEAF_RENAMES:
        old_val = _get_path(d, old_path)
        if old_val is _MISSING:
            continue
        new_val = _get_path(d, new_path)
        if new_val is _MISSING:
            _set_path(d, new_path, old_val)
            report.append(f"moved {old_path} -> {new_path}")
        elif new_val != old_val:
            report.append(
                f"kept {new_path}={new_val!r}, discarded conflicting "
                f"legacy {old_path}={old_val!r}"
            )
        else:
            report.append(f"removed duplicate legacy key {old_path}")
        _del_path(d, old_path)


def _compute_migration(d):
    """Apply every migration rule to a deep copy of `d` and report what
    would change, without touching the original.

    Arguments:
        d: The parsed config.yaml dict (left untouched).

    Returns:
        (migrated_copy, report) -- migrated_copy is the fully migrated
        dict, report is the list of human-readable change lines (empty
        if nothing needed migrating). Shared by migrate_config() (which
        writes migrated_copy back to disk) and check_config() (which
        only wants the report, read-only, for `mt-doctor`).
    """
    import copy

    working = copy.deepcopy(d)
    report = []
    _apply_section_renames(working, report)
    _apply_leaf_renames(working, report)
    _prune_empty_dicts(working)
    return working, report


def check_config():
    """Report-only counterpart to migrate_config(): prints whether
    config.yaml has legacy keys pending migration, without writing
    anything. Used by `mt-doctor` to surface config drift alongside its
    other environment checks without mutating state as a side effect of
    a report command.
    """
    import yaml

    path = get_config_path()
    if not os.path.exists(path):
        print("SKIP: no config.yaml found yet.")
        return

    with open(path, "r", encoding="utf-8") as f:
        d = yaml.safe_load(f) or {}

    if not isinstance(d, dict):
        print("WARN: config.yaml did not parse to a mapping.")
        return

    _, report = _compute_migration(d)
    if not report:
        print("OK: config.yaml matches the current schema.")
        return

    plural = "y" if len(report) == 1 else "ies"
    print(f"WARN: {len(report)} legacy config.yaml entr{plural} pending migration "
          f"-- run 'mt-migrate-config' to clean up:")
    for line in report:
        print(f"  - {line}")


def migrate_config():
    """Detect and clean up legacy config.yaml keys left behind by past
    schema renames (see LEAF_RENAMES/SECTION_RENAMES).

    config.yaml is only ever created once, from config.yaml.tpl, the
    first time a shell starts with none present (see 00-config.sh) -- it
    is never otherwise touched or migrated across framework updates. So
    when a later release renames a key, every existing installation just
    keeps writing to the OLD name forever (update_yaml() and every wizard
    call-site only know the CURRENT canonical name, so they add it
    alongside instead of replacing anything), and config.yaml
    accumulates both the legacy and canonical key for every rename it
    has lived through.

    This is a safe no-op if no legacy keys are found. When there is
    something to migrate, the original file is backed up to
    BACKUP_DIR/config-migrations/ first, then the cleaned-up config is
    written back and the env cache is invalidated so the next shell
    reload picks up the change. Prints a human-readable report either
    way. Called both automatically (end of mt-get-update's install step)
    and on demand via `mt-migrate-config`.
    """
    import shutil
    from datetime import datetime

    import yaml

    path = get_config_path()
    if not os.path.exists(path):
        print("No config.yaml found -- nothing to migrate.")
        return

    with open(path, "r", encoding="utf-8") as f:
        d = yaml.safe_load(f) or {}

    if not isinstance(d, dict):
        print("🚨 config.yaml did not parse to a mapping -- skipping migration.")
        return

    d, report = _compute_migration(d)

    if not report:
        print(
            "✅ config.yaml already matches the current schema -- nothing to migrate."
        )
        return

    home = os.environ.get("HOME", "")
    backup_dir = os.path.join(
        os.path.expanduser(
            os.environ.get("BACKUP_DIR", "~/backups").replace("~", home, 1)
        ),
        "config-migrations",
    )
    os.makedirs(backup_dir, exist_ok=True)
    timestamp = datetime.now().astimezone().strftime("%Y%m%d_%H%M%S")
    backup_path = os.path.join(backup_dir, f"config_pre-migration_{timestamp}.yaml")
    shutil.copy2(path, backup_path)
    os.chmod(backup_path, 0o600)

    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(d, f, sort_keys=False, default_flow_style=False)
    os.chmod(path, 0o600)

    cache_file = os.path.expanduser("~/.bash.d/data/cache/.env.cache")
    if os.path.exists(cache_file):
        os.remove(cache_file)

    plural = "y" if len(report) == 1 else "ies"
    print(f"🔧 Migrated {len(report)} legacy config.yaml entr{plural}:")
    for line in report:
        print(f"   - {line}")
    print(f"📦 Backup saved to {backup_path}")


def update_yaml(cat_path, key, val):
    import yaml

    path = get_config_path()
    d = {}
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            d = yaml.safe_load(f) or {}

    keys = cat_path.split(".")
    current = d
    for k in keys:
        if k not in current or not isinstance(current[k], dict):
            current[k] = {}
        current = current[k]

    current[key] = val

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(d, f, sort_keys=False, default_flow_style=False)

    os.chmod(path, 0o600)

    cache_file = os.path.expanduser("~/.bash.d/data/cache/.env.cache")
    if os.path.exists(cache_file):
        os.remove(cache_file)


if __name__ == "__main__" and len(sys.argv) > 1:
    cmd = sys.argv[1]
    if cmd == "load-env":
        load_env()
    elif cmd == "update" and len(sys.argv) == 5:
        update_yaml(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "migrate":
        migrate_config()
    elif cmd == "check-config":
        check_config()
