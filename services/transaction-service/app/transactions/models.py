"""Versioned, whole-rupee transaction persistence (BR-07/09 and LLD Section 9.2)."""

from datetime import date, datetime
from enum import StrEnum
from uuid import UUID

from sqlalchemy import BigInteger, CheckConstraint, Date, DateTime, Enum, Index, Uuid
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """Provide metadata for Alembic without creating tables at runtime."""


class TransactionType(StrEnum):
    """Distinguish signed balance semantics while storing positive amounts."""

    DEPOSIT = "DEPOSIT"
    WITHDRAWAL = "WITHDRAWAL"


class Transaction(Base):
    """Store immutable goal/type/date and version-checked amount changes."""

    __tablename__ = "transactions"

    transaction_id: Mapped[UUID] = mapped_column(Uuid, primary_key=True)
    goal_id: Mapped[UUID] = mapped_column(Uuid, nullable=False)
    type: Mapped[TransactionType] = mapped_column(
        Enum(TransactionType, native_enum=False, length=10), nullable=False
    )
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    transaction_date: Mapped[date] = mapped_column(Date, nullable=False)
    version: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    __table_args__ = (
        Index("ix_transactions_goal_created", goal_id, created_at.desc()),
        CheckConstraint("amount > 0", name="transactions_amount_check"),
        CheckConstraint("type IN ('DEPOSIT', 'WITHDRAWAL')", name="transactions_type_check"),
    )
    __mapper_args__ = {"version_id_col": version}
