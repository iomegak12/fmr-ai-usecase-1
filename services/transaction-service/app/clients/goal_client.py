"""Non-retrying Goal Service contract with unchanged 4xx Problem Details (LLD Section 14)."""

import logging
from typing import Literal, NoReturn
from uuid import UUID

import httpx
from pydantic import BaseModel, ConfigDict, Field, StrictInt, ValidationError

from app.common.correlation import HEADER
from app.common.errors import ApiError, ErrorCode, GoalProblem
from app.common.logging import correlation_id

logger = logging.getLogger("kalash.goal_client")


class GoalSnapshot(BaseModel):
    """Validate successful upstream snapshots before returning public success."""

    model_config = ConfigDict(populate_by_name=True)
    goal_id: UUID = Field(alias="goalId")
    status: Literal["ACTIVE", "ACHIEVED", "CANCELLED"]
    balance: StrictInt = Field(ge=0, le=2**63 - 1)
    target_amount: StrictInt = Field(alias="targetAmount", gt=0, le=2**63 - 1)


class GoalUnavailable(ApiError):
    """Describe an unavailable/invalid upstream and whether a mutation might have applied."""

    def __init__(self, code: ErrorCode, uncertain: bool) -> None:
        """Expose only catalogue-approved text; retain uncertainty for reconciliation logs."""
        super().__init__(code)
        self.uncertain = uncertain


class GoalClient:
    """Use the lifespan-owned httpx client; enforce the configured timeout without retries."""

    def __init__(self, client: httpx.AsyncClient, timeout: float = 3) -> None:
        """Bind the shared HTTP pool and per-operation deadline."""
        self.client = client
        self.timeout = timeout

    async def snapshot(self, goal_id: UUID) -> GoalSnapshot:
        """Read the goal for BR-20 cancellation checks."""
        response = await self._request("GET", goal_id)
        return self._snapshot(response, goal_id, False)

    async def adjust(self, goal_id: UUID, operation: str, delta: int) -> GoalSnapshot:
        """Apply a signed delta; only a validated 200 snapshot confirms acceptance.

        Args:
            goal_id: Target goal identity.
            operation: DEPOSIT, WITHDRAWAL, TRANSACTION_EDIT or TRANSACTION_DELETE.
            delta: Signed whole-rupee balance change.

        Returns:
            The validated snapshot for the same goal, with no automatic retry.

        Raises:
            GoalProblem: An upstream 4xx, preserved for unchanged propagation.
            GoalUnavailable: A timeout, transport failure or invalid upstream response.
        """
        response = await self._request(
            "POST",
            goal_id,
            suffix="/balance-adjustments",
            payload={"operation": operation, "delta": delta},
        )
        return self._snapshot(response, goal_id, True)

    async def delete(self, goal_id: UUID) -> None:
        """Delete a Cancelled goal after history has durably committed its removal."""
        response = await self._request("DELETE", goal_id)
        if response.status_code != 204 or response.content:
            self._invalid_response(True)

    async def _request(
        self,
        method: str,
        goal_id: UUID,
        suffix: str = "",
        payload: dict[str, str | int] | None = None,
    ) -> httpx.Response:
        mutating = method != "GET"
        headers = {HEADER: correlation_id.get()} if correlation_id.get() else {}
        try:
            response = await self.client.request(
                method,
                f"/internal/v1/goals/{goal_id}{suffix}",
                json=payload,
                headers=headers,
                timeout=self.timeout,
                follow_redirects=False,
            )
        except httpx.TimeoutException as exc:
            logger.error("goal_service_timeout", extra={"goalId": str(goal_id)})
            raise GoalUnavailable(
                ErrorCode.TXN_003,
                mutating and not isinstance(exc, (httpx.ConnectTimeout, httpx.PoolTimeout)),
            ) from exc
        except httpx.RequestError as exc:
            logger.error("goal_service_unavailable", extra={"exceptionType": type(exc).__name__})
            raise GoalUnavailable(
                ErrorCode.TXN_002, mutating and not isinstance(exc, httpx.ConnectError)
            ) from exc
        if 400 <= response.status_code < 500:
            logger.warning("goal_service_rejected", extra={"status": response.status_code})
            raise GoalProblem(response)
        if response.status_code >= 500:
            logger.error("goal_service_failure", extra={"status": response.status_code})
            raise GoalUnavailable(ErrorCode.TXN_002, mutating)
        return response

    def _snapshot(self, response: httpx.Response, goal_id: UUID, uncertain: bool) -> GoalSnapshot:
        if response.status_code != 200:
            self._invalid_response(uncertain)
        try:
            snapshot = GoalSnapshot.model_validate_json(response.content)
        except ValidationError as exc:
            logger.error("goal_service_invalid_snapshot")
            raise GoalUnavailable(ErrorCode.TXN_002, uncertain) from exc
        if snapshot.goal_id != goal_id:
            self._invalid_response(uncertain)
        return snapshot

    def _invalid_response(self, uncertain: bool) -> NoReturn:
        logger.error("goal_service_invalid_response")
        raise GoalUnavailable(ErrorCode.TXN_002, uncertain)
