"""Request correlation and outbound propagation (LLD Section 25)."""

import logging
import re
from time import perf_counter
from uuid import uuid4

import httpx
from starlette.datastructures import Headers, MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.common.logging import correlation_id

logger = logging.getLogger("kalash.correlation")
HEADER = "X-Correlation-ID"
VALID_ID = re.compile(r"[A-Za-z0-9._-]{1,128}")


class CorrelationMiddleware:
    """Isolate per-request IDs, echo them and log completion on all HTTP paths."""

    def __init__(self, app: ASGIApp) -> None:
        """Wrap an ASGI application without introducing a task/context boundary."""
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        """Preserve safe caller IDs and replace malformed or missing ones."""
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        supplied = Headers(scope=scope).get(HEADER, "")
        request_id = supplied if VALID_ID.fullmatch(supplied) else str(uuid4())
        scope.setdefault("state", {})["correlation_id"] = request_id
        token = correlation_id.set(request_id)
        started = perf_counter()
        status = 500

        async def send_with_id(message: Message) -> None:
            nonlocal status
            if message["type"] == "http.response.start":
                status = message["status"]
                MutableHeaders(scope=message)[HEADER] = request_id
            await send(message)

        try:
            if supplied and supplied != request_id:
                logger.warning("invalid_correlation_id_replaced")
            await self.app(scope, receive, send_with_id)
        finally:
            logger.log(
                logging.ERROR if status >= 500 else logging.INFO,
                "request_completed",
                extra={"status": status, "durationMs": round((perf_counter() - started) * 1000, 2)},
            )
            correlation_id.reset(token)


async def forward_correlation(request: httpx.Request) -> None:
    """Forward the active request ID on calls made by the shared Goal client."""
    active = correlation_id.get()
    if active:
        request.headers[HEADER] = active
