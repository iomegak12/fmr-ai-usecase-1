"""Profile-based, correlation-aware logging without request bodies or secrets."""

import json
import logging
import os
import sys
from contextvars import ContextVar
from datetime import UTC, datetime
from types import TracebackType

from rich.console import Console
from rich.logging import RichHandler

correlation_id: ContextVar[str] = ContextVar("correlation_id", default="")


class CorrelationFilter(logging.Filter):
    """Attach request context unless an error boundary provided it explicitly."""

    def filter(self, record: logging.LogRecord) -> bool:
        """Add a correlation ID without overwriting an explicit one."""
        if not hasattr(record, "correlationId"):
            record.correlationId = correlation_id.get()
        return True


class JsonFormatter(logging.Formatter):
    """Emit the LLD Section 25 fields as one JSON object per event."""

    def format(self, record: logging.LogRecord) -> str:
        """Serialize safe event fields; do not serialize arbitrary exception data."""
        event = {
            "timestamp": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": "WARN" if record.levelname == "WARNING" else record.levelname,
            "service": "transaction-service",
            "correlationId": getattr(record, "correlationId", ""),
            "message": record.getMessage(),
        }
        for key in (
            "goalId",
            "transactionId",
            "operation",
            "durationMs",
            "status",
            "exceptionType",
            "delta",
            "remoteOutcome",
        ):
            if hasattr(record, key):
                event[key] = getattr(record, key)
        return json.dumps(event, ensure_ascii=True)


class ConsoleFormatter(logging.Formatter):
    """Suppress raw exception text from server-generated tracebacks, as in JSON logs."""

    def formatException(
        self,
        ei: tuple[type[BaseException] | None, BaseException | None, TracebackType | None],
    ) -> str:
        """Report exception identity without serializing sensitive exception details."""
        exception_type = ei[0]
        return f"exceptionType={exception_type.__name__}" if exception_type else ""


def configure_logging(profile: str, level: str) -> None:
    """Configure service and server logging for D-22; suppress unsafe access logs."""
    console = Console(
        file=sys.stdout,
        force_terminal=sys.stdout.isatty() and "NO_COLOR" not in os.environ,
        no_color="NO_COLOR" in os.environ,
    )
    handler: logging.Handler
    if profile == "docker":
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(JsonFormatter())
    else:
        handler = RichHandler(console=console, show_path=False, markup=False, rich_tracebacks=False)
        handler.setFormatter(ConsoleFormatter("%(message)s [%(correlationId)s]"))
    handler.addFilter(CorrelationFilter())
    logger = logging.getLogger("kalash")
    logger.handlers.clear()
    logger.addHandler(handler)
    logger.setLevel(level)
    logger.propagate = False
    for name in ("uvicorn", "uvicorn.error"):
        server_logger = logging.getLogger(name)
        server_logger.handlers.clear()
        server_logger.addHandler(handler)
        server_logger.setLevel(level)
        server_logger.propagate = False
    logging.getLogger("uvicorn.access").disabled = True
