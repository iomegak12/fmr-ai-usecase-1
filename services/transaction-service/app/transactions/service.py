"""Transaction sequencing, rollback and mismatch logging (BR-09 through BR-14)."""

import asyncio
import logging
from uuid import UUID, uuid4

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.clients.goal_client import GoalClient, GoalSnapshot, GoalUnavailable
from app.common.clock import Clock
from app.common.db import session_scope
from app.transactions.models import Transaction, TransactionType
from app.transactions.repository import TransactionRepository
from app.transactions.schemas import (
    CreateTransactionRequest,
    TransactionHistoryItem,
    TransactionPage,
    TransactionResponse,
    UpdateTransactionRequest,
)

logger = logging.getLogger("kalash.transactions")


class TransactionService:
    """Own transaction persistence while delegating balance authority to the Goal Service."""

    def __init__(
        self, sessions: async_sessionmaker[AsyncSession], goals: GoalClient, clock: Clock
    ) -> None:
        """Use lifespan-owned sessions/client and an injectable IST-aware clock."""
        self.sessions = sessions
        self.goals = goals
        self.clock = clock

    async def create(self, request: CreateTransactionRequest) -> TransactionResponse:
        """Record a deposit/withdrawal with an immutable clock-derived date (BR-09).

        Args:
            request: Validated goal, transaction type and positive amount.

        Returns:
            The committed transaction and resulting Goal Service balance/status.

        Raises:
            GoalProblem: The goal rejects the operation; local work is rolled back.
            GoalUnavailable: The remote response cannot confirm success.
        """
        now = self.clock.now()
        transaction = Transaction(
            transaction_id=uuid4(),
            goal_id=request.goal_id,
            type=request.type,
            amount=request.amount,
            transaction_date=self.clock.today(),
            created_at=now,
            updated_at=now,
        )
        delta = request.amount if request.type == TransactionType.DEPOSIT else -request.amount
        async with session_scope(self.sessions) as session:
            TransactionRepository(session).add(transaction)
            snapshot = await self._apply(session, transaction, request.type.value, delta)
            return self._response(transaction, snapshot)

    async def update(
        self, transaction_id: UUID, request: UpdateTransactionRequest
    ) -> TransactionResponse:
        """Edit the amount only, reversing withdrawal differences (BR-13).

        Args:
            transaction_id: Identity of the persisted transaction to edit.
            request: New positive amount; goal, type and date cannot change.

        Returns:
            Updated transaction and the goal snapshot after both commits succeed.

        Raises:
            ApiError: TXN-001 if the transaction does not exist.
        """
        async with session_scope(self.sessions) as session:
            transaction = await TransactionRepository(session).require(transaction_id)
            difference = request.amount - transaction.amount
            delta = difference if transaction.type == TransactionType.DEPOSIT else -difference
            transaction.amount = request.amount
            transaction.updated_at = self.clock.now()
            snapshot = await self._apply(session, transaction, "TRANSACTION_EDIT", delta)
            return self._response(transaction, snapshot)

    async def delete(self, transaction_id: UUID) -> None:
        """Reverse the transaction before committing local deletion (BR-13/14).

        Args:
            transaction_id: Identity of the transaction whose effect is reversed.

        Raises:
            ApiError: TXN-001 if absent; remote rejection leaves the row intact.
        """
        async with session_scope(self.sessions) as session:
            repository = TransactionRepository(session)
            transaction = await repository.require(transaction_id)
            delta = (
                -transaction.amount
                if transaction.type == TransactionType.DEPOSIT
                else transaction.amount
            )
            await repository.delete(transaction)
            await self._apply(session, transaction, "TRANSACTION_DELETE", delta)

    async def history(self, goal_id: UUID, page: int, size: int) -> TransactionPage:
        """Return newest-first history without depending on Goal Service availability.

        Args:
            goal_id: Goal whose history is requested.
            page: Validated zero-based page number.
            size: Validated page size from 1 through 100.

        Returns:
            A page without goal balance/status fields; absent history is an empty page.
        """
        async with session_scope(self.sessions) as session:
            records, total = await TransactionRepository(session).history(goal_id, page, size)
            return TransactionPage(
                content=[TransactionHistoryItem.model_validate(record) for record in records],
                page=page,
                size=size,
                total_elements=total,
                total_pages=(total + size - 1) // size,
            )

    async def delete_history(self, goal_id: UUID) -> None:
        """Provide the deletion coordinator a transaction-owned cleanup boundary.

        Args:
            goal_id: Goal already confirmed Cancelled by the coordinator.

        Raises:
            SQLAlchemyError: Failed history removal/commit; local work is rolled back.
        """
        async with session_scope(self.sessions) as session:
            await TransactionRepository(session).delete_history(goal_id)
            await session.commit()
            logger.info("transaction_history_deleted", extra={"goalId": str(goal_id)})

    async def _apply(
        self, session: AsyncSession, transaction: Transaction, operation: str, delta: int
    ) -> GoalSnapshot:
        goal_id = transaction.goal_id
        transaction_id = transaction.transaction_id
        await session.flush()
        try:
            snapshot = await self.goals.adjust(goal_id, operation, delta)
        except GoalUnavailable as exc:
            if exc.uncertain:
                self._mismatch(goal_id, transaction_id, operation, delta, "unknown")
            raise
        except asyncio.CancelledError:
            self._mismatch(goal_id, transaction_id, operation, delta, "unknown")
            raise
        try:
            await session.commit()
        except Exception, asyncio.CancelledError:
            # After confirmed remote success, any failed local commit requires reconciliation.
            self._mismatch(goal_id, transaction_id, operation, delta, "confirmed")
            raise
        logger.info(
            "transaction_committed",
            extra={
                "goalId": str(goal_id),
                "transactionId": str(transaction_id),
                "operation": operation,
                "delta": delta,
            },
        )
        return snapshot

    def _response(self, transaction: Transaction, snapshot: GoalSnapshot) -> TransactionResponse:
        values = TransactionHistoryItem.model_validate(transaction).model_dump()
        return TransactionResponse(
            **values, goal_balance=snapshot.balance, goal_status=snapshot.status
        )

    def _mismatch(
        self, goal_id: UUID, transaction_id: UUID, operation: str, delta: int, outcome: str
    ) -> None:
        logger.error(
            "cross_service_commit_mismatch goalId=%s transactionId=%s delta=%s remoteOutcome=%s",
            goal_id,
            transaction_id,
            delta,
            outcome,
            extra={
                "goalId": str(goal_id),
                "transactionId": str(transaction_id),
                "operation": operation,
                "delta": delta,
                "remoteOutcome": outcome,
            },
        )
