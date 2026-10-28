package com.kalash.goal.goal.api;

import com.kalash.goal.goal.domain.Goal;
import com.kalash.goal.goal.domain.GoalStatus;
import com.kalash.goal.insights.Insights;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Public goal representation; insights are calculated per read and null for Cancelled goals. */
public record GoalResponse(
    UUID goalId,
    String name,
    long targetAmount,
    LocalDate targetDate,
    long balance,
    GoalStatus status,
    Insights insights,
    OffsetDateTime createdAt,
    OffsetDateTime updatedAt) {
  /**
   * @param goal persisted goal
   * @param insights current read-time insights
   * @return the LLD Section 13.3 response, without exposing persistence version
   */
  public static GoalResponse from(Goal goal, Insights insights) {
    return new GoalResponse(
        goal.goalId(),
        goal.name(),
        goal.targetAmount(),
        goal.targetDate(),
        goal.balance(),
        goal.status(),
        insights,
        goal.createdAt(),
        goal.updatedAt());
  }
}
