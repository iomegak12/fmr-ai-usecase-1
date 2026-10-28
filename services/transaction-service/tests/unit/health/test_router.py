from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app.main import create_app


def test_health_does_not_access_database(client, session):
    response = client.get("/health", headers={"Origin": "https://example.test"})
    assert response.status_code == 200
    assert response.json() == {"status": "UP"}
    assert "access-control-allow-origin" not in response.headers
    session.scalar.assert_not_awaited()


def test_ready_checks_database_only(client, session):
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "UP"}
    session.scalar.assert_awaited_once()


@pytest.mark.parametrize(
    "error",
    [OperationalError("hidden", {}, Exception("sensitive")), OSError("down"), TimeoutError()],
)
def test_database_outage_not_liveness_failure(client, monkeypatch, error):
    monkeypatch.setattr("app.health.router.check_database", AsyncMock(side_effect=error))
    response = client.get("/ready")
    assert response.status_code == 503
    assert response.json() == {"status": "DOWN"}
    assert "sensitive" not in response.text
    assert client.get("/health").status_code == 200


def test_direct_docs_openapi_metrics_and_no_cors(client):
    for endpoint in ("/docs", "/openapi.json", "/metrics"):
        response = client.get(endpoint, headers={"Origin": "https://example.test"})
        assert response.status_code == 200
        assert not any(header.startswith("access-control-") for header in response.headers)
    schema = client.get("/openapi.json").json()
    assert schema["servers"][0]["url"] == "/"
    assert {"/health", "/ready"} <= schema["paths"].keys()
    assert "503" in schema["paths"]["/ready"]["get"]["responses"]
    assert "/api/v1/transactions" in schema["paths"]
    assert "/openapi.json" in client.get("/docs").text
    assert "http_requests_total" in client.get("/metrics").text


def test_cors_preflight_not_enabled(client):
    response = client.options(
        "/health",
        headers={"Origin": "https://example.test", "Access-Control-Request-Method": "GET"},
    )
    assert response.status_code == 405
    assert not any(header.startswith("access-control-") for header in response.headers)


def test_proxy_prefix_keeps_api_server_at_origin(settings, resources):
    settings = settings.model_copy(update={"app_root_path": "/docs/transactions"})
    with TestClient(create_app(settings), root_path="/docs/transactions") as client:
        assert "/docs/transactions/openapi.json" in client.get("/docs").text
        assert client.get("/openapi.json").json()["servers"][0]["url"] == "/"
