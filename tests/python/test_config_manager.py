"""Tests for lib/python/config_manager.py's pure path/migration logic."""

import config_manager


def test_get_path_walks_nested_dict():
    d = {"ai": {"providers": {"gemini": {"model": "gemini-3.6-flash"}}}}
    assert (
        config_manager._get_path(d, "ai.providers.gemini.model") == "gemini-3.6-flash"
    )


def test_get_path_missing_segment_returns_missing_sentinel():
    d = {"ai": {}}
    assert (
        config_manager._get_path(d, "ai.providers.gemini.model")
        is config_manager._MISSING
    )


def test_set_path_creates_missing_intermediate_dicts():
    d = {}
    config_manager._set_path(d, "ai.providers.gemini.model", "gemini-3.6-flash")
    assert d == {"ai": {"providers": {"gemini": {"model": "gemini-3.6-flash"}}}}


def test_compute_migration_moves_legacy_leaf_forward():
    d = {"paths": {"vcs_root": "~/vcs"}}
    migrated, report = config_manager._compute_migration(d)

    assert migrated["paths"] == {"vcs_root_dir": "~/vcs"}
    assert report == ["moved paths.vcs_root -> paths.vcs_root_dir"]


def test_compute_migration_never_touches_the_original_dict():
    d = {"paths": {"vcs_root": "~/vcs"}}
    config_manager._compute_migration(d)
    assert d == {"paths": {"vcs_root": "~/vcs"}}


def test_compute_migration_keeps_canonical_value_on_conflict():
    d = {"paths": {"vcs_root": "~/old-vcs", "vcs_root_dir": "~/vcs"}}
    migrated, report = config_manager._compute_migration(d)

    assert migrated["paths"] == {"vcs_root_dir": "~/vcs"}
    assert report[0].startswith("kept paths.vcs_root_dir=")
    assert "paths.vcs_root=" in report[0]


def test_compute_migration_merges_legacy_section_rename():
    d = {"system": {"theme": "dracula"}}
    migrated, report = config_manager._compute_migration(d)

    assert migrated == {"core": {"theme": "dracula"}}
    assert report == ["moved system.theme -> core.theme"]


def test_compute_migration_is_a_no_op_on_current_schema():
    d = {"core": {"theme": "default"}, "docker": {"restart_blocklist_csv": "redis"}}
    migrated, report = config_manager._compute_migration(d)

    assert migrated == d
    assert report == []
