"""Thin BR-20 HTTP adapter for history-first Cancelled-goal deletion."""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Path, Response

from app.common.api_docs import ERROR_RESPONSES
from app.goal_deletion.service import GoalDeletionService
from app.transactions.dependencies import get_transaction_service
from app.transactions.service import TransactionService

router = APIRouter(
    prefix="/api/v1/transactions/goals", tags=["Goal deletion"], responses=ERROR_RESPONSES
)


@router.delete("/{goalId}", status_code=204, summary="Delete a Cancelled goal and its history")
async def delete(
    goal_id: Annotated[UUID, Path(alias="goalId")],
    transactions: Annotated[TransactionService, Depends(get_transaction_service)],
) -> Response:
    """Delegate sequencing to the coordinator; do not call persistence in the router."""
    await GoalDeletionService(transactions.goals, transactions).delete(goal_id)
    return Response(status_code=204)
