import asyncio
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from starlette.requests import Request

from app.common.db import check_database, create_engine, session_scope
from app.common.lifecycle import application_lifespan, get_resources


async def test_engine_is_lazy_and_uses_psycopg(settings):
    engine = create_engine(settings)
    assert engine.url.drivername == "postgresql+psycopg"
    assert engine.sync_engine.hide_parameters is True
    await engine.dispose()


async def test_orm_readiness_rolls_back_implicit_transaction(session):
    factory = MagicMock(return_value=session)
    await check_database(factory)
    statement = session.scalar.await_args.args[0]
    assert str(statement).startswith("SELECT")
    session.rollback.assert_awaited_once()
    session.__aexit__.assert_awaited_once()


@pytest.mark.parametrize("failure", [RuntimeError("failed"), asyncio.CancelledError()])
async def test_interrupted_sessions_roll_back_and_close(session, failure):
    factory = MagicMock(return_value=session)
    with pytest.raises(type(failure)):
        async with session_scope(factory):
            raise failure
    session.rollback.assert_awaited_once()
    session.__aexit__.assert_awaited_once()


async def test_already_committed_session_not_rolled_back(session):
    session.in_transaction.return_value = False
    async with session_scope(MagicMock(return_value=session)):
        pass
    session.rollback.assert_not_awaited()


def test_shutdown_closes_both_resources(app, resources):
    engine, _ = resources
    with TestClient(app):
        client = app.state.resources.goal_client
        assert not client.is_closed
    assert client.is_closed
    engine.dispose.assert_awaited_once()


async def test_partial_startup_failure_closes_engine(settings, resources, monkeypatch):
    def broken_client(**kwargs):
        raise RuntimeError("client initialization failed")

    monkeypatch.setattr("app.common.lifecycle.httpx.AsyncClient", broken_client)
    with pytest.raises(RuntimeError, match="initialization failed"):
        async with application_lifespan(settings)(FastAPI()):
            pytest.fail("Startup must fail")
    resources[0].dispose.assert_awaited_once()


def test_resource_accessor_rejects_invalid_state():
    app = FastAPI()
    app.state.resources = object()
    request = Request({"type": "http", "app": app, "headers": []})
    with pytest.raises(RuntimeError, match="not initialized"):
        get_resources(request)
