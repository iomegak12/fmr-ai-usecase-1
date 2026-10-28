# syntax=docker/dockerfile:1
# Kalash Transaction Service image (plan Section 5.6, LLD §27).
#
#   docker build -t kalash/transaction-service services/transaction-service
#
# Stage 1 installs the locked runtime dependencies (no dev group) into a
# virtual environment with uv. Stage 2 copies that environment and the
# application onto the same Python base and runs as a non-root user. The
# entrypoint applies Alembic migrations, then execs the service.

ARG PYTHON_IMAGE=python:3.14.10-slim
ARG UV_IMAGE=ghcr.io/astral-sh/uv:0.9.16

FROM ${UV_IMAGE} AS uv

FROM ${PYTHON_IMAGE} AS build
COPY --from=uv /uv /usr/local/bin/uv
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    UV_PROJECT_ENVIRONMENT=/opt/venv
WORKDIR /build
COPY pyproject.toml uv.lock .python-version ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

FROM ${PYTHON_IMAGE} AS runtime
RUN groupadd --system --gid 10001 kalash \
    && useradd --system --uid 10001 --gid kalash --no-create-home --shell /usr/sbin/nologin kalash

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_ENV=docker

WORKDIR /app
COPY --from=build /opt/venv /opt/venv
COPY alembic.ini ./
COPY alembic/ alembic/
COPY app/ app/
RUN python -m compileall -q app alembic
COPY --chmod=0755 docker/entrypoint.sh /usr/local/bin/docker-entrypoint
COPY --chmod=0755 docker/healthcheck.py /usr/local/bin/healthcheck

# Labels last, so new label values never invalidate the layers above.
# BUILD_DATE replaces the creation date inherited from the base image; Make
# passes the HEAD commit time, so unchanged sources give an identical image.
ARG VERSION=0.1.0
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.title="Kalash Transaction Service" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.description="Transaction history and goal balance coordination" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Kalash Financial Services"

USER kalash
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
    CMD ["healthcheck", "/health"]
ENTRYPOINT ["docker-entrypoint"]
