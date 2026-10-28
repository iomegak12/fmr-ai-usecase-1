import asyncio
from datetime import UTC, date, datetime
from unittest.mock import AsyncMock, MagicMock
from uuid import UUID

import httpx
import pytest
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm.exc import StaleDataError

from app.clients.goal_client import GoalClient, GoalSnapshot, GoalUnavailable
from app.common.errors import ApiError, ErrorCode, GoalProblem
from app.transactions.models import Transaction, TransactionType
from app.transactions.schemas import CreateTransactionRequest, UpdateTransactionRequest
from app.transactions.service import TransactionService

GOAL_ID = UUID("10000000-0000-0000-0000-000000000001")
TXN_ID = UUID("20000000-0000-0000-0000-000000000001")


@pytest.fixture
def record():
    return Transaction(
        transaction_id=TXN_ID,
        goal_id=GOAL_ID,
        type=TransactionType.DEPOSIT,
        amount=20,
        transaction_date=date(2026, 10, 1),
        version=1,
        created_at=datetime(2026, 10, 1, tzinfo=UTC),
        updated_at=datetime(2026, 10, 1, tzinfo=UTC),
    )


@pytest.fixture
def goals():
    mock = AsyncMock(spec=GoalClient)
    mock.adjust.return_value = GoalSnapshot(
        goalId=GOAL_ID, status="ACTIVE", balance=30, targetAmount=100
    )
    return mock


@pytest.fixture
def service(session, goals, clock, record):
    session.get.return_value = record
    return TransactionService(MagicMock(return_value=session), goals, clock)


@pytest.mark.parametrize(("kind", "delta"), [("DEPOSIT", 20), ("WITHDRAWAL", -20)])
async def test_create_order_and_immutable_ist_date(service, session, goals, clock, kind, delta):
    events = []
    session.add.side_effect = lambda record: events.append("add")
    session.flush.side_effect = lambda: events.append("flush")

    async def remote(*args):
        events.append("goal")
        return GoalSnapshot(goalId=GOAL_ID, status="ACTIVE", balance=30, targetAmount=100)

    async def commit():
        events.append("commit")
        session.in_transaction.return_value = False

    goals.adjust.side_effect = remote
    session.commit.side_effect = commit
    result = await service.create(CreateTransactionRequest(goalId=GOAL_ID, type=kind, amount=20))
    assert events == ["add", "flush", "goal", "commit"]
    assert result.transaction_date == date(2026, 10, 28)
    assert result.created_at == clock.now()
    assert result.updated_at == result.created_at
    assert result.goal_balance == 30
    goals.adjust.assert_awaited_once_with(GOAL_ID, kind, delta)
    session.rollback.assert_not_awaited()


@pytest.mark.parametrize(
    ("kind", "new", "delta"),
    [
        ("DEPOSIT", 30, 10),
        ("DEPOSIT", 10, -10),
        ("DEPOSIT", 20, 0),
        ("WITHDRAWAL", 30, -10),
        ("WITHDRAWAL", 10, 10),
        ("WITHDRAWAL", 20, 0),
    ],
)
async def test_edit_delta_and_date_preservation(
    service, session, goals, record, clock, kind, new, delta
):
    record.type = TransactionType(kind)
    result = await service.update(TXN_ID, UpdateTransactionRequest(amount=new))
    assert result.amount == new
    assert result.transaction_date == date(2026, 10, 1)
    assert result.created_at == datetime(2026, 10, 1, tzinfo=UTC)
    assert result.updated_at == clock.now()
    goals.adjust.assert_awaited_once_with(GOAL_ID, "TRANSACTION_EDIT", delta)
    session.flush.assert_awaited_once()
    session.commit.assert_awaited_once()


@pytest.mark.parametrize(("kind", "delta"), [("DEPOSIT", -20), ("WITHDRAWAL", 20)])
async def test_delete_reverses_delta(service, session, goals, record, kind, delta):
    record.type = TransactionType(kind)
    assert await service.delete(TXN_ID) is None
    session.delete.assert_awaited_once_with(record)
    goals.adjust.assert_awaited_once_with(GOAL_ID, "TRANSACTION_DELETE", delta)
    session.commit.assert_awaited_once()


def failures():
    return [
        GoalProblem(httpx.Response(422, json={"errorCode": "GOAL-009"})),
        GoalUnavailable(ErrorCode.TXN_002, False),
        GoalUnavailable(ErrorCode.TXN_003, True),
        asyncio.CancelledError(),
    ]


