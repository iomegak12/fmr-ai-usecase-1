"""ORM-only transaction storage and paginated history (LLD Section 9.2, BR-07/09)."""

from collections.abc import Sequence
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.errors import ApiError, ErrorCode
from app.transactions.models import Transaction


class TransactionRepository:
    """Keep persistence within the transactions feature; never commit implicitly."""

    def __init__(self, session: AsyncSession) -> None:
        """Bind repository operations to the caller's local transaction."""
        self.session = session

    async def require(self, transaction_id: UUID) -> Transaction:
        """Load one transaction or raise TXN-001 before any Goal Service call."""
        transaction = await self.session.get(Transaction, transaction_id)
        if transaction is None:
            raise ApiError(ErrorCode.TXN_001)
        return transaction

    def add(self, transaction: Transaction) -> None:
        """Stage a new ORM row; the service must flush before adjusting the goal."""
        self.session.add(transaction)

    async def delete(self, transaction: Transaction) -> None:
        """Stage a version-checked deletion, not a bulk SQL deletion."""
        await self.session.delete(transaction)

    async def history(
        self, goal_id: UUID, page: int, size: int
    ) -> tuple[Sequence[Transaction], int]:
        """Read goal-filtered history with deterministic descending timestamp/UUID order."""
        total = await self.session.scalar(
            select(func.count()).select_from(Transaction).where(Transaction.goal_id == goal_id)
        )
        records = await self.session.scalars(
            select(Transaction)
            .where(Transaction.goal_id == goal_id)
            .order_by(Transaction.created_at.desc(), Transaction.transaction_id.desc())
            .offset(page * size)
            .limit(size)
        )
        if total is None:
            raise RuntimeError("Transaction count returned no result")
        return records.all(), total

    async def delete_history(self, goal_id: UUID) -> None:
        """Remove history in bounded batches within one transaction, retaining ORM checks."""
        while True:
            records = (
                await self.session.scalars(
                    select(Transaction).where(Transaction.goal_id == goal_id).limit(500)
                )
            ).all()
            if not records:
                return
            for transaction in records:
                await self.session.delete(transaction)
            await self.session.flush()
