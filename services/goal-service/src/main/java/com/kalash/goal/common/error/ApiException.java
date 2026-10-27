package com.kalash.goal.common.error;

import java.util.Objects;

/** An expected rejection; arbitrary exception messages are never exposed to callers. */
public class ApiException extends RuntimeException {
  private final ErrorCode errorCode;

  /**
   * Creates a rejection using the catalogue's safe public description.
   *
   * @param errorCode the public rejection code
   */
  public ApiException(ErrorCode errorCode) {
    super(Objects.requireNonNull(errorCode).title());
    this.errorCode = errorCode;
  }

  /**
   * @return the catalogue entry for this rejection
   */
  public ErrorCode errorCode() {
    return errorCode;
  }
}
