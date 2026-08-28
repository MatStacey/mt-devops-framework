"""
Resolves an mt-export schema file by alias, name, or filename stem.

Searches every *.yaml file in the given schemas directory for one whose
`aliases` list contains the query, whose `name` matches it case-insensitively,
or whose filename (minus extension) matches it. Prints the resolved path and
exits, or prints nothing if no schema matches.

Usage:
    python resolve_export_schema.py <schemas_dir> <query>
"""

import os
import sys

import yaml


def main():
    if len(sys.argv) < 3:
        sys.exit(1)

    schemas_dir = sys.argv[1]
    query = sys.argv[2].lower()

    for filename in os.listdir(schemas_dir):
        if not filename.endswith(".yaml"):
            continue

        path = os.path.join(schemas_dir, filename)
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = yaml.safe_load(f) or {}
        except (OSError, yaml.YAMLError):
            continue

        aliases = data.get("aliases", [])
        stem = filename.split(".")[0]
        if query in aliases or query == data.get("name", "").lower() or query == stem:
            print(path)
            return

    print()


if __name__ == "__main__":
    main()
