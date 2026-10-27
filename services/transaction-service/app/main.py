"""Phase 1 app factory; business routers are introduced in P3."""

from zoneinfo import ZoneInfo

from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

from app import __version__
from app.common.clock import Clock, SystemClock
from app.common.config import Settings
from app.common.correlation import CorrelationMiddleware
from app.common.errors import register_error_handlers
from app.common.lifecycle import application_lifespan
from app.health.router import router as health_router


def create_app(settings: Settings | None = None, clock: Clock | None = None) -> FastAPI:
    """Create a service with validated settings and injectable time."""
    settings = settings or Settings()
    clock = clock or SystemClock(ZoneInfo(settings.app_timezone))
    app = FastAPI(
        title="Kalash Transaction Service",
        version=__version__,
        description="Transaction Service cross-cutting foundations. Business APIs arrive in P3.",
        lifespan=application_lifespan(settings),
        root_path=settings.app_root_path,
        root_path_in_servers=False,
        servers=[{"url": "/", "description": "Public API origin (direct or gateway)"}],
        openapi_tags=[
            {
                "name": "Health",
                "description": "Process liveness and transaction database readiness.",
            },
            {
                "name": "Internal",
                "description": "Internal-only operations, not exposed by the gateway.",
            },
        ],
    )
    app.state.clock = clock
    app.state.settings = settings
    app.add_middleware(CorrelationMiddleware)
    register_error_handlers(app, clock)
    app.include_router(health_router)
    Instrumentator(excluded_handlers=["/metrics"]).instrument(app).expose(
        app, endpoint="/metrics", include_in_schema=False
    )
    return app
