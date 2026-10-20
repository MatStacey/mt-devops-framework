"""Tests for lib/python/confluence_text.py."""

import sys
from pathlib import Path

sys.path.insert(
    0, str(Path(__file__).resolve().parents[2] / ".bash.d" / "lib" / "python")
)

import confluence_text


def test_headings_and_paragraphs():
    text = confluence_text.convert("<h2>Title</h2><p>Hello <b>world</b></p>")
    assert text == "## Title\n\nHello world\n"


def test_entities_are_decoded():
    assert confluence_text.convert("<p>A &amp; B</p>") == "A & B\n"


def test_list_items_are_on_separate_lines():
    text = confluence_text.convert("<ul><li>a</li><li>b</li></ul>")
    assert text == "- a\n- b\n"


def test_table_cells_are_separated():
    html = "<table><tr><th>H1</th><th>H2</th></tr><tr><td>x</td><td>y</td></tr></table>"
    assert confluence_text.convert(html) == "H1 | H2\nx | y\n"


def test_code_macro_cdata_is_kept():
    html = (
        '<ac:structured-macro ac:name="code"><ac:plain-text-body>'
        "<![CDATA[print(1)]]></ac:plain-text-body></ac:structured-macro>"
    )
    assert "print(1)" in confluence_text.convert(html)


def test_empty_input():
    assert confluence_text.convert("") == "\n"


def test_paragraphs_inside_table_cells_stay_on_one_row():
    html = (
        "<table><tr><th><p>Project</p></th><th><p>Namespace</p></th></tr>"
        "<tr><td><p>a</p></td><td><p>b</p></td></tr></table>"
    )
    assert confluence_text.convert(html) == "Project | Namespace\na | b\n"


def test_macro_parameters_do_not_leak_into_code_blocks():
    html = (
        '<ac:structured-macro ac:name="code">'
        '<ac:parameter ac:name="language">python</ac:parameter>'
        "<ac:plain-text-body><![CDATA[print(1)]]></ac:plain-text-body>"
        "</ac:structured-macro>"
    )
    assert confluence_text.convert(html) == "print(1)\n"


def test_task_status_becomes_a_checkbox():
    html = (
        "<ac:task-list>"
        "<ac:task><ac:task-id>1</ac:task-id><ac:task-status>complete</ac:task-status>"
        "<ac:task-body>done</ac:task-body></ac:task>"
        "<ac:task><ac:task-id>2</ac:task-id><ac:task-status>incomplete</ac:task-status>"
        "<ac:task-body>todo</ac:task-body></ac:task>"
        "</ac:task-list>"
    )
    text = confluence_text.convert(html)
    assert "[x] done" in text
    assert "[ ] todo" in text


def test_consecutive_block_ends_do_not_stack_blank_lines():
    html = "<div><div><div><div><p>a</p></div></div></div></div><p>b</p>"
    assert confluence_text.convert(html) == "a\n\nb\n"


def test_cdata_arriving_as_a_comment_is_kept():
    parser = confluence_text.StorageTextExtractor()
    parser.handle_comment("[CDATA[print(2)]]")
    assert parser.text() == "print(2)\n"
