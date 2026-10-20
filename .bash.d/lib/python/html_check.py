#!/usr/bin/env python3
"""
HTML structure checker for the MT DevOps Framework.

Validates a local HTML file for unbalanced tags and broken internal
anchors (href="#id" links with no matching id/name attribute). Backs the
mt-html-check command (02-utilities/38-html-check.sh).

Usage:
    html_check.py <file.html>

Outputs:
    One problem per line on stdout, prefixed with the source line number.

Returns:
    Exit code 0 if no problems were found, 1 if any were found, 2 if the
    file could not be read.
"""

import sys
from html.parser import HTMLParser

VOID_ELEMENTS = frozenset(
    {
        "area",
        "base",
        "br",
        "col",
        "embed",
        "hr",
        "img",
        "input",
        "link",
        "meta",
        "param",
        "source",
        "track",
        "wbr",
    }
)
EXIT_OK = 0
EXIT_PROBLEMS = 1
EXIT_UNREADABLE = 2


class StructureChecker(HTMLParser):
    """Collect tag-balance problems, defined anchor ids and internal links."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.open_tags = []
        self.problems = []
        self.anchor_ids = set()
        self.internal_links = []

    def handle_starttag(self, tag, attrs):
        """Track the open tag, its id/name anchor and any #fragment href."""
        line = self.getpos()[0]
        attributes = dict(attrs)
        for anchor_attr in ("id", "name"):
            if attributes.get(anchor_attr):
                self.anchor_ids.add(attributes[anchor_attr])
        href = attributes.get("href") or ""
        if href.startswith("#") and len(href) > 1:
            self.internal_links.append((line, href[1:]))
        if tag not in VOID_ELEMENTS:
            self.open_tags.append((tag, line))

    def handle_startendtag(self, tag, attrs):
        """Record anchors/links on self-closing tags without tracking them as open."""
        self.handle_starttag(tag, attrs)
        if tag not in VOID_ELEMENTS:
            self.open_tags.pop()

    def handle_endtag(self, tag):
        """Match a closing tag against the open stack, reporting mismatches."""
        line = self.getpos()[0]
        if tag in VOID_ELEMENTS:
            return
        open_names = [name for name, _ in self.open_tags]
        if tag not in open_names:
            self.problems.append((line, f"unexpected closing tag </{tag}>"))
            return
        while self.open_tags:
            name, open_line = self.open_tags.pop()
            if name == tag:
                return
            self.problems.append(
                (open_line, f"<{name}> is never closed (still open at </{tag}>)")
            )

    def finish(self):
        """Report tags left open and internal links with no matching anchor."""
        self.close()
        for name, open_line in self.open_tags:
            self.problems.append((open_line, f"<{name}> is never closed"))
        for line, fragment in self.internal_links:
            if fragment not in self.anchor_ids:
                self.problems.append((line, f'broken anchor link "#{fragment}"'))
        return sorted(self.problems)


def check_html(text):
    """Return a sorted list of (line, message) problems found in HTML text."""
    checker = StructureChecker()
    checker.feed(text)
    return checker.finish()


def main(argv):
    """Check the file named in argv[1] and print each problem found."""
    if len(argv) != 2:
        print("Usage: html_check.py <file.html>", file=sys.stderr)
        return EXIT_UNREADABLE
    try:
        with open(argv[1], encoding="utf-8") as html_file:
            text = html_file.read()
    except OSError as error:
        print(f"html_check.py: cannot read {argv[1]}: {error}", file=sys.stderr)
        return EXIT_UNREADABLE
    problems = check_html(text)
    for line, message in problems:
        print(f"{argv[1]}:{line}: {message}")
    return EXIT_PROBLEMS if problems else EXIT_OK


if __name__ == "__main__":
    sys.exit(main(sys.argv))
