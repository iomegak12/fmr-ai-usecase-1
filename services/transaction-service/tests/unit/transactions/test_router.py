import json
from datetime import UTC, date, datetime
from unittest.mock import MagicMock
from uuid import UUID

import httpx
import pytest
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm.exc import StaleDataError

from app.transactions.models import Transaction, TransactionType

GOAL_ID = UUID("10000000-0000-0000-0000-000000000001")
TXN_ID = UUID("20000000-0000-0000-0000-000000000001")
PATH = "/api/v1/transactions"
REMOTE = f"http://localhost:8080/internal/v1/goals/{GOAL_ID}"


@pytest.fixture
def stored(session):
    record = Transaction(
        transaction_id=TXN_ID,
        goal_id=GOAL_ID,
        type=TransactionType.DEPOSIT,
        amount=10,
        version=1,
        transaction_date=date(2026, 10, 1),
        created_at=datetime(2026, 10, 1, tzinfo=UTC),
        updated_at=datetime(2026, 10, 1, tzinfo=UTC),
    )
    session.get.return_value = record
    return record


@pytest.fixture
def adjustment(respx_mock):
    return respx_mock.post(REMOTE + "/balance-adjustments").respond(
        200, json={"goalId": str(GOAL_ID), "status": "ACTIVE", "balance": 20, "targetAmount": 100}
    )


