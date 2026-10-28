"""Wire business services from existing lifespan resources without allocating new pools."""

from typing import Annotated

from fastapi import Depends, Request

from app.clients.goal_client import GoalClient
from app.common.lifecycle import Resources, get_resources
from app.transactions.service import TransactionService


def get_transaction_service(
    request: Request, resources: Annotated[Resources, Depends(get_resources)]
) -> TransactionService:
    """Construct a request-scoped facade over shared sessions, HTTP client and clock."""
    return TransactionService(
        resources.sessions,
        GoalClient(resources.goal_client, request.app.state.settings.goal_service_timeout_seconds),
        request.app.state.clock,
    )
