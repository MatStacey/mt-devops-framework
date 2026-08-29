#!/usr/bin/env python3
"""
Docker image version tracking for the MT DevOps Framework.

Tracks the last version built per image name in a local TSV state file
so docker-build (02-utilities/36-docker-registry.sh) can auto-increment
a semver patch version instead of requiring a manually-picked tag. Pure
functions over a plain TSV -- no format change from the bash/awk
implementation this replaces, so existing build history keeps working.
"""

import os
import sys

import config_manager

VERSION_FILE = os.path.join(
    config_manager.xdg_dir("XDG_CACHE_HOME", (".cache",), os.environ.get("HOME", "")),
    ".docker_image_versions.tsv",
)


def _read_versions(path):
    """Reads the version-tracker TSV into an ordered {image: version}
    dict, tolerating a missing file (nothing built yet) as an empty map.
    """
    versions = {}
    if not os.path.exists(path):
        return versions
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            image, _, version = line.partition("\t")
            if image:
                versions[image] = version
    return versions


def _write_versions(path, versions):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(f"{image}\t{version}\n" for image, version in versions.items())


def next_version(image, path=VERSION_FILE):
    """Computes the next auto-incremented semver for an image, based on
    the last version recorded for it. Read-only -- never writes
    anything, so a failed build never consumes a version number.

    Arguments:
        image: Image name.
        path: Version-tracker TSV path (overridable for tests).

    Returns:
        "v0.1.0" for a never-built image, otherwise the last recorded
        version's patch component incremented by one.
    """
    last = _read_versions(path).get(image)
    if not last:
        return "v0.1.0"
    major, minor, patch = last.lstrip("v").split(".")
    return f"v{major}.{minor}.{int(patch) + 1}"


def last_version(image, path=VERSION_FILE):
    """Looks up the most recently recorded version for an image.

    Arguments:
        image: Image name.
        path: Version-tracker TSV path (overridable for tests).

    Returns:
        The last recorded version string, or None if this image has
        never been built.
    """
    return _read_versions(path).get(image)


def record_version(image, version, path=VERSION_FILE):
    """Persists the version just built for an image, so the next
    next_version() call increments from it. Only ever called after a
    successful build (see docker-build), so a failed build never burns
    a version number.

    Arguments:
        image: Image name.
        version: Version that was just built (e.g. "v0.1.0").
        path: Version-tracker TSV path (overridable for tests).
    """
    versions = _read_versions(path)
    versions[image] = version
    _write_versions(path, versions)


def main():
    if len(sys.argv) < 3:
        print(
            "Usage: docker_versions.py <next-version|last-version> <image>",
            file=sys.stderr,
        )
        print(
            "       docker_versions.py record-version <image> <version>",
            file=sys.stderr,
        )
        sys.exit(1)

    cmd, image = sys.argv[1], sys.argv[2]
    if cmd == "next-version":
        print(next_version(image))
    elif cmd == "last-version":
        result = last_version(image)
        if result:
            print(result)
    elif cmd == "record-version" and len(sys.argv) >= 4:
        record_version(image, sys.argv[3])
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
