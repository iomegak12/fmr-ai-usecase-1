package com.kalash.goal.balance.api;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;

/** LLD Section 14 balance-change contract; delta signs are validated by the service. */
public record BalanceAdjustmentRequest(
    @NotNull @Schema(example = "DEPOSIT") Operation operation,
    @NotNull @Schema(example = "5000") Long delta) {
  /** Operations with distinct BR-10/12/13 permissions. */
  public enum Operation {
    DEPOSIT,
    WITHDRAWAL,
    TRANSACTION_EDIT,
    TRANSACTION_DELETE
  }
}
