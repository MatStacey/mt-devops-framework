#!/usr/bin/env python3
"""
Confluence storage-format to plain-text converter for the MT DevOps Framework.

Reads Confluence storage-format XHTML on stdin and prints readable plain
text: headings, paragraphs, list items, table rows and code blocks keep
their line structure, and macro bodies (ac:* / ri:* elements) contribute
their text content. Backs conf-get (20-vcs/62-confluence.sh).

Usage:
    confluence_text.py < storage.html

Outputs:
    Plain text on stdout.

Returns:
    Exit code 0 always for parseable input.
"""

import sys
from html.parser import HTMLParser

LINE_TAGS = frozenset({"br", "tr", "li", "ul", "ol", "table"})
PARAGRAPH_TAGS = frozenset(
    {"p", "div", "pre", "blockquote"} | {f"h{level}" for level in range(1, 7)}
)
HEADING_PREFIX = {f"h{level}": "#" * level + " " for level in range(1, 7)}
CELL_TAGS = frozenset({"td", "th"})
CELL_SEPARATOR = " | "
LIST_BULLET = "- "


class StorageTextExtractor(HTMLParser):
    """Collect text from storage-format HTML, preserving block structure."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.cells_in_row = 0

    def _ensure_breaks(self, count: int) -> None:
        """End the current line and leave `count` newlines in total at the tail."""
        tail = "".join(self.parts[-3:])
        trailing = len(tail) - len(tail.rstrip("\n"))
        if self.parts:
            self.parts.append("\n" * max(0, count - trailing))

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in PARAGRAPH_TAGS:
            self._ensure_breaks(2)
        elif tag in LINE_TAGS:
            self._ensure_breaks(1)
        if tag in HEADING_PREFIX:
            self.parts.append(HEADING_PREFIX[tag])
        elif tag == "li":
            self.parts.append(LIST_BULLET)
        elif tag == "tr":
            self.cells_in_row = 0
        elif tag in CELL_TAGS:
            if self.cells_in_row:
                self.parts.append(CELL_SEPARATOR)
            self.cells_in_row += 1

    def handle_endtag(self, tag: str) -> None:
        if tag in PARAGRAPH_TAGS:
            self._ensure_breaks(2)
        elif tag in LINE_TAGS:
            self._ensure_breaks(1)

    def handle_data(self, data: str) -> None:
        self.parts.append(data)

    def unknown_decl(self, data: str) -> None:
        """Keep the content of CDATA sections (code macro bodies)."""
        if data.startswith("CDATA["):
            self.parts.append(data[len("CDATA[") :])

    def text(self) -> str:
        """Return the extracted text with trailing whitespace trimmed per line."""
        lines = [line.rstrip() for line in "".join(self.parts).splitlines()]
        return "\n".join(lines).strip() + "\n"


def convert(storage_html: str) -> str:
    """Convert storage-format HTML to plain text."""
    extractor = StorageTextExtractor()
    extractor.feed(storage_html)
    extractor.close()
    return extractor.text()


def main() -> int:
    """Read stdin, write the converted text to stdout."""
    sys.stdout.write(convert(sys.stdin.read()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
