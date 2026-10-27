"""D-16/D-17 health: liveness is process-only; readiness depends solely on the DB."""

import logging
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel
from sqlalchemy.exc import SQLAlchemyError

from app.common.db import check_database
from app.common.lifecycle import Resources, get_resources

logger = logging.getLogger("kalash.health")
router = APIRouter(tags=["Health"])


class HealthStatus(BaseModel):
    """Report availability without revealing connection details."""

    status: Literal["UP", "DOWN"]


@router.get(
    "/health",
    response_model=HealthStatus,
    summary="Process liveness",
    description="Reports process availability without checking external dependencies.",
    responses={200: {"content": {"application/json": {"example": {"status": "UP"}}}}},
)
async def health() -> HealthStatus:
    """Return UP as long as this process can serve requests."""
    return HealthStatus(status="UP")


@router.get(
    "/ready",
    response_model=HealthStatus,
    summary="Database readiness",
    description="Checks transaction_db through an ORM session; never calls the Goal Service.",
    responses={
        200: {"content": {"application/json": {"example": {"status": "UP"}}}},
        503: {
            "model": HealthStatus,
            "description": "Transaction database is unavailable.",
            "content": {"application/json": {"example": {"status": "DOWN"}}},
        },
    },
)
async def ready(
    response: Response, resources: Annotated[Resources, Depends(get_resources)]
) -> HealthStatus:
    """Return 503 on database connectivity failure while preserving liveness."""
    try:
        await check_database(resources.sessions)
    except (SQLAlchemyError, OSError, TimeoutError) as exc:
        logger.error("database_unavailable", extra={"exceptionType": type(exc).__name__})
        response.status_code = 503
        return HealthStatus(status="DOWN")
    return HealthStatus(status="UP")
