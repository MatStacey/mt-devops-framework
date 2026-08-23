"""
Updates the 'Recent Updates & Enhancements' section of a Markdown file.

This script reads a target Markdown file, locates the section starting with
'## 🚀 Recent Updates & Enhancements' and ending with a standalone '---'
horizontal rule, and PREPENDS the new content to its existing bullet list
(most recent first) rather than replacing it, so the section accumulates a
rolling history of recent changes instead of only ever reflecting the
single latest push. The combined list is capped at MAX_BULLETS entries,
dropping the oldest ones once exceeded.

Usage:
    python update_readme_summary.py <file_path> <new_content>
"""

import json
import re
import sys

HEADING = "## 🚀 Recent Updates & Enhancements"
MAX_BULLETS = 8

# The section's own closing delimiter: a "---" alone on its line. Only
# consumes through that line's own newline, so any blank line separating it
# from the next section is left untouched.
SECTION_PATTERN = re.compile(
    re.escape(HEADING) + r".*?\n-{3,}[ \t]*(?:\n|$)", re.DOTALL)

# Fallback if a prior run left the section without its closing "---":
# stop at the next top-level heading instead.
NEXT_HEADING_PATTERN = re.compile(
    re.escape(HEADING) + r".*?(?=\n## )", re.DOTALL)

BULLET_LINE = re.compile(r"^[ \t]*[-*][ \t]+")


def _looks_like_code_or_raw_json(text):
    """Heuristic: does this look like leaked code/JSON rather than prose?"""
    stripped = text.strip()
    if not stripped:
        return False
    try:
        json.loads(stripped)
        return True
    except (json.JSONDecodeError, ValueError):
        pass
    # Escaped quotes are a strong signal of a raw JSON string body leaking in.
    if '\\"' in stripped:
        return True
    # Shebangs or shell heredoc markers.
    return bool(re.search(r"^\s*#!/|<<['\"]?[A-Z_]+['\"]?\s*$", stripped, re.MULTILINE))


def _extract_bullets(text):
    """Pulls each top-level bullet line out of a block of markdown text,
    stripping the leading '-'/'*' marker, and returns the bare bullet
    bodies in their original order."""
    return [
        BULLET_LINE.sub("", line, count=1).strip()
        for line in text.splitlines()
        if BULLET_LINE.match(line)
    ]


def _split_new_bullets(new_content):
    """Splits incoming content into one or more bullet-body strings. If
    it's already bullet-formatted (the common case -- the AI prompt and
    the manual quota-fallback callers both produce '- '-prefixed lines),
    each bullet becomes its own entry; otherwise the whole block becomes
    a single entry."""
    if any(BULLET_LINE.match(line) for line in new_content.splitlines()):
        return _extract_bullets(new_content)
    stripped = new_content.strip()
    return [stripped] if stripped else []


def main():
    """Reads the target file, prepends new_content to the updates section's
    bullet list (capped at MAX_BULLETS entries), and overwrites the file."""
    if len(sys.argv) < 3:
        sys.exit(1)

    file_path = sys.argv[1]
    new_content = sys.argv[2]

    with open(file_path, "r", encoding="utf-8") as f:
        c = f.read()

    # Strip any standalone "---" lines from the incoming content so it can
    # never be mistaken for the section's own closing delimiter on a later run.
    new_content = re.sub(r"(?m)^-{3,}\s*$", "", new_content).strip()

    if _looks_like_code_or_raw_json(new_content):
        new_bullets = [f"```\n{new_content}\n```"]
    else:
        new_bullets = _split_new_bullets(new_content)

    if not new_bullets:
        return

    section_match = SECTION_PATTERN.search(c)
    existing_bullets = (
        _extract_bullets(section_match.group(0)) if section_match else []
    )

    combined = new_bullets + [b for b in existing_bullets if b not in new_bullets]
    combined = combined[:MAX_BULLETS]

    body = "\n".join(f"- {b}" for b in combined)
    updates = f"{HEADING}\n\n{body}\n\n---\n"

    if section_match:
        c_new = SECTION_PATTERN.sub(updates, c, count=1)
    elif NEXT_HEADING_PATTERN.search(c):
        c_new = NEXT_HEADING_PATTERN.sub(updates, c, count=1)
    else:
        print(
            f"update_readme_summary.py: could not locate '{HEADING}' section in {file_path}, leaving file untouched",
            file=sys.stderr,
        )
        return

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(c_new)


if __name__ == "__main__":
    main()