def test_create_real_wiring_and_correlated_goal_call(client, session, adjustment):
    response = client.post(
        PATH,
        json={"goalId": str(GOAL_ID), "type": "DEPOSIT", "amount": 20},
        headers={"X-Correlation-ID": "txn-create-123", "Origin": "https://example.test"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["goalId"] == str(GOAL_ID)
    assert body["amount"] == 20
    assert body["transactionDate"] == "2026-10-28"
    assert body["goalBalance"] == 20
    assert body["goalStatus"] == "ACTIVE"
    assert "version" not in body
    assert UUID(body["transactionId"])
    assert response.headers["Location"] == f"{PATH}/{body['transactionId']}"
    assert response.headers["X-Correlation-ID"] == "txn-create-123"
    assert "access-control-allow-origin" not in response.headers
    assert adjustment.calls.last.request.headers["X-Correlation-ID"] == "txn-create-123"
    assert json.loads(adjustment.calls.last.request.content)["delta"] == 20
    session.commit.assert_awaited_once()


def test_edit_and_delete_have_expected_shapes(client, stored, adjustment):
    changed = client.patch(f"{PATH}/{TXN_ID}", json={"amount": 30})
    assert changed.status_code == 200
    assert changed.json()["transactionDate"] == "2026-10-01"
    assert changed.json()["createdAt"] == "2026-10-01T00:00:00Z"
    assert changed.json()["amount"] == 30
    assert json.loads(adjustment.calls.last.request.content)["delta"] == 20
    deleted = client.delete(f"{PATH}/{TXN_ID}")
    assert deleted.status_code == 204 and deleted.content == b""
    assert json.loads(adjustment.calls.last.request.content)["delta"] == -30


def test_history_envelope_filters_by_goal(client, stored, session):
    session.scalar.return_value = 1
    session.scalars.return_value = MagicMock(all=MagicMock(return_value=[stored]))
    response = client.get(PATH, params={"goalId": str(GOAL_ID)})
    assert response.status_code == 200
    body = response.json()
    assert (body["page"], body["size"], body["totalElements"], body["totalPages"]) == (0, 20, 1, 1)
    assert "goalBalance" not in body["content"][0]


def test_cancelled_goal_deletion_wiring(client, session, respx_mock):
    respx_mock.get(REMOTE).respond(
        200, json={"goalId": str(GOAL_ID), "status": "CANCELLED", "balance": 0, "targetAmount": 100}
    )
    deleted = respx_mock.delete(REMOTE).respond(204)
    session.scalars.return_value = MagicMock(all=MagicMock(return_value=[]))
    response = client.delete(f"{PATH}/goals/{GOAL_ID}")
    assert response.status_code == 204 and response.content == b""
    session.commit.assert_awaited_once()
    assert deleted.call_count == 1


@pytest.mark.parametrize("amount", [0, -1, "1", 1.0, True, None, 2**63])
def test_amount_validation_is_400_not_fastapi422(client, session, amount):
    response = client.post(PATH, json={"goalId": str(GOAL_ID), "type": "DEPOSIT", "amount": amount})
    assert response.status_code == 400
    assert response.json()["errorCode"] == "COMMON-400"
    assert response.json()["errors"][0]["field"] == "amount"
    session.add.assert_not_called()


@pytest.mark.parametrize(
    ("body", "field"),
    [
        ({"goalId": str(GOAL_ID), "type": "deposit", "amount": 1}, "type"),
        ({"goalId": str(GOAL_ID), "type": "TRANSFER", "amount": 1}, "type"),
        ({"goalId": str(GOAL_ID), "type": None, "amount": 1}, "type"),
        ({"goalId": str(GOAL_ID), "amount": 1}, "type"),
        ({"type": "DEPOSIT", "amount": 1}, "goalId"),
        ({"goalId": "not-a-uuid", "type": "DEPOSIT", "amount": 1}, "goalId"),
    ],
)
def test_type_and_goal_validation_never_reach_goal_service(
    client, session, respx_mock, body, field
):
    response = client.post(PATH, json=body)
    assert response.status_code == 400
    assert response.headers["content-type"] == "application/problem+json"
    assert response.json()["errorCode"] == "COMMON-400"
    assert [error["field"] for error in response.json()["errors"]] == [field]
    session.add.assert_not_called()
    assert not respx_mock.calls


@pytest.mark.parametrize(
    "query",
    [
        "",
        "?goalId=bad",
        f"?goalId={GOAL_ID}&page=-1",
        f"?goalId={GOAL_ID}&size=0",
        f"?goalId={GOAL_ID}&size=101",
    ],
)
def test_history_query_validation(client, query):
    assert client.get(PATH + query).status_code == 400


def test_immutable_patch_fields_uuid_and_empty_body_validation(client):
    for body in ({}, {"amount": None}, {"amount": 2, "transactionDate": "2027-01-01"}):
        assert client.patch(f"{PATH}/{TXN_ID}", json=body).status_code == 400
    assert client.delete(f"{PATH}/bad-uuid").status_code == 400


def test_missing_transaction_returns_txn001(client, session):
    session.get.return_value = None
    response = client.delete(f"{PATH}/{TXN_ID}")
    assert response.status_code == 404
    assert response.json()["errorCode"] == "TXN-001"


def test_upstream_problem_is_byte_for_byte_unchanged(client, stored, session, respx_mock):
    body = (
        b'{ "type":"urn:kalash:error:GOAL-011", "status":422, "errorCode":"GOAL-011",'
        b' "extra": [1,2], "instance":"/internal/example" }'
    )
    respx_mock.post(REMOTE + "/balance-adjustments").respond(
        422,
        content=body,
        headers={"content-type": "application/problem+json; charset=utf-8", "retry-after": "9"},
    )
    response = client.patch(f"{PATH}/{TXN_ID}", json={"amount": 12})
    assert response.status_code == 422
    assert response.content == body
    assert response.headers["content-type"] == "application/problem+json; charset=utf-8"
    assert response.headers["retry-after"] == "9"
    session.commit.assert_not_awaited()
    session.rollback.assert_awaited_once()


@pytest.mark.parametrize(
    ("failure", "status", "code"),
    [(httpx.ReadTimeout("secret"), 504, "TXN-003"), (httpx.ConnectError("secret"), 503, "TXN-002")],
)
def test_remote_failure_rolls_back_and_maps_status(
    client, stored, session, respx_mock, failure, status, code
):
    respx_mock.post(REMOTE + "/balance-adjustments").mock(side_effect=failure)
    response = client.patch(f"{PATH}/{TXN_ID}", json={"amount": 12})
    assert response.status_code == status
    assert response.json()["errorCode"] == code
    assert "secret" not in response.text
    session.rollback.assert_awaited_once()
    session.commit.assert_not_awaited()


@pytest.mark.parametrize(
    ("failure", "status", "code"),
    [
        (StaleDataError("private"), 409, "COMMON-409"),
        (OperationalError("private", {}, None), 500, "COMMON-500"),
    ],
)
def test_local_failure_returns_sanitized_problem(client, stored, session, failure, status, code):
    session.flush.side_effect = failure
    response = client.patch(f"{PATH}/{TXN_ID}", json={"amount": 12})
    assert response.status_code == status
    assert response.json()["errorCode"] == code
    assert "private" not in response.text
    session.rollback.assert_awaited_once()


def test_openapi_documents_all_five_operations_and_error_contract(client):
    schema = client.get("/openapi.json").json()
    operations = [
        (PATH, "post", "201"),
        (PATH, "get", "200"),
        (PATH + "/{transactionId}", "patch", "200"),
        (PATH + "/{transactionId}", "delete", "204"),
        (PATH + "/goals/{goalId}", "delete", "204"),
    ]
    for path, method, success in operations:
        responses = schema["paths"][path][method]["responses"]
        assert success in responses
        assert "application/problem+json" in responses["400"]["content"]
        assert responses["422"]["description"].startswith("Goal business")
    assert "goalBalance" in schema["components"]["schemas"]["TransactionResponse"]["example"]
    assert (
        "goalBalance" not in schema["components"]["schemas"]["TransactionHistoryItem"]["properties"]
    )
