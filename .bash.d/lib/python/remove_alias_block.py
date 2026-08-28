"""
Removes an alias's definition line -- and its immediately preceding
docstring block, if the block's own '###...' fence is followed within a
few lines by that exact `alias <name>=` line -- from an aliases file.

Used by `mt-alias -u` to clear out an alias's old entry before the updated
alias + docstring are appended back in, so an update never leaves a stale
duplicate definition behind.

Usage:
    python remove_alias_block.py <aliases_file> <alias_name>
"""

import sys

DOCSTRING_FENCE = "#######################################"
LOOKAHEAD_LINES = 9


def main():
    if len(sys.argv) < 3:
        sys.exit(1)

    file_path = sys.argv[1]
    alias_prefix = f"alias {sys.argv[2]}="

    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.read().split("\n")

    kept = []
    i = 0
    while i < len(lines):
        line = lines[i]

        if line.startswith(DOCSTRING_FENCE):
            lookahead = lines[i + 1 : i + 1 + LOOKAHEAD_LINES]
            if any(x.startswith(alias_prefix) for x in lookahead):
                # Skip the whole docstring block, up to and including the
                # alias definition line it documents.
                while not lines[i].startswith(alias_prefix):
                    i += 1
                i += 1
                continue

        if line.startswith(alias_prefix):
            i += 1
            continue

        kept.append(line)
        i += 1

    while kept and kept[-1].strip() == "":
        kept.pop()

    with open(file_path, "w", encoding="utf-8") as f:
        f.write("\n".join(kept) + "\n")


if __name__ == "__main__":
    main()
