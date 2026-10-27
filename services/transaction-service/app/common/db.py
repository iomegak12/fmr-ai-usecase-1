"""ORM-only session access with rollback on cancellation (D-08 and D-20)."""

import logging
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from sqlalchemy import select
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.common.config import Settings

logger = logging.getLogger("kalash.db")


def create_engine(settings: Settings) -> AsyncEngine:
    """Create a lazy async pool without a startup connectivity dependency."""
    return create_async_engine(
        settings.database_url(),
        pool_pre_ping=True,
        pool_timeout=3,
        connect_args={"connect_timeout": 3, "options": "-c statement_timeout=3000"},
        hide_parameters=True,
    )


@asynccontextmanager
async def session_scope(factory: async_sessionmaker[AsyncSession]) -> AsyncGenerator[AsyncSession]:
    """Yield an ORM session; roll back any uncommitted work on every exit path."""
    async with factory() as session:
        try:
            yield session
        finally:
            if session.in_transaction():
                await session.rollback()
                logger.info("transaction_rolled_back")


async def check_database(factory: async_sessionmaker[AsyncSession]) -> None:
    """Check database connectivity through an ORM session, without handwritten SQL."""
    async with session_scope(factory) as session:
        await session.scalar(select(1))
