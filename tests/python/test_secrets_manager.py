"""Tests for lib/python/secrets_manager.py's pure status/config-check logic."""

from datetime import datetime, timedelta, timezone

import secrets_manager


def _date_str(days_from_today):
    return (
        datetime.now(timezone.utc).date() + timedelta(days=days_from_today)
    ).isoformat()


def test_expiry_status_empty_string_is_none():
    assert secrets_manager._expiry_status("") == ("none", None)


def test_expiry_status_unparseable_string_is_none():
    status, days = secrets_manager._expiry_status("not-a-date")
    assert status == "none"
    assert days is None


def test_expiry_status_past_date_is_expired():
    status, days = secrets_manager._expiry_status(_date_str(-5))
    assert status == "expired"
    assert days < 0


def test_expiry_status_within_warning_window_is_expiring():
    status, days = secrets_manager._expiry_status(_date_str(10))
    assert status == "expiring"
    assert days == 10


def test_expiry_status_boundary_day_counts_as_expiring():
    status, _ = secrets_manager._expiry_status(
        _date_str(secrets_manager.EXPIRY_WARNING_DAYS)
    )
    assert status == "expiring"


def test_expiry_status_just_past_warning_window_is_ok():
    status, _ = secrets_manager._expiry_status(
        _date_str(secrets_manager.EXPIRY_WARNING_DAYS + 1)
    )
    assert status == "ok"


def test_is_configured_false_when_secrets_file_missing(tmp_path, monkeypatch):
    monkeypatch.setattr(secrets_manager, "SECRETS_FILE", str(tmp_path / "secrets.sh"))
    assert secrets_manager._is_configured("GEMINI_API_KEY") is False


def test_is_configured_true_when_export_line_present(tmp_path, monkeypatch):
    secrets_file = tmp_path / "secrets.sh"
    secrets_file.write_text('export GEMINI_API_KEY="abc123"\n')
    monkeypatch.setattr(secrets_manager, "SECRETS_FILE", str(secrets_file))

    assert secrets_manager._is_configured("GEMINI_API_KEY") is True
    assert secrets_manager._is_configured("CLAUDE_API_KEY") is False
