"""Load the service's validated settings and ORM metadata for Alembic migrations."""

import asyncio
import sys

from sqlalchemy import Connection, pool
from sqlalchemy.ext.asyncio import create_async_engine

from alembic import context
from app.common.config import Settings
from app.transactions.models import Base

config = context.config
settings = Settings.model_validate({})


def run_migrations(connection: Connection) -> None:
    """Apply migrations through Alembic's transaction boundary."""
    context.configure(connection=connection, target_metadata=Base.metadata, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()


async def online() -> None:
    """Use the psycopg async driver with no persistent migration connection pool."""
    engine = create_async_engine(
        settings.database_url(), poolclass=pool.NullPool, hide_parameters=True
    )
    try:
        async with engine.connect() as connection:
            await connection.run_sync(run_migrations)
    finally:
        await engine.dispose()


if context.is_offline_mode():
    context.configure(
        url=settings.database_url(), target_metadata=Base.metadata, literal_binds=True
    )
    with context.begin_transaction():
        context.run_migrations()
else:
    loop_factory = asyncio.SelectorEventLoop if sys.platform == "win32" else asyncio.new_event_loop
    with asyncio.Runner(loop_factory=loop_factory) as runner:
        runner.run(online())
