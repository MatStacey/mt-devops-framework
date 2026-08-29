"""Tests for lib/python/docker_versions.py's pure version-tracking logic."""

import docker_versions


def test_next_version_for_never_built_image_starts_at_0_1_0(tmp_path):
    version_file = tmp_path / "versions.tsv"
    assert docker_versions.next_version("myapp", path=str(version_file)) == "v0.1.0"


def test_next_version_increments_patch(tmp_path):
    version_file = tmp_path / "versions.tsv"
    docker_versions.record_version("myapp", "v1.2.3", path=str(version_file))
    assert docker_versions.next_version("myapp", path=str(version_file)) == "v1.2.4"


def test_last_version_returns_none_for_never_built_image(tmp_path):
    version_file = tmp_path / "versions.tsv"
    assert docker_versions.last_version("myapp", path=str(version_file)) is None


def test_record_version_then_last_version_round_trips(tmp_path):
    version_file = tmp_path / "versions.tsv"
    docker_versions.record_version("myapp", "v0.1.0", path=str(version_file))
    assert docker_versions.last_version("myapp", path=str(version_file)) == "v0.1.0"


def test_record_version_updates_existing_entry_in_place(tmp_path):
    version_file = tmp_path / "versions.tsv"
    docker_versions.record_version("myapp", "v0.1.0", path=str(version_file))
    docker_versions.record_version("other", "v0.1.0", path=str(version_file))
    docker_versions.record_version("myapp", "v0.2.0", path=str(version_file))

    assert docker_versions.last_version("myapp", path=str(version_file)) == "v0.2.0"
    assert docker_versions.last_version("other", path=str(version_file)) == "v0.1.0"
    # Updating myapp in place shouldn't duplicate its row or disturb other's.
    assert version_file.read_text().splitlines() == ["myapp\tv0.2.0", "other\tv0.1.0"]


def test_failed_build_never_burns_a_version_number(tmp_path):
    """docker-build only calls record_version() after a successful build --
    this pins down that calling next_version() alone (simulating a build
    that failed and never recorded) doesn't advance the counter."""
    version_file = tmp_path / "versions.tsv"
    docker_versions.record_version("myapp", "v1.0.0", path=str(version_file))

    first_attempt = docker_versions.next_version("myapp", path=str(version_file))
    second_attempt = docker_versions.next_version("myapp", path=str(version_file))

    assert first_attempt == second_attempt == "v1.0.1"
