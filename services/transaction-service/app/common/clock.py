"""Injectable business-date and UTC timestamp clocks (BR-09 and D-06)."""

from dataclasses import dataclass
from datetime import UTC, date, datetime
from typing import Protocol
from zoneinfo import ZoneInfo


class Clock(Protocol):
    """Provide deterministic business dates and UTC timestamps."""

    def now(self) -> datetime:
        """Return a timezone-aware instant in UTC."""
        ...

    def today(self) -> date:
        """Return today's business date in the configured timezone."""
        ...


@dataclass(frozen=True)
class SystemClock:
    """Read wall time only at the injectable infrastructure boundary."""

    timezone: ZoneInfo

    def now(self) -> datetime:
        """Return the current UTC instant."""
        return datetime.now(UTC)

    def today(self) -> date:
        """Resolve the business date using the configured timezone."""
        return self.now().astimezone(self.timezone).date()


@dataclass(frozen=True)
class FixedClock:
    """Support repeatable time-dependent tests without changing the system clock."""

    instant: datetime
    timezone: ZoneInfo

    def __post_init__(self) -> None:
        """Reject naive instants rather than guessing a timezone."""
        if self.instant.tzinfo is None or self.instant.utcoffset() is None:
            raise ValueError("FixedClock requires a timezone-aware instant")

    def now(self) -> datetime:
        """Return the fixed instant normalized to UTC."""
        return self.instant.astimezone(UTC)

    def today(self) -> date:
        """Resolve the fixed instant's business date."""
        return self.instant.astimezone(self.timezone).date()
