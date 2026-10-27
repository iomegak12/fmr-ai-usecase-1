package com.kalash.goal.common.error;

import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.Map;
import java.util.Set;
import org.hibernate.exception.ConstraintViolationException;
import org.postgresql.util.PSQLException;
import org.postgresql.util.ServerErrorMessage;

/** Maps structured database metadata, never SQL text or driver messages, to public errors. */
public final class ConstraintErrorMapper {
  private static final Map<String, ErrorCode> CONSTRAINTS =
      Map.of(
          "ux_goals_name_ci", ErrorCode.GOAL_002,
          "goals_balance_check", ErrorCode.GOAL_012,
          "goals_target_amount_check", ErrorCode.COMMON_400,
          "goals_status_check", ErrorCode.COMMON_400);
  private static final Set<String> REQUIRED_GOAL_FIELDS =
      Set.of("name", "target_amount", "target_date", "balance", "status");

  private ConstraintErrorMapper() {}

  /**
   * Implements BR-03, BR-04 and BR-14 at the persistence boundary.
   *
   * @param failure the persistence failure, potentially wrapped
   * @return a known rejection or the sanitized internal-error fallback
   */
  public static ErrorCode map(Throwable failure) {
    Set<Throwable> seen = Collections.newSetFromMap(new IdentityHashMap<>());
    for (Throwable cause = failure; cause != null && seen.add(cause); cause = cause.getCause()) {
      if (cause instanceof ConstraintViolationException violation) {
        ErrorCode mapped = knownConstraint(violation.getConstraintName());
        if (mapped != null) {
          return mapped;
        }
      }
      if (cause instanceof PSQLException postgres) {
        ServerErrorMessage metadata = postgres.getServerErrorMessage();
        if (metadata != null) {
          ErrorCode mapped = knownConstraint(metadata.getConstraint());
          if (mapped != null) {
            return mapped;
          }
          if ("23502".equals(postgres.getSQLState())
              && "goals".equals(metadata.getTable())
              && metadata.getColumn() != null
              && REQUIRED_GOAL_FIELDS.contains(metadata.getColumn())) {
            return ErrorCode.COMMON_400;
          }
        }
      }
    }
    return ErrorCode.COMMON_500;
  }

  private static ErrorCode knownConstraint(String name) {
    return name == null ? null : CONSTRAINTS.get(name);
  }
}
