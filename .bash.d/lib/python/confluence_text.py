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
SUPPRESSED_TAGS = frozenset({"ac:parameter", "ac:task-id", "ac:task-status"})
TASK_STATUS_TAG = "ac:task-status"
TASK_DONE = "complete"
CHECKBOX_DONE = "[x] "
CHECKBOX_OPEN = "[ ] "
CDATA_OPEN = "[CDATA["
CDATA_CLOSE = "]]"
CELL_SEPARATOR = " | "
LIST_BULLET = "- "


class StorageTextExtractor(HTMLParser):
    """Collect text from storage-format HTML, preserving block structure."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.cells_in_row = 0
        self.cell_depth = 0
        self.suppress_depth = 0
        self.task_status = ""
        self.in_task_status = False
        self.trailing_newlines = 0

    def _emit(self, text: str) -> None:
        """Append text and track how many newlines the output now ends with."""
        if not text:
            return
        self.parts.append(text)
        stripped = text.rstrip("\n")
        if stripped:
            self.trailing_newlines = len(text) - len(stripped)
        else:
            self.trailing_newlines += len(text)

    def _ensure_breaks(self, count: int) -> None:
        """End the current line and leave `count` newlines in total at the tail."""
        if self.parts:
            self._emit("\n" * max(0, count - self.trailing_newlines))

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in SUPPRESSED_TAGS:
            self.suppress_depth += 1
            if tag == TASK_STATUS_TAG:
                self.task_status = ""
                self.in_task_status = True
            return
        if tag in PARAGRAPH_TAGS:
            if not self.cell_depth:
                self._ensure_breaks(2)
        elif tag in LINE_TAGS:
            self._ensure_breaks(1)
        if tag in HEADING_PREFIX:
            self._emit(HEADING_PREFIX[tag])
        elif tag == "li":
            self._emit(LIST_BULLET)
        elif tag == "tr":
            self.cells_in_row = 0
        elif tag in CELL_TAGS:
            if self.cells_in_row:
                self._emit(CELL_SEPARATOR)
            self.cells_in_row += 1
            self.cell_depth += 1

    def handle_endtag(self, tag: str) -> None:
        if tag in SUPPRESSED_TAGS:
            self.suppress_depth = max(0, self.suppress_depth - 1)
            if tag == TASK_STATUS_TAG:
                self.in_task_status = False
                done = self.task_status.strip() == TASK_DONE
                self._emit(CHECKBOX_DONE if done else CHECKBOX_OPEN)
            return
        if tag in CELL_TAGS:
            self.cell_depth = max(0, self.cell_depth - 1)
        elif tag in PARAGRAPH_TAGS:
            if not self.cell_depth:
                self._ensure_breaks(2)
        elif tag in LINE_TAGS:
            self._ensure_breaks(1)

    def handle_data(self, data: str) -> None:
        if self.suppress_depth:
            if self.in_task_status:
                self.task_status += data
            return
        self._emit(data)

    def unknown_decl(self, data: str) -> None:
        """Keep the content of CDATA sections (code macro bodies)."""
        if data.startswith("CDATA["):
            self._emit(data[len("CDATA[") :])

    def handle_comment(self, data: str) -> None:
        """Newer CPython parses CDATA outside foreign content as a bogus comment."""
        if data.startswith(CDATA_OPEN) and data.endswith(CDATA_CLOSE):
            self._emit(data[len(CDATA_OPEN) : -len(CDATA_CLOSE)])

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
