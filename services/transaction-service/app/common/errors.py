"""RFC 9457 error boundaries and the LLD Section 21.2 error catalogue."""

import logging
from enum import Enum
from http import HTTPStatus
from typing import TypedDict

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException

from app.common.clock import Clock
from app.common.correlation import HEADER

logger = logging.getLogger("kalash.errors")


class ErrorCode(Enum):
    """Stable contract codes shared with Goal Service and gateway documentation."""

    COMMON_400 = ("COMMON-400", 400, "Validation failed")
    COMMON_409 = ("COMMON-409", 409, "Concurrent update conflict, please retry")
    COMMON_429 = ("COMMON-429", 429, "Too many requests, please retry later")
    COMMON_500 = ("COMMON-500", 500, "Unexpected error")
    GOAL_001 = ("GOAL-001", 404, "Goal not found")
    GOAL_002 = ("GOAL-002", 409, "Goal name already in use")
    GOAL_003 = ("GOAL-003", 422, "Target date must be a future date")
    GOAL_004 = ("GOAL-004", 422, "Target amount must be greater than the current balance")
    GOAL_005 = ("GOAL-005", 422, "This change is not permitted for the goal's status")
    GOAL_006 = ("GOAL-006", 422, "Only Active goals can be cancelled")
    GOAL_007 = ("GOAL-007", 422, "Withdraw the full balance before cancelling")
    GOAL_008 = ("GOAL-008", 422, "Only Cancelled goals can be deleted")
    GOAL_009 = ("GOAL-009", 422, "Deposits can be recorded only on Active goals")
    GOAL_010 = ("GOAL-010", 422, "Withdrawals are not permitted on Cancelled goals")
    GOAL_011 = ("GOAL-011", 422, "Transactions can be changed only on Active goals")
    GOAL_012 = ("GOAL-012", 422, "The balance cannot go below \u20b90")
    TXN_001 = ("TXN-001", 404, "Transaction not found")
    TXN_002 = ("TXN-002", 503, "Goal Service unavailable, please try again")
    TXN_003 = ("TXN-003", 504, "Goal Service did not respond in time, please try again")

    @property
    def code(self) -> str:
        """Return the public contract identifier."""
        return self.value[0]

    @property
    def status(self) -> int:
        """Return the code's HTTP status."""
        return self.value[1]

    @property
    def title(self) -> str:
        """Return the stable client-facing title."""
        return self.value[2]


class FieldError(TypedDict):
    """Identify one invalid field without including its submitted value."""

    field: str
    message: str


class ApiError(Exception):
    """Carry a deliberate, safe public error from business or client code."""

    def __init__(
        self, code: ErrorCode, detail: str | None = None, errors: list[FieldError] | None = None
    ) -> None:
        """Accept only sanitized details intended for a caller."""
        super().__init__(detail or code.title)
        self.code = code
        self.detail = detail or code.title
        self.errors = errors


class ValidationError(ApiError):
    """Represent application-level validation under COMMON-400."""

    def __init__(self, errors: list[FieldError]) -> None:
        """Attach the validation-only errors extension."""
        super().__init__(ErrorCode.COMMON_400, errors=errors)


def problem_response(request: Request, error: ApiError, clock: Clock) -> JSONResponse:
    """Serialize the agreed envelope, echoing correlation even on unhandled errors."""
    request_id = getattr(request.state, "correlation_id", "")
    content: dict[str, object] = {
        "type": f"urn:kalash:error:{error.code.code}",
        "title": error.code.title,
        "status": error.code.status,
        "detail": error.detail,
        "instance": request.url.path,
        "errorCode": error.code.code,
        "correlationId": request_id,
        "timestamp": clock.now().isoformat().replace("+00:00", "Z"),
    }
    if error.errors is not None:
        content["errors"] = error.errors
    return JSONResponse(
        content,
        status_code=error.code.status,
        media_type="application/problem+json",
        headers={HEADER: request_id},
    )


def register_error_handlers(app: FastAPI, clock: Clock) -> None:
    """Register explicit logged boundaries without returning internal exception text."""

    @app.exception_handler(ApiError)
    async def api_error(request: Request, exc: ApiError) -> JSONResponse:
        logger.log(
            logging.ERROR if exc.code.status >= 500 else logging.WARNING,
            "api_error",
            extra={"operation": exc.code.code},
        )
        return problem_response(request, exc, clock)

    @app.exception_handler(RequestValidationError)
    async def validation_error(request: Request, exc: RequestValidationError) -> JSONResponse:
        fields: list[FieldError] = [
            {
                "field": ".".join(str(part) for part in error["loc"] if part != "body"),
                "message": "Invalid value" if error["type"] == "value_error" else error["msg"],
            }
            for error in exc.errors()
        ]
        logger.warning("validation_failed")
        return problem_response(request, ValidationError(fields), clock)

    @app.exception_handler(HTTPException)
    async def http_error(request: Request, exc: HTTPException) -> JSONResponse:
        # No domain code represents framework routing errors; retain the HTTP status.
        content = {
            "type": "about:blank",
            "title": HTTPStatus(exc.status_code).phrase,
            "status": exc.status_code,
            "detail": HTTPStatus(exc.status_code).phrase,
            "instance": request.url.path,
            "correlationId": getattr(request.state, "correlation_id", ""),
            "timestamp": clock.now().isoformat().replace("+00:00", "Z"),
        }
        logger.warning("http_error", extra={"status": exc.status_code})
        headers = dict(exc.headers or {})
        headers[HEADER] = getattr(request.state, "correlation_id", "")
        return JSONResponse(
            content,
            status_code=exc.status_code,
            media_type="application/problem+json",
            headers=headers,
        )

    @app.exception_handler(Exception)
    async def unexpected_error(request: Request, exc: Exception) -> JSONResponse:
        logger.error(
            "unexpected_error",
            extra={
                "exceptionType": type(exc).__name__,
                "correlationId": getattr(request.state, "correlation_id", ""),
            },
        )
        return problem_response(request, ApiError(ErrorCode.COMMON_500), clock)
