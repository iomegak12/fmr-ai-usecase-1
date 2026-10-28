package com.kalash.goal.goal.service;

import com.kalash.goal.common.error.ApiException;
import com.kalash.goal.common.error.ErrorCode;
import com.kalash.goal.goal.api.UpdateGoalRequest;
import com.kalash.goal.goal.domain.Goal;
import com.kalash.goal.goal.domain.GoalStatus;
import com.kalash.goal.goal.repository.GoalRepository;
import java.time.Clock;
import java.time.LocalDate;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** Business validation for BR-03/05/06/17/19, independent of HTTP transport. */
@Component
public class GoalRules {
  private final GoalRepository repository;
  private final Clock clock;

  /**
   * @param repository goal-owned persistence boundary
   * @param clock injectable business-date clock
   */
  public GoalRules(GoalRepository repository, Clock clock) {
    this.repository = repository;
    this.clock = clock;
  }

  /**
   * @param name supplied display name
   * @return normalized name; rejects blank names after Unicode whitespace normalization
   */
  public String normalizeName(String name) {
    String normalized = name.strip();
    if (normalized.isBlank() || normalized.length() > 100)
      throw new ApiException(ErrorCode.COMMON_400);
    return normalized;
  }

  /**
   * @param name normalized candidate
   * @param excluding goal being edited, or null on creation
   * @throws ApiException GOAL-002 when the name is reserved (including Cancelled goals)
   */
  public void ensureNameUnique(String name, UUID excluding) {
    boolean exists =
        excluding == null
            ? repository.existsByNameIgnoreCase(name)
            : repository.existsByNameIgnoreCaseAndGoalIdNot(name, excluding);
    if (exists) throw new ApiException(ErrorCode.GOAL_002);
  }

  /**
   * @param date candidate target date
   * @throws ApiException GOAL-003 unless the date is after today in the configured timezone
   */
  public void ensureFutureDate(LocalDate date) {
    if (!date.isAfter(LocalDate.now(clock))) throw new ApiException(ErrorCode.GOAL_003);
  }

  /**
   * @param target proposed edited target
   * @param balance current balance
   * @throws ApiException GOAL-004 unless the target strictly exceeds the balance
   */
  public void ensureTargetAboveBalance(long target, long balance) {
    if (target <= balance) throw new ApiException(ErrorCode.GOAL_004);
  }

  /**
   * @param goal current persisted goal
   * @param request requested edit
   * @throws ApiException GOAL-005 when editing is forbidden by BR-17/19
   */
  public void ensureEditAllowed(Goal goal, UpdateGoalRequest request) {
    if (goal.status() == GoalStatus.CANCELLED
        || (goal.status() == GoalStatus.ACHIEVED
            && (request.name() != null
                || request.targetDate() != null
                || request.targetAmount() == null
                || request.targetAmount() <= goal.targetAmount()))) {
      throw new ApiException(ErrorCode.GOAL_005);
    }
  }
}
