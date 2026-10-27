from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from app.common.clock import FixedClock
from app.common.config import Settings
from app.main import create_app


@pytest.fixture
def settings():
    return Settings(_env_file=None, txn_db_password="unit-test-only", app_env="test")


@pytest.fixture
def clock():
    return FixedClock(datetime(2026, 10, 27, 20, 0, tzinfo=UTC), ZoneInfo("Asia/Kolkata"))


@pytest.fixture
def session():
    value = AsyncMock(spec=AsyncSession)
    value.in_transaction = MagicMock(return_value=True)
    value.__aenter__.return_value = value
    return value


@pytest.fixture
def resources(monkeypatch, session):
    engine = MagicMock(spec=AsyncEngine)
    engine.dispose = AsyncMock()
    factory = MagicMock(return_value=session)
    monkeypatch.setattr("app.common.lifecycle.create_engine", lambda settings: engine)
    monkeypatch.setattr("app.common.lifecycle.async_sessionmaker", lambda *a, **kw: factory)
    return engine, factory


@pytest.fixture
def app(settings, clock, resources):
    return create_app(settings, clock)


@pytest.fixture
def client(app):
    with TestClient(app, raise_server_exceptions=False) as value:
        yield value
