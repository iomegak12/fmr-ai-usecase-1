import json
import logging
import sys

from app.common.banner import startup_banner
from app.common.logging import (
    ConsoleFormatter,
    CorrelationFilter,
    JsonFormatter,
    configure_logging,
    correlation_id,
)


def test_json_logging_fields_and_no_exception_contents():
    record = logging.LogRecord("kalash", logging.WARNING, "", 0, "event", (), None)
    record.durationMs = 12.3
    record.status = 503
    record.exceptionType = "OperationalError"
    token = correlation_id.set("log-123")
    try:
        CorrelationFilter().filter(record)
    finally:
        correlation_id.reset(token)
    value = json.loads(JsonFormatter().format(record))
    assert value["correlationId"] == "log-123"
    assert value["service"] == "transaction-service"
    assert value["level"] == "WARN"
    assert value["durationMs"] == 12.3
    assert value["exceptionType"] == "OperationalError"
    assert value["timestamp"].endswith("+00:00")


def test_explicit_error_correlation_is_preserved():
    record = logging.makeLogRecord({"correlationId": "explicit"})
    CorrelationFilter().filter(record)
    assert record.correlationId == "explicit"


def test_docker_logs_and_banner_are_json_without_secrets(settings, capsys):
    settings = settings.model_copy(update={"app_env": "docker"})
    configure_logging("docker", "INFO")
    startup_banner(settings, 0.25)
    output = capsys.readouterr().out
    value = json.loads(output)
    assert value["message"].startswith("startup transaction-service")
    assert "\x1b" not in output
    assert settings.txn_db_password.get_secret_value() not in output
    assert "Goal Service=" in value["message"]
    assert "metrics=" in value["message"]


def test_no_color_plain_banner_lists_required_fields(settings, monkeypatch, capsys):
    monkeypatch.setenv("NO_COLOR", "1")
    configure_logging("local", "INFO")
    startup_banner(settings, 0.25)
    output = capsys.readouterr().out
    for expected in (
        "transaction-service",
        "Python=",
        "PID=",
        "Swagger=",
        "database=",
        "timezone=",
    ):
        assert expected in output
    assert "\x1b" not in output
    assert settings.txn_db_password.get_secret_value() not in output


def test_non_tty_banner_has_no_color(settings, capsys):
    startup_banner(settings, 0.25)
    assert "\x1b" not in capsys.readouterr().out


def test_tty_banner_uses_color(settings, monkeypatch, capsys):
    monkeypatch.delenv("NO_COLOR", raising=False)
    monkeypatch.setattr(sys.stdout, "isatty", lambda: True)
    startup_banner(settings, 0.25)
    assert "\x1b" in capsys.readouterr().out


def test_server_exception_text_is_not_logged():
    try:
        raise RuntimeError("must-not-appear-in-logs")
    except RuntimeError:
        record = logging.LogRecord(
            "uvicorn.error", logging.ERROR, "", 0, "failure", (), sys.exc_info()
        )
    output = ConsoleFormatter().format(record)
    assert "RuntimeError" in output
    assert "must-not-appear" not in output
