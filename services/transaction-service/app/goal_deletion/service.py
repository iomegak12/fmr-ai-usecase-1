"""Repeatable history-first Cancelled-goal deletion (BR-20 and LLD Section 17.3)."""

import asyncio
import logging
from uuid import UUID

from app.clients.goal_client import GoalClient
from app.common.errors import ApiError, ErrorCode
from app.transactions.service import TransactionService

logger = logging.getLogger("kalash.goal_deletion")


class GoalDeletionService:
    """Coordinate services without importing another feature's repository."""

    def __init__(self, goals: GoalClient, transactions: TransactionService) -> None:
        """Use the Goal API and transaction-owned history cleanup operation."""
        self.goals = goals
        self.transactions = transactions

    async def delete(self, goal_id: UUID) -> None:
        """Confirm Cancelled, commit history removal, then delete the goal; retry is safe.

        A missing goal returns its original GOAL-001 response. If the last step
        fails, the goal remains Cancelled and already-empty history is harmless
        on a subsequent request.
        """
        snapshot = await self.goals.snapshot(goal_id)
        if snapshot.status != "CANCELLED":
            raise ApiError(ErrorCode.GOAL_008)
        await self.transactions.delete_history(goal_id)
        try:
            await self.goals.delete(goal_id)
        except Exception, asyncio.CancelledError:
            logger.error("goal_deletion_incomplete", extra={"goalId": str(goal_id)})
            raise
        logger.info("cancelled_goal_deleted", extra={"goalId": str(goal_id)})
