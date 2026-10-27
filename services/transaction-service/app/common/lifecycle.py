"""Managed runtime resources, with cleanup on shutdown and partial startup failure."""

import logging
from collections.abc import AsyncGenerator, Callable
from contextlib import AbstractAsyncContextManager, AsyncExitStack, asynccontextmanager
from dataclasses import dataclass
from time import perf_counter

import httpx
from fastapi import FastAPI, Request
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.common.banner import startup_banner
from app.common.config import Settings
from app.common.correlation import forward_correlation
from app.common.db import create_engine
from app.common.logging import configure_logging

logger = logging.getLogger("kalash.lifecycle")


@dataclass(frozen=True)
class Resources:
    """Own the shared pool, ORM session factory and outbound HTTP client."""

    engine: AsyncEngine
    sessions: async_sessionmaker[AsyncSession]
    goal_client: httpx.AsyncClient


def get_resources(request: Request) -> Resources:
    """Require completed startup rather than silently constructing another pool."""
    resources = request.app.state.resources
    if not isinstance(resources, Resources):
        raise RuntimeError("Application resources were not initialized")
    return resources


def application_lifespan(
    settings: Settings,
) -> Callable[[FastAPI], AbstractAsyncContextManager[None]]:
    """Build a lifespan context with settings validated by the application factory."""

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncGenerator[None]:
        started = perf_counter()
        configure_logging(settings.app_env, settings.log_level)
        async with AsyncExitStack() as cleanup:
            engine = create_engine(settings)

            async def close_engine() -> None:
                await engine.dispose()
                logger.info("database_pool_closed")

            cleanup.push_async_callback(close_engine)
            client = httpx.AsyncClient(
                base_url=str(settings.goal_service_base_url),
                timeout=settings.goal_service_timeout_seconds,
                event_hooks={"request": [forward_correlation]},
                trust_env=False,
            )

            async def close_client() -> None:
                await client.aclose()
                logger.info("goal_http_client_closed")

            cleanup.push_async_callback(close_client)
            app.state.resources = Resources(
                engine, async_sessionmaker(engine, expire_on_commit=False), client
            )
            startup_banner(settings, perf_counter() - started)
            try:
                yield
            finally:
                logger.info("shutdown_started")
        logger.info("shutdown_complete")

    return lifespan
