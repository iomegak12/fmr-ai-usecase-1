from unittest.mock import AsyncMock, MagicMock

from app import __main__ as entrypoint


def test_entrypoint_uses_immediate_shutdown_and_no_proxy_trust(settings, monkeypatch):
    config = MagicMock()
    server = MagicMock()
    server.serve = AsyncMock()
    monkeypatch.setattr(entrypoint.Settings, "model_validate", lambda values: settings)
    monkeypatch.setattr(entrypoint, "create_app", lambda config: object())
    monkeypatch.setattr(entrypoint.uvicorn, "Config", config)
    monkeypatch.setattr(entrypoint.uvicorn, "Server", lambda config: server)
    entrypoint.main()
    assert config.call_args.kwargs["timeout_graceful_shutdown"] == 0
    assert config.call_args.kwargs["proxy_headers"] is False
    assert config.call_args.kwargs["host"] == "127.0.0.1"
    server.serve.assert_awaited_once()
