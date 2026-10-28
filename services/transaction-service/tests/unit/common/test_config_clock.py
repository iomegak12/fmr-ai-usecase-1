from datetime import UTC, date, datetime
from zoneinfo import ZoneInfo

import pytest
from pydantic import ValidationError

from app.common.clock import FixedClock, SystemClock
from app.common.config import Settings


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("txn_db_password", ""),
        ("txn_db_password", "   "),
        ("txn_service_port", 0),
        ("txn_db_port", 65536),
        ("app_env", "production"),
        ("app_timezone", "Not/AZone"),
        ("log_level", "typo"),
        ("goal_service_timeout_seconds", 0),
        ("goal_service_timeout_seconds", float("inf")),
        ("goal_service_base_url", "http://user:secret@localhost"),
        ("goal_service_base_url", "http://localhost?token=secret"),
        ("goal_service_base_url", "http://localhost#token"),
        ("app_root_path", "/arbitrary"),
    ],
)
def test_invalid_settings_fail(field, value):
    values = {"txn_db_password": "unit-test-only", field: value}
    with pytest.raises(ValidationError):
        Settings(_env_file=None, **values)


def test_password_is_required(monkeypatch):
    monkeypatch.delenv("TXN_DB_PASSWORD", raising=False)
    with pytest.raises(ValidationError):
        Settings(_env_file=None)


def test_validated_factory_loads_environment_and_rejects_blank_password(monkeypatch):
    monkeypatch.setenv("TXN_DB_PASSWORD", "unit-test-only")
    assert Settings.model_validate({}).txn_db_password.get_secret_value() == "unit-test-only"
    monkeypatch.setenv("TXN_DB_PASSWORD", "")
    with pytest.raises(ValidationError):
        Settings.model_validate({})


def test_environment_overrides_dotenv(tmp_path, monkeypatch):
    dotenv = tmp_path / ".env"
    dotenv.write_text("TXN_DB_PASSWORD=unit-test-only\nTXN_DB_PORT=5433\nUNRELATED=ignored\n")
    monkeypatch.setenv("TXN_DB_PORT", "15433")
    result = Settings(_env_file=dotenv)
    assert result.txn_db_port == 15433
    assert result.app_timezone == "Asia/Kolkata"
    assert result.app_root_path == ""


def test_url_encodes_password_and_repr_hides_it():
    password = "unit-only:@/escaped"
    settings = Settings(_env_file=None, txn_db_password=password)
    url = settings.database_url()
    assert url.drivername == "postgresql+psycopg"
    assert url.password == password
    assert password not in str(url)
    assert password not in repr(settings)


def test_fixed_clock_handles_ist_day_boundary(clock):
    assert clock.today() == date(2026, 10, 28)
    assert clock.now() == datetime(2026, 10, 27, 20, tzinfo=UTC)


def test_fixed_clock_rejects_naive_time():
    with pytest.raises(ValueError, match="timezone-aware"):
        FixedClock(datetime(2026, 1, 1), ZoneInfo("Asia/Kolkata"))


def test_system_clock_uses_injected_timezone(monkeypatch):
    instant = datetime(2026, 10, 27, 20, tzinfo=UTC)
    monkeypatch.setattr(SystemClock, "now", lambda self: instant)
    assert SystemClock(ZoneInfo("Asia/Kolkata")).today() == date(2026, 10, 28)


def test_system_clock_returns_utc():
    assert SystemClock(ZoneInfo("Asia/Kolkata")).now().tzinfo is UTC
