from unittest.mock import AsyncMock
from uuid import uuid4

import httpx
import pytest

from app.clients.goal_client import GoalClient, GoalSnapshot, GoalUnavailable
from app.common.errors import ApiError, ErrorCode, GoalProblem
from app.goal_deletion.service import GoalDeletionService
from app.transactions.service import TransactionService


@pytest.fixture
def collaborators():
    goal_id = uuid4()
    goals = AsyncMock(spec=GoalClient)
    goals.snapshot.return_value = GoalSnapshot(
        goalId=goal_id, status="CANCELLED", balance=0, targetAmount=100
    )
    transactions = AsyncMock(spec=TransactionService)
    return goal_id, goals, transactions, GoalDeletionService(goals, transactions)


async def test_history_commit_precedes_goal_delete(collaborators):
    goal_id, goals, transactions, service = collaborators
    events = []
    transactions.delete_history.side_effect = lambda _: events.append("history-committed")
    goals.delete.side_effect = lambda _: events.append("goal-deleted")
    await service.delete(goal_id)
    assert events == ["history-committed", "goal-deleted"]
    goals.snapshot.assert_awaited_once_with(goal_id)


@pytest.mark.parametrize("status", ["ACTIVE", "ACHIEVED"])
async def test_non_cancelled_never_removes_history(collaborators, status):
    goal_id, goals, transactions, service = collaborators
    goals.snapshot.return_value = GoalSnapshot(
        goalId=goal_id, status=status, balance=100, targetAmount=100
    )
    with pytest.raises(ApiError) as caught:
        await service.delete(goal_id)
    assert caught.value.code == ErrorCode.GOAL_008
    transactions.delete_history.assert_not_awaited()
    goals.delete.assert_not_awaited()


async def test_missing_goal_problem_is_unchanged(collaborators):
    goal_id, goals, transactions, service = collaborators
    error = GoalProblem(httpx.Response(404, content=b'{"errorCode":"GOAL-001"}'))
    goals.snapshot.side_effect = error
    with pytest.raises(GoalProblem) as caught:
        await service.delete(goal_id)
    assert caught.value is error
    transactions.delete_history.assert_not_awaited()


async def test_history_failure_never_deletes_goal(collaborators):
    goal_id, goals, transactions, service = collaborators
    transactions.delete_history.side_effect = RuntimeError("commit failed")
    with pytest.raises(RuntimeError):
        await service.delete(goal_id)
    goals.delete.assert_not_awaited()


async def test_goal_delete_failure_can_be_repeated_after_history_removed(collaborators):
    goal_id, goals, transactions, service = collaborators
    goals.delete.side_effect = [GoalUnavailable(ErrorCode.TXN_002, False), None]
    with pytest.raises(GoalUnavailable):
        await service.delete(goal_id)
    await service.delete(goal_id)
    assert transactions.delete_history.await_count == 2
    assert goals.delete.await_count == 2
