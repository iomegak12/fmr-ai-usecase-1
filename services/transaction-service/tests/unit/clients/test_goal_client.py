import json
from uuid import UUID

import httpx
import pytest

from app.clients.goal_client import GoalClient, GoalUnavailable
from app.common.errors import ErrorCode, GoalProblem
from app.common.logging import correlation_id

GOAL_ID = UUID("10000000-0000-0000-0000-000000000001")
PATH = f"http://goal.test/internal/v1/goals/{GOAL_ID}"
SNAPSHOT = {"goalId": str(GOAL_ID), "status": "ACTIVE", "balance": 20, "targetAmount": 100}


@pytest.fixture
async def goal_client():
    async with httpx.AsyncClient(base_url="http://goal.test", trust_env=False) as client:
        yield GoalClient(client)


async def test_snapshot_adjust_delete_and_forwarded_correlation(goal_client, respx_mock):
    get = respx_mock.get(PATH).respond(200, json=SNAPSHOT)
    post = respx_mock.post(PATH + "/balance-adjustments").respond(200, json=SNAPSHOT)
    delete = respx_mock.delete(PATH).respond(204)
    token = correlation_id.set("upstream-123")
    try:
        assert (await goal_client.snapshot(GOAL_ID)).balance == 20
        assert (await goal_client.adjust(GOAL_ID, "DEPOSIT", 20)).goal_id == GOAL_ID
        await goal_client.delete(GOAL_ID)
    finally:
        correlation_id.reset(token)
    assert json.loads(post.calls.last.request.content) == {"operation": "DEPOSIT", "delta": 20}
    for route in (get, post, delete):
        assert route.call_count == 1
        assert route.calls.last.request.headers["X-Correlation-ID"] == "upstream-123"
        assert set(route.calls.last.request.extensions["timeout"].values()) == {3}


@pytest.mark.parametrize("status", [400, 404, 409, 422, 429])
async def test_every_4xx_is_preserved_verbatim(goal_client, respx_mock, status):
    raw = (
        b'{ "status": '
        + str(status).encode()
        + b', "errorCode":"GOAL-009","custom":{"kept":true} }'
    )
    respx_mock.post(PATH + "/balance-adjustments").respond(
        status,
        content=raw,
        headers={"content-type": "application/problem+json", "retry-after": "8"},
    )
    with pytest.raises(GoalProblem) as caught:
        await goal_client.adjust(GOAL_ID, "DEPOSIT", 1)
    assert caught.value.body == raw
    assert caught.value.status == status
    assert caught.value.retry_after == "8"


@pytest.mark.parametrize(
    ("exception", "code", "uncertain"),
    [
        (httpx.ReadTimeout("secret"), ErrorCode.TXN_003, True),
        (httpx.WriteTimeout("secret"), ErrorCode.TXN_003, True),
        (httpx.ConnectTimeout("secret"), ErrorCode.TXN_003, False),
        (httpx.PoolTimeout("secret"), ErrorCode.TXN_003, False),
        (httpx.ConnectError("secret"), ErrorCode.TXN_002, False),
        (httpx.ReadError("secret"), ErrorCode.TXN_002, True),
        (httpx.RemoteProtocolError("secret"), ErrorCode.TXN_002, True),
    ],
)
async def test_network_errors_map_without_retries(
    goal_client, respx_mock, exception, code, uncertain
):
    route = respx_mock.post(PATH + "/balance-adjustments").mock(side_effect=exception)
    with pytest.raises(GoalUnavailable) as caught:
        await goal_client.adjust(GOAL_ID, "DEPOSIT", 1)
    assert caught.value.code == code
    assert caught.value.uncertain is uncertain
    assert "secret" not in str(caught.value)
    assert route.call_count == 1


@pytest.mark.parametrize("status", [500, 502, 503, 504])
async def test_upstream_5xx_always_maps_to_txn002(goal_client, respx_mock, status):
    route = respx_mock.get(PATH).respond(status, text="private-server-details")
    with pytest.raises(GoalUnavailable) as caught:
        await goal_client.snapshot(GOAL_ID)
    assert caught.value.code == ErrorCode.TXN_002
    assert caught.value.uncertain is False
    assert route.call_count == 1


@pytest.mark.parametrize(
    "body",
    [
        b"not JSON",
        b"{}",
        b'{"goalId":"invalid"}',
        json.dumps(SNAPSHOT | {"balance": "20"}).encode(),
        json.dumps(SNAPSHOT | {"balance": -1}).encode(),
        json.dumps(SNAPSHOT | {"goalId": "20000000-0000-0000-0000-000000000001"}).encode(),
    ],
)
async def test_malformed_success_never_becomes_success(goal_client, respx_mock, body):
    respx_mock.post(PATH + "/balance-adjustments").respond(200, content=body)
    with pytest.raises(GoalUnavailable) as caught:
        await goal_client.adjust(GOAL_ID, "DEPOSIT", 1)
    assert caught.value.code == ErrorCode.TXN_002
    assert caught.value.uncertain is True


@pytest.mark.parametrize("method", ["GET", "DELETE"])
async def test_redirects_and_wrong_success_status_rejected(goal_client, respx_mock, method):
    respx_mock.request(method, PATH).respond(302, headers={"location": "http://elsewhere.test"})
    with pytest.raises(GoalUnavailable):
        if method == "GET":
            await goal_client.snapshot(GOAL_ID)
        else:
            await goal_client.delete(GOAL_ID)
