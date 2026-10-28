"""Camel-case public contracts with strict integer validation (BR-07, LLD Section 13.3)."""

from datetime import date, datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StrictInt
from pydantic.alias_generators import to_camel

from app.transactions.models import TransactionType

MAX_AMOUNT = 2**63 - 1
Amount = Annotated[StrictInt, Field(gt=0, le=MAX_AMOUNT)]


class ApiModel(BaseModel):
    """Use Python names internally and camelCase on HTTP input/output."""

    model_config = ConfigDict(
        alias_generator=to_camel, populate_by_name=True, from_attributes=True, extra="forbid"
    )


class CreateTransactionRequest(ApiModel):
    """Validate a deposit or withdrawal amount before any database/HTTP side effect."""

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "goalId": "10000000-0000-0000-0000-000000000001",
                "type": "DEPOSIT",
                "amount": 5000,
            }
        }
    )
    goal_id: UUID
    type: TransactionType
    amount: Amount


class UpdateTransactionRequest(ApiModel):
    """Permit only the amount to change; date, type and goal remain immutable."""

    model_config = ConfigDict(json_schema_extra={"example": {"amount": 4500}})
    amount: Amount


class TransactionHistoryItem(ApiModel):
    """Represent a persisted transaction without a potentially stale goal snapshot."""

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "transactionId": "20000000-0000-0000-0000-000000000001",
                "goalId": "10000000-0000-0000-0000-000000000001",
                "type": "DEPOSIT",
                "amount": 5000,
                "transactionDate": "2026-10-28",
                "createdAt": "2026-10-27T20:00:00Z",
                "updatedAt": "2026-10-27T20:00:00Z",
            }
        }
    )
    transaction_id: UUID
    goal_id: UUID
    type: TransactionType
    amount: int
    transaction_date: date
    created_at: datetime
    updated_at: datetime


class TransactionResponse(TransactionHistoryItem):
    """Include the goal's resulting state after successful create/edit operations."""

    goal_balance: int
    goal_status: Literal["ACTIVE", "ACHIEVED", "CANCELLED"]

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "transactionId": "20000000-0000-0000-0000-000000000001",
                "goalId": "10000000-0000-0000-0000-000000000001",
                "type": "DEPOSIT",
                "amount": 5000,
                "transactionDate": "2026-10-28",
                "createdAt": "2026-10-27T20:00:00Z",
                "updatedAt": "2026-10-27T20:00:00Z",
                "goalBalance": 5000,
                "goalStatus": "ACTIVE",
            }
        }
    )


class TransactionPage(ApiModel):
    """Expose stable zero-based pagination, newest transaction first."""

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "content": [],
                "page": 0,
                "size": 20,
                "totalElements": 0,
                "totalPages": 0,
            }
        }
    )
    content: list[TransactionHistoryItem]
    page: int
    size: int
    total_elements: int
    total_pages: int
