"""Safe, TTY-aware startup summaries required by implementation-plan Section 7.4."""

import logging
import os
import platform
import sys

from rich.console import Console

from app import __version__
from app.common.config import Settings

logger = logging.getLogger("kalash.lifecycle")


def startup_banner(settings: Settings, duration: float) -> None:
    """Show identity, endpoints and nonsecret settings; keep Docker output JSON."""
    base = f"http://localhost:{settings.txn_service_port}"
    summary = (
        f"transaction-service {__version__} | profile={settings.app_env} | "
        f"Python={platform.python_version()} | PID={os.getpid()}\n"
        f"port={settings.txn_service_port} | API={base}/api/v1/transactions\n"
        f"Swagger={base}/docs | OpenAPI={base}/openapi.json\n"
        f"health={base}/health | ready={base}/ready | metrics={base}/metrics\n"
        f"database={settings.txn_db_host}:{settings.txn_db_port}/{settings.txn_db_name}\n"
        f"Goal Service={settings.goal_service_base_url}\n"
        f"timezone={settings.app_timezone} | logLevel={settings.log_level} | "
        f"startupSeconds={duration:.3f}"
    )
    if settings.app_env == "docker":
        logger.info("startup %s", summary.replace("\n", " | "))
    else:
        Console(
            file=sys.stdout,
            force_terminal=sys.stdout.isatty() and "NO_COLOR" not in os.environ,
            no_color="NO_COLOR" in os.environ,
        ).print(summary, style="bold cyan", markup=False, highlight=False)
