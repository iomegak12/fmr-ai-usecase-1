package com.kalash.goal.common.error;

/** Stable public error catalogue from LLD 21.2 and implementation decision D-14. */
public enum ErrorCode {
  COMMON_400(400, "Validation failed"),
  COMMON_409(409, "Concurrent update conflict, please retry"),
  COMMON_429(429, "Too many requests, please retry later"),
  COMMON_500(500, "Unexpected error"),
  GOAL_001(404, "Goal not found"),
  GOAL_002(409, "Goal name already in use"),
  GOAL_003(422, "Target date must be a future date"),
  GOAL_004(422, "Target amount must be greater than the current balance"),
  GOAL_005(422, "This change is not permitted for the goal's status"),
  GOAL_006(422, "Only Active goals can be cancelled"),
  GOAL_007(422, "Withdraw the full balance before cancelling"),
  GOAL_008(422, "Only Cancelled goals can be deleted"),
  GOAL_009(422, "Deposits can be recorded only on Active goals"),
  GOAL_010(422, "Withdrawals are not permitted on Cancelled goals"),
  GOAL_011(422, "Transactions can be changed only on Active goals"),
  GOAL_012(422, "The balance cannot go below ₹0"),
  TXN_001(404, "Transaction not found"),
  TXN_002(503, "Goal Service unavailable, please try again"),
  TXN_003(504, "Goal Service did not respond in time, please try again");

  private final int status;
  private final String title;

  ErrorCode(int status, String title) {
    this.status = status;
    this.title = title;
  }

  /**
   * @return the external, hyphenated catalogue identifier
   */
  public String code() {
    return name().replace('_', '-');
  }

  /**
   * @return the HTTP response status
   */
  public int status() {
    return status;
  }

  /**
   * @return a safe public description
   */
  public String title() {
    return title;
  }
}
