"""Error response documentation for Phase 3 APIs and forwarded Goal rejections."""

from app.common.errors import ErrorCode


def problem_example(code: ErrorCode) -> dict[str, object]:
    """Describe catalogue envelopes; forwarded Goal bodies retain their original instance."""
    example: dict[str, object] = {
        "type": f"urn:kalash:error:{code.code}",
        "title": code.title,
        "status": code.status,
        "detail": code.title,
        "errorCode": code.code,
        "instance": "/api/v1/transactions",
        "correlationId": "example-correlation-id",
        "timestamp": "2026-10-27T20:00:00Z",
    }
    if code == ErrorCode.COMMON_400:
        example["errors"] = [{"field": "amount", "message": "Invalid value"}]
    return example


ERROR_RESPONSES: dict[int | str, dict[str, object]] = {
    status: {
        "description": description,
        "content": {
            "application/problem+json": {
                "examples": {code.code: {"value": problem_example(code)} for code in codes}
            }
        },
    }
    for status, description, codes in (
        (400, "Request validation failed", [ErrorCode.COMMON_400]),
        (404, "Transaction or goal not found", [ErrorCode.TXN_001, ErrorCode.GOAL_001]),
        (409, "Concurrent transaction or goal update conflict", [ErrorCode.COMMON_409]),
        (
            422,
            "Goal business rule rejected; upstream Problem Details are unchanged",
            [
                ErrorCode.GOAL_008,
                ErrorCode.GOAL_009,
                ErrorCode.GOAL_010,
                ErrorCode.GOAL_011,
                ErrorCode.GOAL_012,
            ],
        ),
        (429, "Upstream rate-limit response, forwarded unchanged", [ErrorCode.COMMON_429]),
        (500, "Local persistence or unexpected failure", [ErrorCode.COMMON_500]),
        (503, "Goal Service unavailable or returned an invalid response", [ErrorCode.TXN_002]),
        (504, "Goal Service timeout", [ErrorCode.TXN_003]),
    )
}
