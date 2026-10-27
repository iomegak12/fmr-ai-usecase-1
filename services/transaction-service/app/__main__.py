"""Run with immediate Uvicorn shutdown as required by D-20."""

import asyncio
import sys

import uvicorn

from app.common.config import Settings
from app.main import create_app


def main() -> None:
    """Use a selector loop on Windows for psycopg async connections."""
    settings = Settings()
    config = uvicorn.Config(
        create_app(settings),
        host="0.0.0.0" if settings.app_env == "docker" else "127.0.0.1",
        port=settings.txn_service_port,
        log_config=None,
        access_log=False,
        proxy_headers=False,
        timeout_graceful_shutdown=0,
    )
    loop_factory = asyncio.SelectorEventLoop if sys.platform == "win32" else asyncio.new_event_loop
    with asyncio.Runner(loop_factory=loop_factory) as runner:
        runner.run(uvicorn.Server(config).serve())


if __name__ == "__main__":
    main()
