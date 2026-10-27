"""Environment configuration for implementation-plan D-06 and Section 6."""

from typing import Literal
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import AnyHttpUrl, Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy import URL


class Settings(BaseSettings):
    """Validate runtime settings without exposing passwords in representations."""

    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore", hide_input_in_errors=True
    )

    app_env: Literal["local", "docker", "test"] = "local"
    app_timezone: str = "Asia/Kolkata"
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = "INFO"
    txn_service_port: int = Field(default=8000, ge=1, le=65535)
    txn_db_host: str = Field(default="localhost", min_length=1)
    txn_db_port: int = Field(default=5433, ge=1, le=65535)
    txn_db_name: str = Field(default="transaction_db", min_length=1)
    txn_db_user: str = Field(default="txn_user", min_length=1)
    txn_db_password: SecretStr
    goal_service_base_url: AnyHttpUrl = AnyHttpUrl("http://localhost:8080")
    goal_service_timeout_seconds: float = Field(default=3, gt=0, allow_inf_nan=False)
    app_root_path: str = ""

    @field_validator("txn_db_password")
    @classmethod
    def require_password(cls, value: SecretStr) -> SecretStr:
        """Reject empty development credentials instead of silently defaulting."""
        if not value.get_secret_value().strip():
            raise ValueError("TXN_DB_PASSWORD must be nonempty")
        return value

    @field_validator("app_timezone")
    @classmethod
    def validate_timezone(cls, value: str) -> str:
        """Require an available IANA timezone for BR-09 business dates."""
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError) as exc:
            raise ValueError("APP_TIMEZONE must be a valid IANA timezone") from exc
        return value

    @field_validator("goal_service_base_url")
    @classmethod
    def validate_goal_url(cls, value: AnyHttpUrl) -> AnyHttpUrl:
        """Keep credentials and query data out of the logged dependency URL."""
        if value.username or value.password or value.query or value.fragment:
            raise ValueError("Goal Service URL must not contain credentials, query or fragment")
        return value

    @field_validator("app_root_path")
    @classmethod
    def validate_root_path(cls, value: str) -> str:
        """Accept only a normalized documentation proxy prefix."""
        if value not in ("", "/docs/transactions"):
            raise ValueError("APP_ROOT_PATH must be empty or /docs/transactions")
        return value

    def database_url(self) -> URL:
        """Build an escaped driver URL; never render it with the password visible."""
        return URL.create(
            "postgresql+psycopg",
            username=self.txn_db_user,
            password=self.txn_db_password.get_secret_value(),
            host=self.txn_db_host,
            port=self.txn_db_port,
            database=self.txn_db_name,
        )
