import asyncio
from uuid import UUID

import httpx
import pytest
from fastapi import Query
from fastapi.testclient import TestClient
from pydantic import BaseModel, StrictInt

from app.common.correlation import CorrelationMiddleware, forward_correlation
from app.common.errors import ApiError, ErrorCode, ValidationError
from app.common.logging import correlation_id


@pytest.mark.parametrize("code", list(ErrorCode))
def test_every_error_code_has_problem_details(app, clock, code):
    @app.get("/test-error")
    async def fail():
        raise ApiError(code)

    with TestClient(app) as client:
        response = client.get("/test-error", headers={"X-Correlation-ID": "test-request-123"})
    body = response.json()
    assert response.status_code == code.status
    assert response.headers["content-type"] == "application/problem+json"
    assert response.headers["x-correlation-id"] == "test-request-123"
    assert body == {
        "type": f"urn:kalash:error:{code.code}",
        "title": code.title,
        "status": code.status,
        "detail": code.title,
        "instance": "/test-error",
        "errorCode": code.code,
        "correlationId": "test-request-123",
        "timestamp": clock.now().isoformat().replace("+00:00", "Z"),
    }


def test_validation_errors_are_400_and_do_not_echo_values(app):
    class Payload(BaseModel):
        amount: StrictInt

    @app.post("/validate")
    async def validate(body: Payload, page: int = Query(ge=0)):
        return {"amount": body.amount}

    with TestClient(app) as client:
        response = client.post("/validate?page=-1", json={"amount": "do-not-echo"})
    body = response.json()
    assert response.status_code == 400
    assert body["errorCode"] == "COMMON-400"
    assert {field["field"] for field in body["errors"]} == {"amount", "query.page"}
    assert "do-not-echo" not in response.text


def test_application_validation_has_errors(app):
    @app.get("/validate")
    async def validate():
        raise ValidationError([{"field": "name", "message": "Required"}])

    with TestClient(app) as client:
        response = client.get("/validate")
    assert response.json()["errors"] == [{"field": "name", "message": "Required"}]


def test_unhandled_error_is_safe_and_correlated(app):
    @app.get("/unexpected")
    async def unexpected():
        raise RuntimeError("database-password-must-not-leak")

    with TestClient(app, raise_server_exceptions=False) as client:
        response = client.get("/unexpected", headers={"X-Correlation-ID": "failure-123"})
    assert response.status_code == 500
    assert response.json()["errorCode"] == "COMMON-500"
    assert response.json()["correlationId"] == "failure-123"
    assert response.headers["x-correlation-id"] == "failure-123"
    assert "database-password" not in response.text
    assert correlation_id.get() == ""


def test_routing_errors_preserve_http_status(client):
    missing = client.get("/does-not-exist")
    method = client.post("/health")
    assert missing.status_code == 404
    assert missing.json()["type"] == "about:blank"
    assert method.status_code == 405
    assert "GET" in method.headers["allow"]


@pytest.mark.parametrize("incoming", ["", "bad id", "x" * 129])
def test_missing_or_invalid_correlation_replaced(client, incoming):
    response = client.get("/health", headers={"X-Correlation-ID": incoming})
    assert UUID(response.headers["x-correlation-id"])
    assert correlation_id.get() == ""


async def test_outbound_http_hook_propagates_context(respx_mock):
    route = respx_mock.get("http://goal.test/internal").respond(200)
    token = correlation_id.set("outbound-123")
    try:
        async with httpx.AsyncClient(
            event_hooks={"request": [forward_correlation]}, trust_env=False
        ) as client:
            await client.get("http://goal.test/internal")
    finally:
        correlation_id.reset(token)
    assert route.calls.last.request.headers["X-Correlation-ID"] == "outbound-123"
    request = httpx.Request("GET", "http://goal.test/")
    await forward_correlation(request)
    assert "X-Correlation-ID" not in request.headers


async def test_concurrent_contexts_are_isolated():
    async def worker(identifier):
        token = correlation_id.set(identifier)
        try:
            await asyncio.sleep(0)
            request = httpx.Request("GET", "http://goal.test/")
            await forward_correlation(request)
            return request.headers["X-Correlation-ID"]
        finally:
            correlation_id.reset(token)

    assert await asyncio.gather(worker("first"), worker("second")) == ["first", "second"]
    assert correlation_id.get() == ""


async def test_non_http_scope_is_forwarded():
    calls = []

    async def wrapped(scope, receive, send):
        calls.append(scope["type"])

    async def receive():
        return {"type": "lifespan.startup"}

    async def send(message):
        pass

    await CorrelationMiddleware(wrapped)({"type": "lifespan"}, receive, send)
    assert calls == ["lifespan"]
