"""Tests for lib/python/html_check.py's tag-balance and anchor checks."""

import html_check


def messages(text):
    return [message for _, message in html_check.check_html(text)]


def test_balanced_document_with_valid_anchor_has_no_problems():
    text = '<html><body><a href="#top">x</a><h1 id="top">T</h1><br><img src="a"></body></html>'
    assert html_check.check_html(text) == []


def test_unclosed_tag_is_reported_with_its_line():
    problems = html_check.check_html("<div>\n<p>text\n</div>")
    assert problems == [(2, "<p> is never closed (still open at </div>)")]


def test_tag_left_open_at_end_of_file_is_reported():
    assert messages("<div><span>x</span>") == ["<div> is never closed"]


def test_stray_closing_tag_is_reported():
    assert messages("<p>x</p></div>") == ["unexpected closing tag </div>"]


def test_broken_internal_anchor_is_reported():
    assert messages('<a href="#missing">x</a>') == ['broken anchor link "#missing"']


def test_name_attribute_satisfies_anchor():
    assert html_check.check_html('<a name="sec"></a><a href="#sec">x</a>') == []


def test_bare_hash_and_external_links_are_ignored():
    assert (
        html_check.check_html('<a href="#">x</a><a href="http://e.com/#y">z</a>') == []
    )


def test_self_closing_non_void_tag_is_not_left_open():
    assert html_check.check_html("<div><svg/></div>") == []


def test_main_returns_exit_codes(tmp_path, capsys):
    good = tmp_path / "good.html"
    good.write_text("<p>ok</p>")
    bad = tmp_path / "bad.html"
    bad.write_text("<p>oops")
    assert html_check.main(["html_check.py", str(good)]) == 0
    assert html_check.main(["html_check.py", str(bad)]) == 1
    assert "bad.html:1: <p> is never closed" in capsys.readouterr().out
    assert html_check.main(["html_check.py", str(tmp_path / "nope.html")]) == 2
