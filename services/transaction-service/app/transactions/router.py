"""Thin transaction HTTP routes implementing the first four contracts in LLD Section 13.2."""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Path, Query, Response

from app.common.api_docs import ERROR_RESPONSES
from app.transactions.dependencies import get_transaction_service
from app.transactions.schemas import (
    CreateTransactionRequest,
    TransactionPage,
    TransactionResponse,
    UpdateTransactionRequest,
)
from app.transactions.service import TransactionService

router = APIRouter(prefix="/api/v1/transactions", tags=["Transactions"], responses=ERROR_RESPONSES)
Service = Annotated[TransactionService, Depends(get_transaction_service)]


@router.post(
    "",
    response_model=TransactionResponse,
    status_code=201,
    summary="Record a deposit or withdrawal",
    responses={
        201: {
            "description": "Created transaction with resulting goal state",
            "headers": {
                "Location": {
                    "description": "Created transaction resource",
                    "schema": {"type": "string"},
                }
            },
        }
    },
)
async def create(
    request: CreateTransactionRequest, service: Service, response: Response
) -> TransactionResponse:
    """Delegate the local/remote commit sequence; return the resulting goal snapshot."""
    transaction = await service.create(request)
    response.headers["Location"] = f"/api/v1/transactions/{transaction.transaction_id}"
    return transaction


@router.get("", response_model=TransactionPage, summary="Read newest-first transaction history")
async def history(
    service: Service,
    goal_id: Annotated[UUID, Query(alias="goalId")],
    page: Annotated[int, Query(ge=0)] = 0,
    size: Annotated[int, Query(ge=1, le=100)] = 20,
) -> TransactionPage:
    """Return paginated history; an unknown goal with no records has an empty page."""
    return await service.history(goal_id, page, size)


@router.patch(
    "/{transactionId}", response_model=TransactionResponse, summary="Edit a transaction amount"
)
async def update(
    transaction_id: Annotated[UUID, Path(alias="transactionId")],
    request: UpdateTransactionRequest,
    service: Service,
) -> TransactionResponse:
    """Delegate amount editing without permitting goal, type or date changes."""
    return await service.update(transaction_id, request)


@router.delete(
    "/{transactionId}",
    status_code=204,
    summary="Delete a transaction and reverse its balance effect",
)
async def delete(
    transaction_id: Annotated[UUID, Path(alias="transactionId")], service: Service
) -> Response:
    """Return no body, per the explicit LLD endpoint contract."""
    await service.delete(transaction_id)
    return Response(status_code=204)