@pytest.mark.parametrize("operation", ["create", "update", "delete"])
@pytest.mark.parametrize("failure", failures())
async def test_remote_failure_rolls_back_every_mutation(
    service, session, goals, operation, failure
):
    goals.adjust.side_effect = failure
    with pytest.raises(type(failure)):
        await invoke(service, operation)
    session.flush.assert_awaited_once()
    session.commit.assert_not_awaited()
    session.rollback.assert_awaited_once()
    session.__aexit__.assert_awaited_once()


@pytest.mark.parametrize("operation", ["create", "update", "delete"])
@pytest.mark.parametrize(
    "failure", [StaleDataError("stale"), OperationalError("private", {}, None)]
)
async def test_local_flush_failure_never_calls_goal(service, session, goals, operation, failure):
    session.flush.side_effect = failure
    with pytest.raises(type(failure)):
        await invoke(service, operation)
    goals.adjust.assert_not_awaited()
    session.commit.assert_not_awaited()
    session.rollback.assert_awaited_once()


@pytest.mark.parametrize("operation", ["create", "update", "delete"])
@pytest.mark.parametrize(
    "failure", [OperationalError("private", {}, None), asyncio.CancelledError()]
)
async def test_post_goal_commit_failure_logs_mismatch_and_rolls_back(
    service, session, operation, failure, monkeypatch
):
    log = MagicMock()
    monkeypatch.setattr("app.transactions.service.logger.error", log)
    session.commit.side_effect = failure
    with pytest.raises(type(failure)):
        await invoke(service, operation)
    session.rollback.assert_awaited_once()
    extra = log.call_args.kwargs["extra"]
    assert extra["goalId"] == str(GOAL_ID)
    assert "transactionId" in extra and "delta" in extra
    assert extra["remoteOutcome"] == "confirmed"


async def test_uncertain_remote_outcome_is_logged(service, goals, session, monkeypatch):
    log = MagicMock()
    monkeypatch.setattr("app.transactions.service.logger.error", log)
    goals.adjust.side_effect = GoalUnavailable(ErrorCode.TXN_003, True)
    with pytest.raises(GoalUnavailable):
        await service.delete(TXN_ID)
    assert log.call_args.kwargs["extra"]["remoteOutcome"] == "unknown"
    session.rollback.assert_awaited_once()


async def test_missing_transaction_does_not_call_goal(service, session, goals):
    session.get.return_value = None
    for action in ("update", "delete"):
        with pytest.raises(ApiError) as caught:
            await invoke(service, action)
        assert caught.value.code == ErrorCode.TXN_001
    goals.adjust.assert_not_awaited()


async def test_history_maps_page_without_goal_calls(service, session, goals, record):
    session.scalar.return_value = 3
    session.scalars.return_value = MagicMock(all=MagicMock(return_value=[record]))
    page = await service.history(GOAL_ID, 1, 2)
    assert (page.page, page.size, page.total_elements, page.total_pages) == (1, 2, 3, 2)
    assert page.content[0].transaction_id == TXN_ID
    assert "goalBalance" not in page.content[0].model_dump(by_alias=True)
    goals.adjust.assert_not_awaited()
    goals.snapshot.assert_not_awaited()


async def test_history_cleanup_commits_only_after_all_rows_deleted(service, session, record):
    session.scalars.side_effect = [
        MagicMock(all=MagicMock(return_value=[record])),
        MagicMock(all=MagicMock(return_value=[])),
    ]
    await service.delete_history(GOAL_ID)
    session.delete.assert_awaited_once_with(record)
    session.flush.assert_awaited_once()
    session.commit.assert_awaited_once()


async def test_history_commit_failure_rolls_back(service, session):
    session.scalars.return_value = MagicMock(all=MagicMock(return_value=[]))
    session.commit.side_effect = OperationalError("private", {}, None)
    with pytest.raises(OperationalError):
        await service.delete_history(GOAL_ID)
    session.rollback.assert_awaited_once()


async def test_mismatch_logging_does_not_read_expired_orm_fields(service, session, monkeypatch):
    record = MagicMock(spec=Transaction)
    record.goal_id = GOAL_ID
    record.transaction_id = TXN_ID
    log = MagicMock()
    monkeypatch.setattr("app.transactions.service.logger.error", log)

    async def failed_commit():
        del record.goal_id
        del record.transaction_id
        raise OperationalError("commit failed", {}, None)

    session.commit.side_effect = failed_commit
    with pytest.raises(OperationalError):
        await service._apply(session, record, "TRANSACTION_EDIT", 10)
    assert log.call_args.kwargs["extra"]["goalId"] == str(GOAL_ID)


async def invoke(service, operation):
    if operation == "create":
        return await service.create(
            CreateTransactionRequest(goalId=GOAL_ID, type="DEPOSIT", amount=20)
        )
    if operation == "update":
        return await service.update(TXN_ID, UpdateTransactionRequest(amount=30))
    return await service.delete(TXN_ID)
